//
//  AppearanceMode.swift
//  salattracker
//

import SwiftUI

/// How the app chooses light vs. dark appearance.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case light
    case dark
    /// Follows the sun: light between sunrise and sunset, dark otherwise.
    case dynamic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .dynamic: "Dynamic"
        }
    }

    var symbol: String {
        switch self {
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        case .dynamic: "circle.lefthalf.filled"
        }
    }
}
