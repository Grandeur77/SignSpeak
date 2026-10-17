//
//  ButtonStyles.swift
//  SignSpeak
//

import SwiftUI

/// Navy with white text in light mode; turquoise with navy text in dark mode.
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundStyle(.onPrimary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(.primaryFill, in: .rect(cornerRadius: Theme.Radius.button))
            .pressEffect(isPressed: configuration.isPressed, isEnabled: isEnabled, reduceMotion: reduceMotion)
    }
}

/// Full-width outlined button for secondary actions such as "Continue as guest".
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundStyle(.accentText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.button)
                    .strokeBorder(.brandTurquoise, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: Theme.Radius.button))
            .pressEffect(isPressed: configuration.isPressed, isEnabled: isEnabled, reduceMotion: reduceMotion)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// Solid red button with white text for destructive actions (e.g. deleting account, sign out).
struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appButton)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(.danger, in: .rect(cornerRadius: Theme.Radius.button))
            .pressEffect(isPressed: configuration.isPressed, isEnabled: isEnabled, reduceMotion: reduceMotion)
    }
}

extension ButtonStyle where Self == DestructiveButtonStyle {
    static var destructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}

private extension View {
    /// Dims disabled buttons and gives pressed feedback; the shrink is skipped under Reduce Motion.
    func pressEffect(isPressed: Bool, isEnabled: Bool, reduceMotion: Bool) -> some View {
        self
            .opacity(isEnabled ? (isPressed ? 0.8 : 1) : 0.4)
            .scaleEffect(isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isPressed)
    }
}
