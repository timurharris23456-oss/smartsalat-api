//
//  SocialStreaks.swift
//  salattracker
//
//  Models for the SalatStreaks social tab. Friends are sample data for now;
//  the "You" row is driven by real local data. Wiring these to real friends
//  needs accounts + a synced backend.
//

import Foundation

/// A single row in the streaks leaderboard (a friend, or you).
struct StreakEntry: Identifiable {
    let id: String
    let name: String
    let streak: Int
    let completedToday: Set<Prayer>
    var isYou: Bool = false

    var completedCount: Int { completedToday.count }
    var isComplete: Bool { completedToday.count == Prayer.allCases.count }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }
}

