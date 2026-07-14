//
//  Theme.swift
//  salattracker
//
//  Central color + surface styling. Warm, calm palette tuned for a
//  spiritual habit app: amber for streaks, green for completion.
//

import SwiftUI
import UIKit

private extension UIColor {
    convenience init(hex: UInt) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension Color {
    init(hex: UInt) { self.init(UIColor(hex: hex)) }

    /// A color that resolves differently in light and dark appearance.
    static func adaptive(light: UInt, dark: UInt) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

enum Theme {
    /// Amber — streaks, highlights, primary accent.
    static let primary = Color.adaptive(light: 0xD97706, dark: 0xF59E0B)
    /// Habit green — completion.
    static let accent = Color.adaptive(light: 0x059669, dark: 0x34D399)
    /// Card / raised surface.
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x241D17)
    /// Primary text.
    static let text = Color.adaptive(light: 0x1C1917, dark: 0xF6EFE6)
    /// Secondary text.
    static let subtle = Color.adaptive(light: 0x8A7E72, dark: 0xADA294)
    /// Warm shadow used under raised surfaces.
    static let shadow = Color.adaptive(light: 0xC98A3A, dark: 0x000000)

    /// The screen's warm background wash.
    static var background: LinearGradient {
        LinearGradient(
            colors: [
                Color.adaptive(light: 0xFFFBF3, dark: 0x1A1510),
                Color.adaptive(light: 0xFBEED9, dark: 0x0F0C08),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Soft glow tint behind the streak flame.
    static let glow = Color.adaptive(light: 0xFDBA74, dark: 0xB45309)

    /// The app's shared motion — one gentle spring used everywhere so
    /// transitions feel consistent and calm.
    static let motion = Animation.spring(response: 0.42, dampingFraction: 0.86)
    /// A slightly quicker spring for taps and toggles.
    static let quickMotion = Animation.spring(response: 0.32, dampingFraction: 0.72)
}

/// A rounded, softly shadowed raised surface — the app's card look.
struct SoftCard: ViewModifier {
    var cornerRadius: CGFloat = 24
    var elevated: Bool = false

    func body(content: Content) -> some View {
        content.background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.surface)
                // Softer, more diffuse shadow — lighter and calmer to look at.
                .shadow(
                    color: Theme.shadow.opacity(elevated ? 0.18 : 0.10),
                    radius: elevated ? 24 : 18,
                    x: 0,
                    y: elevated ? 12 : 8
                )
        )
    }
}

extension View {
    func softCard(cornerRadius: CGFloat = 24, elevated: Bool = false) -> some View {
        modifier(SoftCard(cornerRadius: cornerRadius, elevated: elevated))
    }
}

/// Press feedback: a gentle spring scale-down on tap.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(Theme.quickMotion, value: configuration.isPressed)
    }
}
