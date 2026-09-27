//
//  HomeDashboardView.swift
//  SignalApp
//

import SwiftUI

struct HomeDashboardView: View {
    @Binding var rooms: [Room]
    @Binding var nickname: String
    @Binding var widgetTargetRoomId: UUID?

    let isLoading: Bool
    let errorMessage: String?
    var onRefresh: () async -> Void
    var onOpenRoom: (Room) -> Void
    var onCreateRoom: () async -> Void
    var onJoinRoom: (String) async -> Void
    var onDeleteWaitingRoom: (Room) async -> Void
    var onAccountDeleted: () -> Void

    @State private var showRoomActionsMenu = false
    @State private var menuJoinCode = ""
    @State private var roomPendingDelete: Room?
    @State private var roomCustomizationEpoch = 0
    @State private var roomCustomizationTarget: Room?

    private let manager = SupabaseManager.shared

    private var isNicknameValid: Bool {
        NicknameValidator.canSubmit(nickname)
    }

    var body: some View {
        ZStack {
            CozyTheme.roomBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    headerBar

                    introCard

                    if rooms.isEmpty, !isLoading {
                        emptyRoomsCard
                    } else {
                        VStack(spacing: 14) {
                            ForEach(rooms) { room in
                                roomListCard(room)
                            }
                        }
                        .id(roomCustomizationEpoch)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .refreshable {
                await onRefresh()
            }

            if isLoading, rooms.isEmpty {
                ProgressView()
                    .tint(CozyTheme.lavender)
            }
        }
        .sheet(isPresented: $showRoomActionsMenu) {
            HomeRoomActionsSheet(
                nickname: $nickname,
                joinCode: $menuJoinCode,
                rooms: rooms,
                widgetTargetRoomId: $widgetTargetRoomId,
                isNicknameValid: isNicknameValid,
                onCreateRoom: {
                    showRoomActionsMenu = false
                    Task { await onCreateRoom() }
                },
                onJoinRoom: {
                    let code = menuJoinCode
                    showRoomActionsMenu = false
                    Task { await onJoinRoom(code) }
                },
                onAccountDeleted: {
                    showRoomActionsMenu = false
                    onAccountDeleted()
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(item: $roomCustomizationTarget) { room in
            RoomCardCustomizationSheet(room: room) {
                roomCustomizationEpoch += 1
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "대기 중인 방을 삭제할까요?",
            isPresented: Binding(
                get: { roomPendingDelete != nil },
                set: { if !$0 { roomPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("방 삭제", role: .destructive) {
                guard let room = roomPendingDelete else { return }
                roomPendingDelete = nil
                Task { await onDeleteWaitingRoom(room) }
            }
            Button("취소", role: .cancel) {
                roomPendingDelete = nil
            }
        } message: {
            Text("멤버가 2명 이상 연결된 방은 삭제할 수 없습니다. 채팅방 메뉴에서 나가기를 사용해 주세요.")
        }
    }

    private var headerBar: some View {
        HStack {
            Text("ㄱ.정병키캡")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [CozyTheme.pink, CozyTheme.lavender],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            Spacer()

            Button {
                showRoomActionsMenu = true
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(CozyTheme.textSecondary)
            }
            .accessibilityLabel("메뉴")
        }
        .padding(.top, 8)
    }

    private var introCard: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("키캡 시그널")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CozyTheme.textPrimary)
                Text("마음껏 정병을 발사하세요.")
                    .font(.subheadline)
                    .foregroundStyle(CozyTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "keyboard.fill")
                .font(.system(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [CozyTheme.pink, CozyTheme.lavender],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: CozyTheme.pink.opacity(0.25), radius: 4, y: 2)
        }
        .padding(20)
        .cozyDashboardCard()
    }

    private var emptyRoomsCard: some View {
        VStack(spacing: 12) {
            Text("아직 참여 중인 방이 없어요")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CozyTheme.textPrimary)
            Text("우측 상단 ··· 메뉴에서 새 방을 만들거나 초대 코드로 연결해 주세요.")
                .font(.caption)
                .foregroundStyle(CozyTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .cozyDashboardCard()
    }

    private func roomListCard(_ room: Room) -> some View {
        let waiting = !room.isMatched

        return HStack(spacing: 0) {
            Button {
                onOpenRoom(room)
            } label: {
                HStack(spacing: 14) {
                    RoomEmojiBadge(emoji: manager.roomDisplayEmoji(for: room))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(manager.roomDisplayTitle(for: room))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(CozyTheme.textPrimary)
                            .lineLimit(1)

                        Text(roomStatusSubtitle(for: room))
                            .font(.caption)
                            .foregroundStyle(CozyTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    if widgetTargetRoomId == room.id {
                        Image(systemName: "lock.square.stack.fill")
                            .font(.caption)
                            .foregroundStyle(CozyTheme.accent)
                            .accessibilityLabel("위젯 전송 방")
                    }

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CozyTheme.textSecondary.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.vertical, 16)
                .padding(.trailing, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                roomCustomizationTarget = room
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(CozyTheme.accent)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(CozyTheme.lavender.opacity(0.2))
                    )
            }
            .buttonStyle(.plain)
            .padding(.vertical, 16)
            .accessibilityLabel("방 이름·이모지 설정")

            if waiting, manager.canDeleteWaitingRoom(room) {
                Button {
                    roomPendingDelete = room
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [CozyTheme.pink.opacity(0.95), Color.red.opacity(0.75)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .accessibilityLabel("대기 방 삭제")
            } else {
                Spacer()
                    .frame(width: 12)
            }
        }
        .cozyDashboardCard()
    }

    private func roomStatusSubtitle(for room: Room) -> String {
        let countLabel = manager.memberCountLabel(for: room)
        if room.isMatched {
            return "\(countLabel) · 탭하여 입장"
        }
        return "\(countLabel) · 멤버 모집 중 · #\(room.inviteCode.prefix(6))…"
    }
}

private struct RoomEmojiBadge: View {
    let emoji: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.92),
                            CozyTheme.lavender.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(emoji)
                .font(.system(size: 30))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(width: 56, height: 56)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(CozyTheme.lavender.opacity(0.28), lineWidth: 1)
        )
    }
}

private struct RoomCardCustomizationSheet: View {
    let room: Room
    var onSaved: () -> Void

    @State private var draftTitle = ""
    @State private var draftEmoji = RoomCustomizationStore.defaultEmojiSymbol
    @Environment(\.dismiss) private var dismiss

    private let manager = SupabaseManager.shared

    private var canSave: Bool {
        RoomCustomizationStore.canSubmitTitle(draftTitle)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        RoomEmojiBadge(emoji: RoomCustomizationStore.primaryEmoji(from: draftEmoji))
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("방 이름", text: $draftTitle)
                    TextField("대표 이모지", text: $draftEmoji)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: draftEmoji) { _, newValue in
                            let picked = RoomCustomizationStore.sanitizedEmojiInput(newValue)
                            if picked != newValue {
                                draftEmoji = picked
                            }
                        }
                } header: {
                    Text("내 화면에만 보여요")
                } footer: {
                    Text("상대에게는 전달되지 않습니다. 기본 이름은 상대 닉네임입니다. 이모지는 하나만 저장됩니다(비우면 저장 시 기본값).")
                }

                Section {
                    Button("기본값으로 되돌리기") {
                        draftTitle = manager.defaultRoomTitle(for: room)
                        draftEmoji = manager.defaultRoomEmoji(for: room)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(CozyTheme.roomBackground.ignoresSafeArea())
            .navigationTitle("방 꾸미기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .foregroundStyle(CozyTheme.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        manager.saveRoomCustomization(
                            for: room,
                            title: draftTitle,
                            emoji: draftEmoji
                        )
                        onSaved()
                        dismiss()
                    }
                    .disabled(!canSave)
                    .foregroundStyle(CozyTheme.accent)
                }
            }
            .onAppear {
                let draft = manager.customizationDraft(for: room)
                draftTitle = draft.title
                draftEmoji = draft.emoji
            }
        }
    }
}

private struct HomeRoomActionsSheet: View {
    @Binding var nickname: String
    @Binding var joinCode: String
    let rooms: [Room]
    @Binding var widgetTargetRoomId: UUID?
    let isNicknameValid: Bool
    var onCreateRoom: () -> Void
    var onJoinRoom: () -> Void
    var onAccountDeleted: () -> Void

    private let manager = SupabaseManager.shared

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("영문·숫자", text: $nickname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: nickname) { _, newValue in
                            nickname = NicknameValidator.sanitizedInput(newValue)
                        }
                } header: {
                    Text("내 닉네임")
                } footer: {
                    Text("채팅에서 보이는 내 이름입니다. 홈 카드 방 이름·이모지는 각 방 옆 설정에서 바꿀 수 있어요.")
                }

                Section {
                    Button {
                        onCreateRoom()
                    } label: {
                        Label("새 방 만들기", systemImage: "plus.circle.fill")
                            .foregroundStyle(CozyTheme.textPrimary)
                    }
                    .disabled(!isNicknameValid)

                    TextField("12자리 초대 코드", text: $joinCode)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .onChange(of: joinCode) { _, newValue in
                            joinCode = String(InviteCodeValidator.sanitizedInput(newValue).prefix(12))
                        }

                    Button {
                        onJoinRoom()
                    } label: {
                        Text("초대 코드로 연결 / 재입장")
                    }
                    .disabled(!isNicknameValid || !InviteCodeValidator.isValidLength(joinCode))
                } header: {
                    Text("방")
                }

                Section {
                    Picker("잠금화면 위젯 전송 방", selection: $widgetTargetRoomId) {
                        Text("선택 안 함").tag(UUID?.none)
                        ForEach(rooms) { room in
                            Text(manager.roomDisplayTitle(for: room))
                                .tag(Optional(room.id))
                        }
                    }
                } footer: {
                    Text("잠금화면 키캡을 누를 때 메시지가 전달될 채팅방입니다.")
                }

                Section {
                    NavigationLink {
                        SafetyAndDataView(onAccountDeleted: {
                            dismiss()
                            onAccountDeleted()
                        })
                    } label: {
                        Label("안전 및 데이터", systemImage: "shield")
                    }
                } footer: {
                    Text("신고·차단·내 데이터 삭제·약관 링크")
                }
            }
            .scrollContentBackground(.hidden)
            .background(CozyTheme.roomBackground.ignoresSafeArea())
            .navigationTitle("메뉴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                        .foregroundStyle(CozyTheme.accent)
                }
            }
        }
    }
}

private extension View {
    func cozyDashboardCard() -> some View {
        background {
            RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                .fill(CozyTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                        .strokeBorder(CozyTheme.lavender.opacity(0.28), lineWidth: 1)
                )
                .shadow(color: CozyTheme.lavender.opacity(0.12), radius: 10, y: 4)
        }
    }
}
