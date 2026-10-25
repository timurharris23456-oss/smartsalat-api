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
    var avatar: Data? = nil
    var nudgedToday: Set<Prayer> = []

    var completedCount: Int { completedToday.count }
    var isComplete: Bool { completedToday.count == Prayer.allCases.count }

    /// Prayers this person hasn't completed today, in order.
    var missedToday: [Prayer] { Prayer.allCases.filter { !completedToday.contains($0) } }

    /// The earliest missed prayer you haven't already nudged them about, if any.
    var nudgeablePrayer: Prayer? { missedToday.first { !nudgedToday.contains($0) } }

    var initials: String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }
}

