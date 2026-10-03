//
//  ContentView.swift
//  SignalApp
//

import SwiftUI

enum HomeNavigationRoute: Hashable {
    case chatRoom(id: UUID)
}

struct ContentView: View {
    @EnvironmentObject private var pushRouter: PushNotificationRouter
    @EnvironmentObject private var authSession: AuthSessionManager
    @State private var rooms: [Room] = []
    @State private var navigationPath: [HomeNavigationRoute] = []
    @State private var showProfileNameSetup = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var widgetTargetRoomId: UUID?

    private let manager = SupabaseManager.shared

    var body: some View {
        Group {
            switch authSession.phase {
            case .loading:
                ProgressView("로그인 확인 중…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .signedOut:
                SignInView()
            case .signedIn:
                signedInHome
            }
        }
        .preferredColorScheme(.light)
    }

    private var signedInHome: some View {
        NavigationStack(path: $navigationPath) {
            HomeDashboardView(
                rooms: $rooms,
                widgetTargetRoomId: $widgetTargetRoomId,
                isLoading: isLoading,
                errorMessage: errorMessage,
                onRefresh: { await reloadRooms() },
                onOpenRoom: { room in openRoom(room) },
                onCreateRoom: {
                    try await createRoom()
                },
                onJoinRoom: { code in
                    try await joinRoom(code: code)
                },
                onDeleteWaitingRoom: { room in await deleteWaitingRoom(room) },
                onAccountDeleted: {
                    navigationPath.removeAll()
                    Task { await reloadRooms() }
                }
            )
            .navigationDestination(for: HomeNavigationRoute.self) { route in
                switch route {
                case .chatRoom(let roomId):
                    chatRoomDestination(roomId: roomId)
                }
            }
        }
        .task {
            manager.restoreDeviceUserIdFromAuthMetadataIfAvailable()
            _ = manager.currentUserId
            showProfileNameSetup = !ProfileDisplayNameStore.hasValid
            loadWidgetTargetFromStorage()
            await reloadRooms()
            await HeartWalletService.shared.refresh()
        }
        .sheet(isPresented: $showProfileNameSetup) {
            ProfileDisplayNameSetupView {
                showProfileNameSetup = false
                Task { await reloadRooms() }
            }
        }
        .onChange(of: widgetTargetRoomId) { _, newValue in
            if let id = newValue {
                AppGroupStorage.widgetTargetRoomId = id.uuidString
            } else {
                AppGroupStorage.widgetTargetRoomId = nil
            }
            manager.refreshWidgetTimelines()
        }
    }

    private func loadWidgetTargetFromStorage() {
        if let raw = AppGroupStorage.widgetTargetRoomId, let id = UUID(uuidString: raw) {
            widgetTargetRoomId = id
        }
    }

    private func resolvedNickname(for room: Room) -> String {
        if let mine = manager.myNickname(in: room) {
            return mine
        }
        if let profile = ProfileDisplayNameStore.saved, NicknameValidator.isValid(profile) {
            return profile
        }
        return "me"
    }

    private func openRoom(_ room: Room) {
        let nick = resolvedNickname(for: room)
        manager.syncSharedState(room: room, nickname: nick)
        manager.persistSession(room: room, nickname: nick)
        let route = HomeNavigationRoute.chatRoom(id: room.id)
        if navigationPath.last != route {
            navigationPath.append(route)
        }
    }

    @ViewBuilder
    private func chatRoomDestination(roomId: UUID) -> some View {
        if let room = rooms.first(where: { $0.id == roomId }) {
            ChatRoomView(
                room: room,
                senderNickname: resolvedNickname(for: room),
                onLeaveRoom: { Task { await exitChatRoom(roomId: room.id) } }
            )
            .id(room.id)
            .task(id: room.id) {
                for await updated in manager.watchRoomUpdates(roomId: room.id) {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        guard let index = rooms.firstIndex(where: { $0.id == updated.id }) else { return }
                        if rooms[index] != updated {
                            rooms[index] = updated
                        }
                    }
                }
            }
        } else {
            ProgressView("방 불러오는 중…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    await reloadRooms()
                    if rooms.first(where: { $0.id == roomId }) == nil {
                        popNavigationRoute()
                    }
                }
        }
    }

    private func popNavigationRoute() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
    }

    @MainActor
    private func exitChatRoom(roomId: UUID) async {
        if let room = rooms.first(where: { $0.id == roomId }) {
            try? await manager.leaveRoom(room)
            RoomPinStorage.removePin(for: room.id)
            await reloadRooms()
        }
        popNavigationRoute()
    }

    @MainActor
    private func deleteWaitingRoom(_ room: Room) async {
        guard manager.canDeleteWaitingRoom(room) else {
            errorMessage = SupabaseManagerError.roomDeleteNotAllowed.localizedDescription
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await manager.deleteWaitingRoom(id: room.id)
            RoomPinStorage.removePin(for: room.id)
            navigationPath.removeAll { route in
                if case .chatRoom(let id) = route { return id == room.id }
                return false
            }
            if widgetTargetRoomId == room.id {
                widgetTargetRoomId = nil
            }
            await reloadRooms()
        } catch {
            errorMessage = UserFacingErrorMessage.actionMessage(from: error)
        }
    }

    @MainActor
    private func reloadRooms() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            rooms = try await manager.fetchJoinedRooms()
            if widgetTargetRoomId == nil, let first = rooms.first {
                widgetTargetRoomId = first.id
            }
            if let target = widgetTargetRoomId, !rooms.contains(where: { $0.id == target }) {
                widgetTargetRoomId = rooms.first?.id
            }
            manager.refreshWidgetTimelines()
        } catch {
            errorMessage = UserFacingErrorMessage.loadMessage(from: error)
        }
    }

    @MainActor
    private func createRoom() async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let created = try await manager.createRoom()
        await reloadRooms()
        openRoom(created)
    }

    @MainActor
    private func joinRoom(code: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let joined = try await manager.joinRoom(code: code)
        await reloadRooms()
        openRoom(joined)
    }
}

#Preview {
    ContentView()
        .environmentObject(PushNotificationRouter.shared)
}
