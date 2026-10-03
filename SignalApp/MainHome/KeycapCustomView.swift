//
//  KeycapCustomView.swift
//  SignalApp
//

import SwiftUI
import WidgetKit

struct KeycapCustomView: View {
    /// 하단 탭 「키캡 셋팅」에 임베드될 때 `true`
    var embeddedInTabBar: Bool = false
    var room: Room?
    var onRoomUpdated: ((Room) -> Void)?

    @Environment(\.dismiss) private var dismiss

    @State private var drafts: [String: String] = AppGroupStorage.keycapMessagesForEditing()
    @State private var titleDrafts: [String: String] = AppGroupStorage.keycapTitlesForEditing()
    @State private var emojiDrafts: [String: String] = AppGroupStorage.keycapEmojisForEditing()
    @State private var didSave = false
    @State private var lockScreenPresence = LockScreenWidgetPresence()

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if embeddedInTabBar {
                settingsScroll
                    .background(CozyTheme.roomBackground.ignoresSafeArea())
                    .safeAreaInset(edge: .top, spacing: 0) {
                        embeddedTopBar
                    }
            } else {
                NavigationStack {
                    settingsScroll
                        .background(CozyTheme.background.ignoresSafeArea())
                        .navigationTitle("키캡 시그널 설정")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("닫기") { dismiss() }
                            }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("저장 완료") { save() }
                                    .fontWeight(.semibold)
                            }
                        }
                }
            }
        }
        .onAppear { refreshLockScreenPresence() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshLockScreenPresence() }
        }
        .overlay(alignment: .top) {
            if didSave {
                Text("저장했습니다")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.82), in: Capsule())
                    .padding(.top, embeddedInTabBar ? 52 : 8)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: didSave)
    }

    private var embeddedTopBar: some View {
        HStack {
            Text("키캡 셋팅")
                .font(.headline.weight(.bold))
                .foregroundStyle(CozyTheme.textPrimary)
            Spacer()
            Button("저장") { save() }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(CozyTheme.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.white)
    }

    private var settingsScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !embeddedInTabBar {
                    headerSection
                } else {
                    Text("잠금화면 키캡 문구·알림 동작을 이 기기에서 설정합니다.")
                        .font(.subheadline)
                        .foregroundStyle(CozyTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if embeddedInTabBar, let room {
                    ChatRoomDisplayNameSettingsCard(room: room, onRoomUpdated: onRoomUpdated)
                }

                if lockScreenPresence.hasAnyLockScreenKeycap {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(CozyTheme.deepBlue)
                        Text("빛나는 카드는 지금 잠금화면에 추가된 키캡이에요.")
                            .font(.caption)
                            .foregroundStyle(CozyTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(spacing: 12) {
                    ForEach(Array(AppGroupStorage.keycapNudgeTypeOrder.enumerated()), id: \.element) { index, type in
                        if AppGroupStorage.isUserCustomizableKeycap(type) {
                            KeycapCustomizableCardRow(
                                slotNumber: index + 1,
                                type: type,
                                title: bindingTitle(for: type),
                                emoji: bindingEmoji(for: type),
                                text: binding(for: type),
                                isOnLockScreen: lockScreenPresence.nudgeTypes.contains(type),
                                onReset: { resetSingleKeycap(type) }
                            )
                        } else {
                            KeycapCustomCardRow(
                                type: type,
                                title: AppGroupStorage.displayTitle(for: type),
                                text: binding(for: type),
                                isOnLockScreen: lockScreenPresence.nudgeTypes.contains(type),
                                onReset: { resetSingleKeycap(type) }
                            )
                        }
                    }
                }

                dndInfoCard
                emergencyInfoCard

                legalLinksFooter
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 8)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("키캡 시그널 설정")
                .font(.title2.weight(.bold))
                .foregroundStyle(CozyTheme.textPrimary)
            Text("잠금화면에서 키캡을 눌렀을 때 전송될 문구를 자유롭게 변경해보세요.")
                .font(.subheadline)
                .foregroundStyle(CozyTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("채팅 말풍선에는 표시되지 않으며, 상대에게 넛지로만 전달됩니다.")
                .font(.caption)
                .foregroundStyle(CozyTheme.textSecondary.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private var dndInfoCard: some View {
        HStack(alignment: .top, spacing: 14) {
            KeycapDNDBadge()
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("알림 방해금지 토글")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CozyTheme.textPrimary)
                    if lockScreenPresence.hasDNDWidget {
                        LockScreenKeycapBadge()
                    }
                }
                Text(
                    "잠금화면에서 이 키캡을 누르면 안으로 푹 눌리며 시그널 앱 알림이 무음 처리됩니다. "
                        + "다시 누르면 튀어나오며 알림이 켜집니다."
                )
                .font(.caption)
                .foregroundStyle(CozyTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CozyTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
        )
        .lockScreenKeycapGlow(isActive: lockScreenPresence.hasDNDWidget, accent: CozyTheme.accent)
    }

    private var emergencyInfoCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("🚨")
                .font(.system(size: 36))
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("비상 키캡")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CozyTheme.textPrimary)
                    if lockScreenPresence.hasEmergencyWidget {
                        LockScreenKeycapBadge()
                    }
                }
                Text(
                    "그리드 밖 별도 키캡입니다. 다섯 번 연속으로 누른 뒤 길게 눌러야 연결된 상대에게 우선 알림이 갑니다. "
                        + "방해금지가 켜져 있어도 상대 기기에는 울릴 수 있습니다. "
                        + "119·112 등 공공 긴급전화나 응급 구조 서비스가 아니며, 실제 위급 상황에서는 반드시 공공 기관에 연락하세요."
                )
                .font(.caption)
                .foregroundStyle(CozyTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CozyTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
        )
        .lockScreenKeycapGlow(isActive: lockScreenPresence.hasEmergencyWidget, accent: Color.orange)
    }

    private var legalLinksFooter: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let url = AppLegalConfig.privacyPolicyURL {
                Link("개인정보 처리방침", destination: url)
                    .font(.caption)
            }
            if let url = AppLegalConfig.termsOfServiceURL {
                Link("이용약관", destination: url)
                    .font(.caption)
            }
            Text("신고·차단·삭제: 홈 메뉴 → 안전 및 데이터")
                .font(.caption2)
                .foregroundStyle(CozyTheme.textSecondary.opacity(0.9))
        }
        .foregroundStyle(CozyTheme.textPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func binding(for type: String) -> Binding<String> {
        Binding(
            get: { drafts[type] ?? AppGroupStorage.defaultKeycapMessages[type] ?? "" },
            set: { drafts[type] = $0 }
        )
    }

    private func bindingTitle(for type: String) -> Binding<String> {
        Binding(
            get: { titleDrafts[type] ?? AppGroupStorage.defaultDisplayTitle(for: type) },
            set: { titleDrafts[type] = $0 }
        )
    }

    private func bindingEmoji(for type: String) -> Binding<String> {
        Binding(
            get: { emojiDrafts[type] ?? AppGroupStorage.defaultKeycapEmoji(for: type) ?? "" },
            set: { emojiDrafts[type] = AppGroupStorage.sanitizeSingleEmojiInput($0) }
        )
    }

    private func resetSingleKeycap(_ type: String) {
        drafts[type] = AppGroupStorage.defaultKeycapMessages[type] ?? ""
        if AppGroupStorage.isUserCustomizableKeycap(type) {
            titleDrafts[type] = AppGroupStorage.defaultDisplayTitle(for: type)
            emojiDrafts[type] = AppGroupStorage.defaultKeycapEmoji(for: type) ?? ""
        }
    }

    private func save() {
        AppGroupStorage.saveKeycapMessages(drafts)
        AppGroupStorage.saveKeycapAppearances(titles: titleDrafts, emojis: emojiDrafts)
        WidgetCenter.shared.reloadAllTimelines()
        didSave = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didSave = false
        }
    }

    private func refreshLockScreenPresence() {
        LockScreenWidgetSnapshot.fetch { lockScreenPresence = $0 }
    }
}

