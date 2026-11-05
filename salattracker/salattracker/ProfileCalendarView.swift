//
//  ProfileCalendarView.swift
//  salattracker
//
//  A tapped profile's monthly prayer calendar: each day they prayed is green
//  with the number of prayers that day; days they didn't are gray. The total
//  for the month is shown at the top. Works for a friend or your own "You" row.
//

import SwiftUI

struct ProfileCalendarView: View {
    let entry: StreakEntry
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var monthAnchor = Date()
    @State private var days: [String: Int] = [:]
    @State private var total = 0
    @State private var loading = true
    @State private var failed = false

    private let calendar = Calendar.current

    private var targetUser: String { entry.isYou ? (auth.username ?? "") : entry.name }
    private var displayName: String { entry.isYou ? (auth.username ?? "You") : entry.name }

    private var initials: String {
        let letters = displayName.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }

    /// The displayed month as "YYYY-MM" — also the reload key.
    private var monthKey: String {
        let c = calendar.dateComponents([.year, .month], from: monthAnchor)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private let monthLabel: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "LLLL yyyy"; return f
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    person
                    totalCard
                    monthNav
                    grid
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Prayer Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .task(id: monthKey) { await loadMonth() }
    }

    // MARK: - Pieces

    private var person: some View {
        HStack(spacing: 12) {
            AvatarView(initials: initials, imageData: entry.avatar, size: 52)
            Text(displayName)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.text)
            Spacer()
        }
    }

    private var totalCard: some View {
        VStack(spacing: 4) {
            Text("Total prayers completed")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(Theme.subtle)
            Text("\(total)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.primary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .softCard()
    }

    private var monthNav: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.headline).foregroundStyle(Theme.primary)
            }
            Spacer()
            Text(monthLabel.string(from: monthAnchor))
                .font(.headline)
                .foregroundStyle(Theme.text)
            Spacer()
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right")
                    .font(.headline)
                    .foregroundStyle(canGoForward ? Theme.primary : Theme.subtle.opacity(0.4))
            }
            .disabled(!canGoForward)
        }
        .padding(.horizontal, 4)
    }

    private var grid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(weekdaySymbols.indices, id: \.self) { i in
                    Text(weekdaySymbols[i])
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.subtle)
                        .frame(maxWidth: .infinity)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 42)
                    }
                }
            }
            if failed {
                Text("Couldn't load this month.")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
                    .padding(.top, 6)
            }
        }
        .padding()
        .softCard()
        .opacity(loading ? 0.5 : 1)
        .overlay { if loading { ProgressView() } }
    }

    private func dayCell(_ day: Int) -> some View {
        let count = days[dateKey(day)] ?? 0
        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(count > 0 ? Theme.accent : Theme.subtle.opacity(0.12))
            .frame(height: 42)
            .overlay(
                Text(count > 0 ? "\(count)" : "\(day)")
                    .font(count > 0 ? .subheadline.weight(.bold) : .caption2)
                    .foregroundStyle(count > 0 ? .white : Theme.subtle)
            )
    }

    // MARK: - Calendar math

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    /// Leading blanks (nil) followed by the day numbers of the month.
    private var monthCells: [Int?] {
        let c = calendar.dateComponents([.year, .month], from: monthAnchor)
        guard let first = calendar.date(from: c),
              let range = calendar.range(of: .day, in: .month, for: first) else { return [] }
        let weekday = calendar.component(.weekday, from: first)
        let leading = (weekday - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading) + range.map { Optional($0) }
    }

    private func dateKey(_ day: Int) -> String {
        let c = calendar.dateComponents([.year, .month], from: monthAnchor)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, day)
    }

    private var canGoForward: Bool {
        let now = calendar.dateComponents([.year, .month], from: Date())
        let shown = calendar.dateComponents([.year, .month], from: monthAnchor)
        return (shown.year ?? 0, shown.month ?? 0) < (now.year ?? 0, now.month ?? 0)
    }

    private func shiftMonth(_ delta: Int) {
        if let d = calendar.date(byAdding: .month, value: delta, to: monthAnchor) {
            monthAnchor = d
        }
    }

    private func loadMonth() async {
        loading = true
        failed = false
        do {
            let result = try await auth.calendar(for: targetUser, month: monthKey)
            days = result.days
            total = result.total
        } catch {
            failed = true
            days = [:]
            total = 0
        }
        loading = false
    }
}
