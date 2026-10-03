//
//  AuthSessionManager.swift
//  SignalApp
//

import AuthenticationServices
import CryptoKit
import Foundation
import Supabase
import SwiftUI
import UIKit

@MainActor
final class AuthSessionManager: NSObject, ObservableObject {
    enum Phase {
        case loading
        case signedOut
        case signedIn
    }

    @Published private(set) var phase: Phase = .loading
    @Published var lastError: String?

    private let manager = SupabaseManager.shared
    private var currentNonce: String?

    var isSignedIn: Bool { phase == .signedIn }

    func bootstrap() async {
        if manager.client.auth.currentSession != nil {
            manager.restoreDeviceUserIdFromAuthMetadataIfAvailable()
            await linkDeviceUserIdIfNeeded()
            phase = .signedIn
            await HeartWalletService.shared.refresh()
            return
        }
        phase = .signedOut
    }

    func signInWithApple(profileDisplayName: String) async {
        lastError = nil
        guard savePendingProfileDisplayName(profileDisplayName) else { return }
        let nonce = randomNonce()
        currentNonce = nonce
        let hashed = sha256(nonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashed

        do {
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func completeAppleSignIn(idToken: String) async {
        do {
            _ = try await manager.client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken,
                    nonce: currentNonce
                )
            )
            try await finalizeOAuthSession()
        } catch {
            lastError = error.localizedDescription
            phase = .signedOut
        }
    }

    func signInWithGoogle(profileDisplayName: String) async {
        lastError = nil
        guard savePendingProfileDisplayName(profileDisplayName) else { return }
        do {
            _ = try await manager.client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: HeartCatalog.oauthRedirectURL
            )
        } catch {
            lastError = error.localizedDescription
        }
    }

    func handleOAuthCallback(url: URL) async {
        do {
            _ = try await manager.client.auth.session(from: url)
            try await finalizeOAuthSession()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func signOut() async {
        do {
            try await manager.client.auth.signOut()
        } catch {
            lastError = error.localizedDescription
        }
        phase = .signedOut
    }

    private func finalizeOAuthSession() async throws {
        await linkDeviceUserIdIfNeeded()
        _ = try await manager.client.auth.refreshSession()
        _ = await manager.ensureAuthenticatedSessionForProfiles()
        commitPendingProfileDisplayNameIfNeeded()
        phase = .signedIn
        await HeartWalletService.shared.refresh()
    }

    private func savePendingProfileDisplayName(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard NicknameValidator.isValid(trimmed) else {
            lastError = SupabaseManagerError.invalidNickname.localizedDescription
            return false
        }
        pendingProfileDisplayName = trimmed
        return true
    }

    private var pendingProfileDisplayName: String?

    private func commitPendingProfileDisplayNameIfNeeded() {
        if let pendingProfileDisplayName {
            ProfileDisplayNameStore.save(pendingProfileDisplayName)
            self.pendingProfileDisplayName = nil
        }
    }

    private func linkDeviceUserIdIfNeeded() async {
        manager.restoreDeviceUserIdFromAuthMetadataIfAvailable()
        let deviceId = manager.currentUserId
        let meta = manager.client.auth.currentSession?.user.userMetadata["device_user_id"]?.stringValue
        if DeviceUserId.matches(meta ?? "", deviceId) {
            return
        }
        do {
            try await manager.client.auth.update(
                user: UserAttributes(data: ["device_user_id": AnyJSON.string(deviceId)])
            )
            _ = try await manager.client.auth.refreshSession()
        } catch {
            print("⚠️ [Auth] device_user_id metadata sync failed: \(error)")
        }
    }

    private func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        result.reserveCapacity(length)
        for _ in 0 ..< length {
            result.append(charset.randomElement()!)
        }
        return result
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

extension AuthSessionManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            Task { @MainActor in
                lastError = "Apple 로그인 토큰을 읽을 수 없습니다."
            }
            return
        }
        Task { @MainActor in
            await completeAppleSignIn(idToken: idToken)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor in
            lastError = error.localizedDescription
        }
    }
}

extension AuthSessionManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first { $0.isKeyWindow }
        return window ?? ASPresentationAnchor()
    }
}
