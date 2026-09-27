//
//  SafetyViews.swift
//  SignalApp
//

import SwiftUI

struct ReportSheetContext: Identifiable {
    let room: Room
    let message: MediaMessage?
    let preselectedUserId: String?

    var id: String {
        if let message { return "msg-\(message.id.uuidString)" }
        if let preselectedUserId { return "user-\(preselectedUserId)" }
        return "room-\(room.id.uuidString)"
    }
}

// MARK: - Hub

struct SafetyAndDataView: View {
    var onAccountDeleted: (() -> Void)?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ReportContentView(room: nil, message: nil, preselectedUserId: nil, reporterNickname: nil)
                } label: {
                    Label("콘텐츠·사용자 신고", systemImage: "exclamationmark.bubble")
                }
                NavigationLink {
                    BlockedUsersView()
                } label: {
                    Label("차단한 사용자", systemImage: "person.crop.circle.badge.xmark")
                }
                NavigationLink {
                    DeleteMyDataView(onAccountDeleted: onAccountDeleted)
                } label: {
                    Label("내 데이터 삭제", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } footer: {
                Text("신고·차단·삭제 방법은 이용약관 및 개인정보 처리방침과 함께 운영됩니다.")
            }

            Section("문의·약관") {
                if let url = AppLegalConfig.privacyPolicyURL {
                    Link(destination: url) {
                        Label("개인정보 처리방침", systemImage: "hand.raised")
                    }
                }
                if let url = AppLegalConfig.termsOfServiceURL {
                    Link(destination: url) {
                        Label("이용약관", systemImage: "doc.text")
                    }
                }
                Link(destination: URL(string: "mailto:\(AppLegalConfig.supportEmail)")!) {
                    Label("문의: \(AppLegalConfig.supportEmail)", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("안전 및 데이터")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Report

struct ReportContentView: View {
    let room: Room?
    let message: MediaMessage?
    let preselectedUserId: String?
    let reporterNickname: String?

    @Environment(\.dismiss) private var dismiss

    @State private var catalogRooms: [Room] = []
    @State private var selectedRoomId: UUID?
    @State private var selectedUserId: String?
    @State private var category: UserSafetyService.ReportCategory = .harassment
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var didSubmit = false

    private let manager = SupabaseManager.shared

    private var resolvedRoom: Room? {
        if let room { return room }
        return catalogRooms.first { $0.id == selectedRoomId }
    }

    private var memberOptions: [(userId: String, displayName: String)] {
        guard let resolvedRoom else { return [] }
        return manager.otherMembersForSafety(in: resolvedRoom)
    }

    var body: some View {
        Form {
            if didSubmit {
                Section {
                    Text("접수했습니다. 운영팀이 검토합니다.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    if let room {
                        LabeledContent("방", value: manager.roomDisplayTitle(for: room))
                    } else {
                        Picker("방", selection: $selectedRoomId) {
                            ForEach(catalogRooms) { item in
                                Text(manager.roomDisplayTitle(for: item)).tag(Optional(item.id))
                            }
                        }
                    }

                    if message != nil {
                        LabeledContent("대상", value: "선택한 메시지")
                    }

                    Picker("신고 대상", selection: $selectedUserId) {
                        ForEach(memberOptions, id: \.userId) { member in
                            Text(member.displayName).tag(Optional(member.userId))
                        }
                    }

                    Picker("사유", selection: $category) {
                        ForEach(UserSafetyService.ReportCategory.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }

                    TextField("추가 설명 (선택)", text: $note, axis: .vertical)
                        .lineLimit(3 ... 6)
                } footer: {
                    Text("허위 신고는 이용 제한 사유가 될 수 있습니다. 범죄·긴급 상황은 112·119 등 공공 기관에 연락하세요.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }

                Section {
                    Button("신고 보내기") {
                        Task { await submit() }
                    }
                    .disabled(isSubmitting || resolvedRoom == nil || selectedUserId == nil)
                }
            }
        }
        .navigationTitle("신고")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if room == nil {
                catalogRooms = (try? await manager.fetchJoinedRooms()) ?? []
                if selectedRoomId == nil {
                    selectedRoomId = catalogRooms.first?.id
                }
            } else {
                selectedRoomId = room?.id
            }
            if selectedUserId == nil {
                selectedUserId = preselectedUserId
                    ?? message.flatMap { msg in
                        DeviceUserId.matches(msg.senderId, manager.currentUserId) ? nil : msg.senderId
                    }
                    ?? memberOptions.first?.userId
            }
        }
        .onChange(of: selectedRoomId) { _, _ in
            selectedUserId = memberOptions.first?.userId
        }
    }

    @MainActor
    private func submit() async {
        guard let room = resolvedRoom else { return }
        guard let reportedId = selectedUserId else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let draft = UserSafetyService.ReportDraft(
            roomId: room.id,
            reportedUserId: reportedId,
            messageId: message?.id,
            category: category,
            note: note,
            reporterNickname: reporterNickname ?? manager.savedNickname
        )

        do {
            try await UserSafetyService.submitReport(draft)
            didSubmit = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Block list

struct BlockedUsersView: View {
    @State private var entries = UserSafetyStore.entries

    var body: some View {
        List {
            if entries.isEmpty {
                Text("차단한 사용자가 없습니다.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries) { entry in
                    HStack {
                        Text(entry.displayName)
                        Spacer()
                        Button("해제") {
                            UserSafetyStore.unblock(userId: entry.userId)
                            entries = UserSafetyStore.entries
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle("차단 목록")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { entries = UserSafetyStore.entries }
    }
}

// MARK: - Delete

struct DeleteMyDataView: View {
    var onAccountDeleted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var confirmed = false
    @State private var isDeleting = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Text(
                    "서버에 저장된 내 프로필·내가 보낸 메시지·방 멤버십을 삭제하고, "
                        + "이 기기의 닉네임·방 목록·차단 목록·키캡 설정 등 로컬 데이터를 모두 지웁니다. "
                        + "다른 사람이 보낸 메시지와 방 자체는 남을 수 있습니다. 되돌릴 수 없습니다."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            Section {
                Toggle("위 내용을 이해했습니다", isOn: $confirmed)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await deleteAll() }
                } label: {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Text("내 데이터 영구 삭제")
                    }
                }
                .disabled(!confirmed || isDeleting)
            }
        }
        .navigationTitle("데이터 삭제")
        .navigationBarTitleDisplayMode(.inline)
    }

    @MainActor
    private func deleteAll() async {
        isDeleting = true
        errorMessage = nil
        defer { isDeleting = false }
        do {
            try await UserSafetyService.deleteAllMyData()
            onAccountDeleted?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Room-scoped safety (chat)

struct RoomSafetyMenuView: View {
    let room: Room
    let senderNickname: String
    var onLeaveRoom: () -> Void

    @State private var reportContext: ReportSheetContext?
    @State private var blockTarget: (userId: String, name: String)?
    @State private var showLeaveConfirm = false

    private let manager = SupabaseManager.shared

    var body: some View {
        List {
            Section {
                Button {
                    reportContext = ReportSheetContext(room: room, message: nil, preselectedUserId: nil)
                } label: {
                    Label("콘텐츠·사용자 신고", systemImage: "exclamationmark.bubble")
                }

                if manager.otherMembersForSafety(in: room).count == 1,
                   let only = manager.otherMembersForSafety(in: room).first {
                    Button {
                        blockTarget = (only.userId, only.displayName)
                    } label: {
                        Label("\(only.displayName) 차단", systemImage: "person.crop.circle.badge.xmark")
                    }
                } else {
                    ForEach(manager.otherMembersForSafety(in: room), id: \.userId) { member in
                        Button {
                            blockTarget = (member.userId, member.displayName)
                        } label: {
                            Label("\(member.displayName) 차단", systemImage: "person.crop.circle.badge.xmark")
                        }
                    }
                }

                NavigationLink {
                    BlockedUsersView()
                } label: {
                    Label("차단 목록", systemImage: "list.bullet")
                }

                NavigationLink {
                    DeleteMyDataView(onAccountDeleted: onLeaveRoom)
                } label: {
                    Label("내 데이터 삭제", systemImage: "trash")
                }
            }

            Section {
                Button(role: .destructive) {
                    showLeaveConfirm = true
                } label: {
                    Label("방 나가기", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } footer: {
                Text("방 나가기는 이 방 멤버십만 해제합니다. 내가 보낸 메시지는 서버에 남을 수 있습니다.")
            }

            Section("문의·약관") {
                if let url = AppLegalConfig.privacyPolicyURL {
                    Link(destination: url) { Label("개인정보 처리방침", systemImage: "hand.raised") }
                }
                if let url = AppLegalConfig.termsOfServiceURL {
                    Link(destination: url) { Label("이용약관", systemImage: "doc.text") }
                }
            }
        }
        .navigationTitle("안전 및 데이터")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $reportContext) { ctx in
            NavigationStack {
                ReportContentView(
                    room: ctx.room,
                    message: ctx.message,
                    preselectedUserId: ctx.preselectedUserId,
                    reporterNickname: senderNickname
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { reportContext = nil }
                    }
                }
            }
        }
        .alert("차단", isPresented: Binding(
            get: { blockTarget != nil },
            set: { if !$0 { blockTarget = nil } }
        )) {
            Button("차단", role: .destructive) {
                if let blockTarget {
                    UserSafetyStore.block(userId: blockTarget.userId, displayName: blockTarget.name)
                }
                blockTarget = nil
            }
            Button("취소", role: .cancel) { blockTarget = nil }
        } message: {
            if let blockTarget {
                Text("\(blockTarget.name)님의 메시지와 알림을 이 기기에서 숨깁니다.")
            }
        }
        .confirmationDialog("방 나가기", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("나가기", role: .destructive) {
                Task {
                    try? await manager.leaveRoom(room)
                    onLeaveRoom()
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 방 목록에서 제거되며, 다시 초대 코드로 들어올 수 있습니다.")
        }
    }
}
