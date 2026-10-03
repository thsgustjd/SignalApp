//
//  ProfileDisplayNameSetupView.swift
//  SignalApp
//

import SwiftUI

/// 기존 로그인 세션인데 프로필 닉네임이 없을 때.
struct ProfileDisplayNameSetupView: View {
    var onSaved: () -> Void

    @State private var name = ""
    @State private var errorMessage: String?

    private var canSave: Bool {
        NicknameValidator.isValid(name)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("채팅에 쓸 닉네임을 정해 주세요. 방마다 채팅 설정에서 이름을 바꿀 수 있습니다.")
                    .font(.subheadline)
                    .foregroundStyle(CozyTheme.textPrimary)

                TextField("영문·숫자", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                    )
                    .onChange(of: name) { _, newValue in
                        name = NicknameValidator.sanitizedInput(newValue)
                    }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button("저장하고 시작") {
                    guard canSave else {
                        errorMessage = SupabaseManagerError.invalidNickname.localizedDescription
                        return
                    }
                    ProfileDisplayNameStore.save(name)
                    onSaved()
                }
                .font(.headline.weight(.bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .foregroundStyle(.white)
                .background(CozyTheme.deepBlue, in: RoundedRectangle(cornerRadius: CozyTheme.cornerRadius, style: .continuous))
                .disabled(!canSave)

                Spacer()
            }
            .padding(20)
            .background(CozyTheme.roomBackground.ignoresSafeArea())
            .navigationTitle("닉네임 설정")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}
