//
//  HistoryView.swift
//  salattracker
//
//  Review and edit the last month of prayer records — tap any prayer to
//  correct a day you forgot to mark.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: PrayerStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Tap a prayer to mark or unmark it. Editing past days updates your streak.")
                    .font(.footnote)
                    .foregroundStyle(Theme.subtle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(store.historyDates(), id: \.self) { date in
                    DayHistoryRow(
                        date: date,
                        record: store.record(for: date),
                        onToggleFard: { store.toggleFard($0, on: date) },
                        onToggleWitr: { store.toggleWitr(on: date) }
                    )
                }
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DayHistoryRow: View {
    let date: Date
    let record: DayRecord
    let onToggleFard: (Prayer) -> Void
    let onToggleWitr: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(relativeLabel)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                }
                Spacer()
                if record.isComplete {
                    Label("Complete", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .labelStyle(.iconOnly)
                        .imageScale(.large)
                } else {
                    Text("\(record.fard.count)/5")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(Theme.subtle)
                }
            }

            HStack(spacing: 6) {
                ForEach(Prayer.allCases) { prayer in
                    prayerToggle(
                        title: prayer.name,
                        on: record.fard.contains(prayer),
                        action: { onToggleFard(prayer) }
                    )
                }
                prayerToggle(title: "Witr", on: record.witr, action: onToggleWitr)
            }
        }
        .padding(16)
        .softCard()
    }

    private func prayerToggle(title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(on ? Theme.accent : Theme.subtle.opacity(0.45))
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(on ? Theme.text : Theme.subtle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: on)
    }

    private var relativeLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.wide))
    }
}
