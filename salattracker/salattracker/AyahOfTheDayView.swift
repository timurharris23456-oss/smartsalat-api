//
//  AyahOfTheDayView.swift
//  salattracker
//

import SwiftUI

struct AyahOfTheDayView: View {
    let ayah: Ayah
    var userName: String? = nil
    var now: Date = Date()

    /// "[Name]'s Personal Ayah", falling back to "Personal Ayah" when signed out.
    private var title: String {
        if let userName, !userName.isEmpty {
            return "\(userName)'s Personal Ayah"
        }
        return "Personal Ayah"
    }

    /// Time left until the ayah changes (the user's next local midnight).
    private var countdown: String {
        let calendar = Calendar.current
        guard let nextMidnight = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return "" }
        let remaining = max(0, Int(nextMidnight.timeIntervalSince(now)))
        let minutes = remaining / 60
        return String(format: "Changing in %02d:%02d", minutes / 60, minutes % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.caption)
                Text(title)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
                Text(countdown)
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Theme.primary.opacity(0.55))
            }
            .foregroundStyle(Theme.primary)

            Text(ayah.arabic)
                .font(.system(size: 23, weight: .medium))
                .foregroundStyle(Theme.text)
                .lineSpacing(10)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .environment(\.layoutDirection, .rightToLeft)

            Text(ayah.translation)
                .font(.subheadline)
                .foregroundStyle(Theme.text.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            Text(ayah.reference)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.subtle)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .softCard()
        .transition(.opacity.combined(with: .move(edge: .top)))
        .id(ayah.id)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        AyahOfTheDayView(ayah: AyahLibrary.all[1], userName: "Aisha", now: .now)
            .padding()
    }
}
