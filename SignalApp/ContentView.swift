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
    @State private var rooms: [Room] = []
    @State private var navigationPath: [HomeNavigationRoute] = []
    @State private var nickname = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var widgetTargetRoomId: UUID?

    private let manager = SupabaseManager.shared

    var body: some View {
        NavigationStack(path: $navigationPath) {
            HomeDashboardView(
                rooms: $rooms,
                nickname: $nickname,
                widgetTargetRoomId: $widgetTargetRoomId,
                isLoading: isLoading,
                errorMessage: errorMessage,
                onRefresh: { await reloadRooms() },
                onOpenRoom: { room in openRoom(room) },
                onCreateRoom: { await createRoom() },
                onJoinRoom: { code in await joinRoom(code: code) },
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
        .preferredColorScheme(.light)
        .task {
            _ = manager.currentUserId
            if let saved = manager.savedNickname {
                nickname = saved
            }
            loadWidgetTargetFromStorage()
            await reloadRooms()
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
        if NicknameValidator.isValid(nickname) {
            return nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return manager.savedNickname ?? "me"
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
            navigationPath.removeAll { route in
                if case .chatRoom(let id) = route { return id == room.id }
                return false
            }
            if widgetTargetRoomId == room.id {
                widgetTargetRoomId = nil
            }
            await reloadRooms()
        } catch {
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func createRoom() async {
        guard NicknameValidator.canSubmit(nickname) else {
            errorMessage = "닉네임을 먼저 입력해 주세요."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let created = try await manager.createRoom(nickname: nickname)
            await reloadRooms()
            openRoom(created)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func joinRoom(code: String) async {
        guard NicknameValidator.canSubmit(nickname) else {
            errorMessage = "닉네임을 먼저 입력해 주세요."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let joined = try await manager.joinRoom(code: code, nickname: nickname)
            await reloadRooms()
            openRoom(joined)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(PushNotificationRouter.shared)
}