private struct KeycapCustomizableCardRow: View {
    let slotNumber: Int
    let type: String
    @Binding var title: String
    @Binding var emoji: String
    @Binding var text: String
    var isOnLockScreen: Bool
    var onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("\(slotNumber)번")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(CozyTheme.textPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(CozyTheme.panelInsetFill, in: Capsule())
                    .overlay(Capsule().strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth))
                Text("이모지·이름 커스텀 가능")
                    .font(.caption2)
                    .foregroundStyle(CozyTheme.textSecondary)
            }

            HStack(alignment: .center, spacing: 12) {
                KeycapMiniBadge(type: type, emojiOverride: emoji, isOnLockScreen: isOnLockScreen)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        TextField("😀", text: $emoji)
                            .font(.system(size: 26))
                            .multilineTextAlignment(.center)
                            .frame(width: 44, height: 44)
                            .foregroundStyle(CozyTheme.textPrimary)
                            .background(CozyTheme.panelInsetFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                            )
                            .onChange(of: emoji) { _, newValue in
                                let sanitized = AppGroupStorage.sanitizeSingleEmojiInput(newValue)
                                if sanitized != newValue { emoji = sanitized }
                            }

                        TextField("키캡 이름", text: $title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(CozyTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(CozyTheme.panelInsetFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                            )

                        if isOnLockScreen {
                            LockScreenKeycapBadge()
                        }
                    }

                    TextField("전송 문구", text: $text, axis: .vertical)
                        .lineLimit(1 ... 2)
                        .font(.subheadline)
                        .foregroundStyle(CozyTheme.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                        )
                }

                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(CozyTheme.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(CozyTheme.panelInsetFill, in: Circle())
                        .overlay(Circle().strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(title) 기본값으로 되돌리기")
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
        )
        .lockScreenKeycapGlow(isActive: isOnLockScreen, accent: CozyTheme.accent)
    }
}

