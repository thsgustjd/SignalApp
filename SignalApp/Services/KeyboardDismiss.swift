//
//  KeyboardDismiss.swift
//  SignalApp
//

import SwiftUI
import UIKit

enum KeyboardDismiss {
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private static let installer = BackgroundTapInstaller()
    private static let gestureName = "SignalDismissKeyboardTap"

    static func installIfNeeded(on window: UIWindow?) {
        guard let window else { return }
        if window.gestureRecognizers?.contains(where: { $0.name == gestureName }) == true {
            return
        }
        let tap = UITapGestureRecognizer(target: installer, action: #selector(BackgroundTapInstaller.handleTap))
        tap.name = gestureName
        tap.cancelsTouchesInView = false
        tap.delegate = installer
        window.addGestureRecognizer(tap)
    }
}

private final class BackgroundTapInstaller: NSObject, UIGestureRecognizerDelegate {
    @objc func handleTap() {
        KeyboardDismiss.dismiss()
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view: UIView? = touch.view
        while let current = view {
            if current is UITextField || current is UITextView || current is UISearchBar {
                return false
            }
            view = current.superview
        }
        return true
    }
}

/// `WindowGroup` 루트에 한 번 올려 전 화면에서 배경 탭 시 키보드를 내립니다.
struct KeyboardDismissOnBackgroundTapInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            KeyboardDismiss.installIfNeeded(on: uiView.window)
        }
    }
}

extension View {
    func dismissKeyboardOnBackgroundTap() -> some View {
        background(KeyboardDismissOnBackgroundTapInstaller())
    }
}
