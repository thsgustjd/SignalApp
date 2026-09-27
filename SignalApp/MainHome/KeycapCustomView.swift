//
//  KeycapCustomView.swift
//  SignalApp
//

import SwiftUI
import WidgetKit

struct KeycapCustomView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var drafts: [String: String] = AppGroupStorage.keycapMessagesForEditing()
    @State private var didSave = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection

                    VStack(spacing: 12) {
                        // 표시 순서: heart → … → question → play(5) → angry → … → hot
                        ForEach(AppGroupStorage.keycapNudgeTypeOrder, id: \.self) { type in
                            KeycapCustomCardRow(
                                type: type,
                                title: KeycapMessageMetadata.metadata(for: type).title,
                                text: binding(for: type),
                                onReset: { resetSingleKeycap(type) }
                            )
                        }
                    }

                    dndInfoCard
                    emergencyInfoCard

                    legalLinksFooter
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
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
            .overlay(alignment: .top) {
                if didSave {
                    Text("저장했습니다")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.82), in: Capsule())
                        .padding(.top, 8)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: didSave)
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
                Text("알림 방해금지 토글")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CozyTheme.textPrimary)
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
                .fill(Color(.systemGray6).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(CozyTheme.accent.opacity(0.2), lineWidth: 1)
        )
    }

    private var emergencyInfoCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("🚨")
                .font(.system(size: 36))
            VStack(alignment: .leading, spacing: 6) {
                Text("비상 키캡")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CozyTheme.textPrimary)
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
                .fill(Color(.systemGray6).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
        )
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
        .foregroundStyle(CozyTheme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private func binding(for type: String) -> Binding<String> {
        Binding(
            get: { drafts[type] ?? AppGroupStorage.defaultKeycapMessages[type] ?? "" },
            set: { drafts[type] = $0 }
        )
    }

    private func resetSingleKeycap(_ type: String) {
        drafts[type] = AppGroupStorage.defaultKeycapMessages[type] ?? ""
    }

    private func save() {
        AppGroupStorage.saveKeycapMessages(drafts)
        WidgetCenter.shared.reloadAllTimelines()
        didSave = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            didSave = false
        }
    }
}

private struct KeycapCustomCardRow: View {
    let type: String
    let title: String
    @Binding var text: String
    var onReset: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            KeycapMiniBadge(type: type)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CozyTheme.textPrimary)
                TextField("전송 문구", text: $text, axis: .vertical)
                    .lineLimit(1 ... 2)
                    .font(.subheadline)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }

            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(CozyTheme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray5).opacity(0.6), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(title) 기본 문구로 되돌리기")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        )
    }
}

private struct KeycapMiniBadge: View {
    let type: String

    var body: some View {
        let presentation = AppGroupStorage.keycapSymbolPresentation(for: type)
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
            Text(presentation.emoji)
                .font(.system(size: 22))
        }
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
            return KeycapMessageMetadata(title: "추워 키캡", systemImage: "snowflake", placeholder: defaultText)
        case "hot":
            return KeycapMessageMetadata(title: "더워 키캡", systemImage: "thermometer.sun.fill", placeholder: defaultText)
        case "play":
            return KeycapMessageMetadata(title: "놀자 키캡", systemImage: "face.smiling.inverse", placeholder: defaultText)
        default:
            return KeycapMessageMetadata(title: type, systemImage: "square.grid.2x2", placeholder: defaultText)
        }
    }
}

#Preview {
    KeycapCustomView()
}
