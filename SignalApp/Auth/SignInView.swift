//
//  SignInView.swift
//  SignalApp
//

import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @EnvironmentObject private var auth: AuthSessionManager

    @State private var profileDisplayName = ""

    private var canSignIn: Bool {
        NicknameValidator.isValid(profileDisplayName)
    }

    var body: some View {
        ZStack {
            CozyTheme.roomBackground.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 10) {
                    Text("ㄱ.야르렁밤티키캡")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(CozyTheme.textPrimary)
                    Text("Apple 또는 Google 계정으로 시작해 주세요.\n하트·이용 횟수는 계정에 저장됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(CozyTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("내 닉네임")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CozyTheme.textSecondary)
                    TextField("영문·숫자", text: $profileDisplayName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                        )
                        .onChange(of: profileDisplayName) { _, newValue in
                            profileDisplayName = NicknameValidator.sanitizedInput(newValue)
                        }
                    Text("채팅에서 상대에게 보이는 기본 이름입니다. 방마다 채팅 설정에서 바꿀 수 있어요.")
                        .font(.caption)
                        .foregroundStyle(CozyTheme.textSecondary)
                }
                .padding(.horizontal, 28)

                VStack(spacing: 14) {
                    Button {
                        Task { await auth.signInWithApple(profileDisplayName: profileDisplayName) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "apple.logo")
                            Text("Apple로 계속하기")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .opacity(canSignIn ? 1 : 0.45)
                    .disabled(!canSignIn)

                    Button {
                        Task { await auth.signInWithGoogle(profileDisplayName: profileDisplayName) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "globe")
                            Text("Google로 계속하기")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(CozyTheme.textPrimary)
                    .background(CozyTheme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(CozyTheme.uiBorder, lineWidth: CozyTheme.uiBorderWidth)
                    )
                    .opacity(canSignIn ? 1 : 0.45)
                    .disabled(!canSignIn)
                }
                .padding(.horizontal, 28)

                if let lastError = auth.lastError {
                    Text(lastError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()
            }
        }
    }
}
