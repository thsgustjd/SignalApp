//
//  HomeDashboardView.swift
//  SignalApp
//

import SwiftUI

struct HomeDashboardView: View {
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var authSession: AuthSessionManager

    @Binding var rooms: [Room]
    @Binding var widgetTargetRoomId: UUID?

    let isLoading: Bool
    let errorMessage: String?
    var onRefresh: () async -> Void
    var onOpenRoom: (Room) -> Void
    var onCreateRoom: () async throws -> Void
    var onJoinRoom: (String) async throws -> Void
    var onDeleteWaitingRoom: (Room) async -> Void
    var onAccountDeleted: () -> Void

    @State private var activeHomeSheet: HomeDashboardSheet?
    @State private var roomPendingDelete: Room?
    @State private var roomCustomizationEpoch = 0
    @State private var roomCustomizationTarget: Room?
    @State private var pinListRevision = 0

    @ObservedObject private var heartWallet = HeartWalletService.shared

    private let manager = SupabaseManager.shared

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
                            ForEach(displayRooms) { room in
                                roomListCard(room)
                                    .contextMenu {
                                        if RoomPinStorage.isPinned(room.id) {
                                            Button {
                                                setRoomPinned(room, pinned: false)
                                            } label: {
                                                Label("상단 고정 해제", systemImage: "pin.slash")
                                            }
                                        } else {
                                            Button {
                                                setRoomPinned(room, pinned: true)
                                            } label: {
                                                Label("상단 고정", systemImage: "pin.fill")
                                            }
                                        }
                                    }
                            }
                        }
                        .id("\(roomCustomizationEpoch)-\(pinListRevision)")
                    }

                    widgetTargetSection

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
        .sheet(item: $activeHomeSheet) { sheet in
            switch sheet {
            case .plusMenu:
                HomePlusMenuSheet(
                    onCreateRoom: { activeHomeSheet = .createRoom },
                    onJoinRoom: { activeHomeSheet = .joinRoom },
                    onAccountSettings: { activeHomeSheet = .accountSettings },
                    onSafety: { activeHomeSheet = .safety },
                    onDeveloperStory: { openDeveloperStorySite() },
                    onClose: { activeHomeSheet = nil }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .createRoom:
                CreateRoomSheet(onFinished: { activeHomeSheet = nil }) {
                    try await onCreateRoom()
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .joinRoom:
                JoinRoomSheet(onFinished: { activeHomeSheet = nil }) { code in
                    try await onJoinRoom(code)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .accountSettings:
                NavigationStack {
                    AccountSettingsView()
                        .environmentObject(authSession)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("닫기") { activeHomeSheet = nil }
                                    .foregroundStyle(CozyTheme.textPrimary)
                            }
                        }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .safety:
                NavigationStack {
                    SafetyAndDataView(onAccountDeleted: {
                        activeHomeSheet = nil
                        onAccountDeleted()
                    })
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("닫기") { activeHomeSheet = nil }
                                .foregroundStyle(CozyTheme.textPrimary)
                        }
                    }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .heartShop:
                HeartShopView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(item: $roomCustomizationTarget) { room in
            RoomCardCustomizationSheet(room: room) {
                roomCustomizationEpoch += 1
                pinListRevision += 1
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

    private func openDeveloperStorySite() {
        activeHomeSheet = nil
        guard let url = AppLegalConfig.developerStoryURL else { return }
        openURL(url)
    }

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("ㄱ.야르렁밤티키캡")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(CozyTheme.textPrimary)
                heartStatusLine
            }

            Spacer()

            HStack(spacing: 14) {
                Button {
                    activeHomeSheet = .heartShop
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(CozyTheme.deepBlue)
                        Text("하트 충전")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(CozyTheme.textPrimary)
                    }
                }
                .accessibilityLabel("하트 충전")

                Button {
                    if activeHomeSheet == .plusMenu {
                        activeHomeSheet = nil
                        DispatchQueue.main.async {
                            activeHomeSheet = .plusMenu
                        }
                    } else {
                        activeHomeSheet = .plusMenu
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(CozyTheme.deepBlue)
                }
                .accessibilityLabel("방 메뉴")
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var heartStatusLine: some View {
        if heartWallet.snapshot?.isUnlimitedActive == true {
            Text("하트 · 무제한 이용 중")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CozyTheme.deepBlue)
        } else {
            Text("하트 \(heartWallet.snapshot?.heartBalance ?? 0) · 무료 \(heartWallet.snapshot?.dailyFreeRemaining ?? HeartCatalog.dailyFreeAllowance)회")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(CozyTheme.textPrimary)
        }
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
                .foregroundStyle(CozyTheme.deepBlue)
        }
        .padding(20)
        .cozyDashboardCard()
    }

    private var displayRooms: [Room] {
        RoomPinStorage.sortRooms(rooms)
    }

    private func setRoomPinned(_ room: Room, pinned: Bool) {
        RoomPinStorage.setPinned(room.id, pinned: pinned)
        pinListRevision += 1
    }

    private var emptyRoomsCard: some View {
        VStack(spacing: 12) {
            Text("아직 참여 중인 방이 없어요")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CozyTheme.textPrimary)
            Text("우측 상단 + 버튼에서 새 방을 만들거나 입장해 주세요.")
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
                        HStack(spacing: 6) {
                            Text(manager.roomDisplayTitle(for: room))
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(CozyTheme.textPrimary)
                                .lineLimit(1)
                            if RoomPinStorage.isPinned(room.id) {
                                Image(systemName: "pin.fill")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(CozyTheme.textPrimary)
                                    .rotationEffect(.degrees(35))
                                    .accessibilityLabel("상단 고정됨")
                            }
                        }

                        Text(roomStatusSubtitle(for: room))
                            .font(.caption)
                            .foregroundStyle(CozyTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    if widgetTargetRoomId == room.id {
                        Image(systemName: "lock.square.stack.fill")
                            .font(.caption)
                            .foregroundStyle(CozyTheme.textPrimary)
                            .accessibilityLabel("위젯 전송 방")
                    }

                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CozyTheme.textPrimary)
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
                    .foregroundStyle(CozyTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(CozyTheme.panelInsetFill)
                            .overlay(Circle().strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth))
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
                                        colors: [Color.red.opacity(0.88), Color.red.opacity(0.65)],
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

    private var widgetTargetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("잠금화면 위젯 전송 방", systemImage: "lock.square.stack.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CozyTheme.textPrimary)

            Picker("잠금화면 위젯 전송 방", selection: $widgetTargetRoomId) {
                Text("선택 안 함").tag(UUID?.none)
                ForEach(rooms) { room in
                    Text(manager.roomDisplayTitle(for: room))
                        .tag(Optional(room.id))
                }
            }
            .pickerStyle(.menu)
            .tint(CozyTheme.textPrimary)

            Text("잠금화면 키캡을 누를 때 메시지가 전달될 채팅방입니다.")
                .font(.caption)
                .foregroundStyle(CozyTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .cozyDashboardCard()
    }
}

private enum HomeDashboardSheet: Identifiable {
    case plusMenu
    case createRoom
    case joinRoom
    case accountSettings
    case safety
    case heartShop

    var id: Self { self }
}

private struct RoomEmojiBadge: View {
    let emoji: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CozyTheme.panelInsetFill)
            Text(emoji)
                .font(.system(size: 30))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(width: 56, height: 56)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
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

    private var pinBinding: Binding<Bool> {
        Binding(
            get: { RoomPinStorage.isPinned(room.id) },
            set: { newValue in
                RoomPinStorage.setPinned(room.id, pinned: newValue)
                onSaved()
            }
        )
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
                    Toggle(isOn: pinBinding) {
                        Label("목록 상단 고정", systemImage: "pin.fill")
                    }
                } footer: {
                    Text("고정한 방은 홈 목록 맨 위에 표시됩니다.")
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
                    .foregroundStyle(CozyTheme.textPrimary)
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

private struct HomePlusMenuSheet: View {
    var onCreateRoom: () -> Void
    var onJoinRoom: () -> Void
    var onAccountSettings: () -> Void
    var onSafety: () -> Void
    var onDeveloperStory: () -> Void
    var onClose: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HomePlusMenuButton(
                    title: "새 방 만들기",
                    subtitle: "12자리 초대 코드가 자동으로 만들어집니다",
                    systemImage: "plus.rectangle.fill",
                    action: onCreateRoom
                )

                HomePlusMenuButton(
                    title: "입장하기",
                    subtitle: "초대 코드만 맞으면 입장됩니다",
                    systemImage: "door.left.hand.open",
                    action: onJoinRoom
                )

                HomePlusMenuButton(
                    title: "계정설정",
                    subtitle: "로그인 계정 확인·로그아웃",
                    systemImage: "person.crop.circle",
                    action: onAccountSettings
                )

                HomePlusMenuButton(
                    title: "안전 및 데이터",
                    subtitle: "신고·차단·데이터 삭제·약관",
                    systemImage: "shield.fill",
                    action: onSafety
                )

                HomePlusMenuButton(
                    title: "개발자 이야기",
                    subtitle: "앱을 만든 배경·수익 활용 참고 안내",
                    systemImage: "text.book.closed.fill",
                    action: onDeveloperStory
                )

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CozyTheme.roomBackground.ignoresSafeArea())
            .navigationTitle("방 메뉴")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") {
                        onClose()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct HomePlusMenuButton: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(CozyTheme.deepBlue)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(CozyTheme.textPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(CozyTheme.textSecondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(CozyTheme.textPrimary)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                    .fill(CozyTheme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                            .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                    )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HomeRoomNoticeBanner: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundStyle(CozyTheme.textPrimary)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CozyTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(CozyTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                )
        )
    }
}

private struct CreateRoomSheet: View {
    var onFinished: () -> Void
    var onConfirm: () async throws -> Void

    @State private var inlineError: String?
    @State private var isSubmitting = false

    @Environment(\.dismiss) private var dismiss

    private var canSubmit: Bool { !isSubmitting }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeRoomNoticeBanner(
                        text: "영문 대·소문자와 숫자로 이뤄진 12자리 초대 코드가 자동 생성됩니다. 방 안에서 코드를 복사해 친구에게 공유하세요."
                    )

                    if let inlineError {
                        Text(inlineError)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    confirmButton
                }
                .padding(20)
            }
            .background(CozyTheme.roomBackground.ignoresSafeArea())
            .navigationTitle("새 방 만들기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        onFinished()
                        dismiss()
                    }
                    .foregroundStyle(CozyTheme.textSecondary)
                    .disabled(isSubmitting)
                }
            }
            .overlay {
                if isSubmitting {
                    RoomAsyncTaskLoadingOverlay(
                        title: "채팅방을 만드는 중입니다",
                        subtitle: "초대 코드를 만들고 방을 연결하고 있어요.\n잠시만 기다려 주세요."
                    )
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
        .animation(.easeInOut(duration: 0.2), value: isSubmitting)
    }

    @MainActor
    private func submit() async {
        inlineError = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await onConfirm()
            onFinished()
            dismiss()
        } catch {
            inlineError = UserFacingErrorMessage.actionMessage(from: error)
        }
    }

    private var confirmButton: some View {
        Button {
            Task { await submit() }
        } label: {
            Group {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("방 만들기").font(.headline.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(RoomFormConfirmBackground(enabled: canSubmit))
        .disabled(!canSubmit)
    }
}

private struct JoinRoomSheet: View {
    var onFinished: () -> Void
    var onConfirm: (String) async throws -> Void

    @State private var inviteCode = ""
    @State private var inlineError: String?
    @State private var isSubmitting = false

    @Environment(\.dismiss) private var dismiss

    private var canSubmit: Bool {
        InviteCodeValidator.isValidLength(inviteCode) && !isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HomeRoomNoticeBanner(
                        text: "초대 코드만 맞으면 입장됩니다. 재설치·재로그인 후에도 같은 코드로 다시 들어올 수 있어요."
                    )

                    inviteCodeField

                    if let inlineError {
                        Text(inlineError)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    confirmButton
                }
                .padding(20)
            }
            .background(CozyTheme.roomBackground.ignoresSafeArea())
            .navigationTitle("입장하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        onFinished()
                        dismiss()
                    }
                    .foregroundStyle(CozyTheme.textSecondary)
                }
            }
        }
    }

    @MainActor
    private func submit() async {
        inlineError = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await onConfirm(inviteCode)
            onFinished()
            dismiss()
        } catch {
            inlineError = UserFacingErrorMessage.actionMessage(from: error)
        }
    }

    private var inviteCodeField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("초대 코드 (12자리)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CozyTheme.textSecondary)
            TextField("영문·숫자 12자", text: $inviteCode)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .padding(12)
                .background(RoomFormFieldBackground())
                .onChange(of: inviteCode) { _, newValue in
                    inviteCode = String(InviteCodeValidator.sanitizedInput(newValue).prefix(12))
                }
        }
    }

    private var confirmButton: some View {
        Button {
            Task { await submit() }
        } label: {
            Group {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("입장").font(.headline.weight(.bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .background(RoomFormConfirmBackground(enabled: canSubmit))
        .disabled(!canSubmit)
    }
}

private struct RoomAsyncTaskLoadingOverlay: View {
    let title: String
    let subtitle: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.28)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .scaleEffect(1.15)
                    .tint(CozyTheme.deepBlue)

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(CozyTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(CozyTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 26)
            .frame(maxWidth: 320)
            .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                    .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
            )
        }
        .transition(.opacity)
    }
}

private struct RoomFormFieldBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(CozyTheme.panelInsetFill)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
            )
    }
}

private struct RoomFormConfirmBackground: View {
    let enabled: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: enabled
                        ? [CozyTheme.pink, CozyTheme.lavender]
                        : [Color.gray.opacity(0.45), Color.gray.opacity(0.35)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                    .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
            )
    }
}

private extension View {
    func cozyDashboardCard() -> some View {
        background {
            RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                .fill(CozyTheme.card)
                .overlay(
                    RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                        .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                )
                .shadow(color: CozyTheme.lavender.opacity(0.12), radius: 10, y: 4)
        }
    }
}