private struct KeycapCustomCardRow: View {
    let type: String
    let title: String
    @Binding var text: String
    var isOnLockScreen: Bool
    var onReset: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            KeycapMiniBadge(type: type, isOnLockScreen: isOnLockScreen)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CozyTheme.textPrimary)
                    if isOnLockScreen {
                        LockScreenKeycapBadge()
                    }
                }
                TextField("전송 문구", text: $text, axis: .vertical)
                    .lineLimit(1 ... 2)
                    .font(.subheadline)
                    .foregroundStyle(CozyTheme.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                    )
            }

            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CozyTheme.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(CozyTheme.panelInsetFill, in: Circle())
                    .overlay(Circle().strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) 기본 문구로 되돌리기")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .cozyUIBorderOverlay(cornerRadius: 16)
        .lockScreenKeycapGlow(isActive: isOnLockScreen, accent: CozyTheme.accent)
    }
}

private struct LockScreenKeycapBadge: View {
    var body: some View {
        Label("잠금화면", systemImage: "lock.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(CozyTheme.textPrimary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(CozyTheme.panelInsetFill, in: Capsule())
            .overlay(Capsule().strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth))
    }
}

private struct KeycapMiniBadge: View {
    let type: String
    var emojiOverride: String?
    var isOnLockScreen: Bool = false

    var body: some View {
        let presentation = AppGroupStorage.keycapSymbolPresentation(for: type)
        let emoji = emojiOverride ?? presentation.emoji
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.32), Color(white: 0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                )
            Text(emoji)
                .font(.system(size: 22))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                .frame(width: 44, height: 44)
        }
        .overlay {
            if isOnLockScreen {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(CozyTheme.uiBorder, lineWidth: 2)
                    .frame(width: 48, height: 48)
            }
        }
    }
}

// MARK: - 잠금화면 위젯 하이라이트

private struct LockScreenKeycapGlowModifier: ViewModifier {
    let isActive: Bool
    let accent: Color
    let cornerRadius: CGFloat

    @State private var glowPhase = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(CozyTheme.uiBorder, lineWidth: glowPhase ? 2.5 : 2)
                        .allowsHitTesting(false)
                }
            }
            .shadow(
                color: isActive ? accent.opacity(0.22) : .black.opacity(0.05),
                radius: isActive ? 10 : 6,
                y: isActive ? 0 : 2
            )
            .onAppear { updateGlowAnimation(active: isActive) }
            .onChange(of: isActive) { _, active in
                updateGlowAnimation(active: active)
            }
    }

    private func updateGlowAnimation(active: Bool) {
        glowPhase = false
        guard active else { return }
        withAnimation(.easeInOut(duration: 1.75).repeatForever(autoreverses: true)) {
            glowPhase = true
        }
    }
}

private extension View {
    func lockScreenKeycapGlow(isActive: Bool, accent: Color, cornerRadius: CGFloat = 16) -> some View {
        modifier(LockScreenKeycapGlowModifier(isActive: isActive, accent: accent, cornerRadius: cornerRadius))
    }
}

private struct KeycapDNDBadge: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.28), Color(white: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 44, height: 44)
            Text("🚫")
                .font(.system(size: 22))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                .frame(width: 44, height: 44)
        }
    }
}

private struct KeycapMessageMetadata {
    let title: String
    let systemImage: String
    let placeholder: String

    static func metadata(for type: String) -> KeycapMessageMetadata {
        let defaultText = AppGroupStorage.defaultKeycapMessages[type] ?? ""
        switch type {
        case "heart":
            return KeycapMessageMetadata(title: "사랑해 키캡", systemImage: "heart.fill", placeholder: defaultText)
        case "pleading":
            return KeycapMessageMetadata(title: "보고싶어 키캡", systemImage: "face.smiling", placeholder: defaultText)
        case "tongue":
            return KeycapMessageMetadata(title: "메롱 키캡", systemImage: "face.smiling", placeholder: defaultText)
        case "question":
            return KeycapMessageMetadata(title: "뭐해 키캡", systemImage: "questionmark", placeholder: defaultText)
        case "angry":
            return KeycapMessageMetadata(title: "그만해라 키캡", systemImage: "exclamationmark.bubble.fill", placeholder: defaultText)
        case "sleep":
            return KeycapMessageMetadata(title: "잘자 키캡", systemImage: "moon.zzz.fill", placeholder: defaultText)
        case "grin":
            return KeycapMessageMetadata(title: "굿모닝 키캡", systemImage: "sun.max.fill", placeholder: defaultText)
        case "clover":
            return KeycapMessageMetadata(title: "흥! 키캡", systemImage: "leaf.fill", placeholder: defaultText)
        case "pencil":
            return KeycapMessageMetadata(title: "연락 봐줘", systemImage: "message.fill", placeholder: defaultText)
        case "doc":
            return KeycapMessageMetadata(title: "전화 해줘", systemImage: "phone.fill", placeholder: defaultText)
        case "tired":
            return KeycapMessageMetadata(title: "피곤해", systemImage: "bed.double.fill", placeholder: defaultText)
        case "hungry":
            return KeycapMessageMetadata(title: "배고파 키캡", systemImage: "fork.knife", placeholder: defaultText)
        case "cold":
            return KeycapMessageMetadata(title: "심심해 키캡", systemImage: "ellipsis.bubble", placeholder: defaultText)
        case "hot":
            return KeycapMessageMetadata(title: "퇴근 키캡", systemImage: "figure.wave", placeholder: defaultText)
        case "play":
            return KeycapMessageMetadata(title: "놀자 키캡", systemImage: "face.smiling.inverse", placeholder: defaultText)
        default:
            return KeycapMessageMetadata(title: type, systemImage: "square.grid.2x2", placeholder: defaultText)
        }
    }
}

private struct ChatRoomDisplayNameSettingsCard: View {
    let room: Room
    var onRoomUpdated: ((Room) -> Void)?

    @State private var draftName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSave = false

    private let manager = SupabaseManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("이 방에서 보이는 이름")
                .font(.headline.weight(.bold))
                .foregroundStyle(CozyTheme.textPrimary)
            Text("상대 채팅·알림에 표시됩니다. 계정 닉네임과 별개예요.")
                .font(.caption)
                .foregroundStyle(CozyTheme.textSecondary)

            TextField("영문·숫자", text: $draftName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                )
                .onChange(of: draftName) { _, newValue in
                    draftName = NicknameValidator.sanitizedInput(newValue)
                }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await save() }
            } label: {
                Group {
                    if isSaving {
                        ProgressView().tint(.white)
                    } else {
                        Text("이름 저장")
                            .font(.subheadline.weight(.bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(CozyTheme.deepBlue, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .disabled(isSaving || !NicknameValidator.isValid(draftName))

            if didSave {
                Text("저장했습니다")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CozyTheme.deepBlue)
            }
        }
        .padding(16)
        .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous)
                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
        )
        .onAppear {
            draftName = manager.myNickname(in: room) ?? ProfileDisplayNameStore.saved ?? ""
        }
    }

    @MainActor
    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            let updated = try await manager.setMyRoomDisplayName(room: room, displayName: draftName)
            onRoomUpdated?(updated)
            withAnimation { didSave = true }
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run { didSave = false }
        } catch {
            errorMessage = UserFacingErrorMessage.actionMessage(from: error)
        }
    }
}

#Preview {
    KeycapCustomView()
}
