//
//  PrayerCard.swift
//  salattracker
//

import SwiftUI

struct PrayerCard: View {
    let prayer: Prayer
    let time: Date?
    let isNext: Bool
    let countdown: String?
    let hasArrived: Bool
    let fardDone: Bool
    let sunnahDone: Bool
    let onToggleFard: () -> Void
    let onToggleSunnah: () -> Void
    var timeZone: TimeZone = .current
    /// Witr state, shown only for Isha (nil hides the row).
    var witrDone: Bool? = nil
    var onToggleWitr: (() -> Void)? = nil

    private var timeText: String {
        guard let time else { return "--:--" }
        return time.formatted(
            Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone)
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                icon

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(prayer.name)
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        Text(prayer.arabicName)
                            .font(.subheadline)
                            .foregroundStyle(Theme.subtle)
                        if isNext { nextBadge }
                    }
                    HStack(spacing: 6) {
                        Text(timeText)
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(hasArrived ? Theme.text : Theme.subtle)
                        if isNext, let countdown {
                            Text(countdown)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                    Text("Fard · \(prayer.fardRakats) rakats")
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                }

                Spacer(minLength: 4)

                if hasArrived {
                    Button(action: onToggleFard) {
                        Image(systemName: fardDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 34))
                            .foregroundStyle(fardDone ? Theme.accent : Theme.subtle.opacity(0.45))
                            .contentTransition(.symbolEffect(.replace))
                            .symbolEffect(.bounce, value: fardDone)
                    }
                    .buttonStyle(PressableStyle())
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.subtle.opacity(0.5))
                        .frame(width: 34, height: 34)
                }
            }

            Divider().overlay(Theme.subtle.opacity(0.2))

            HStack(spacing: 8) {
                Text("Sunnah")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.text)
                Text(prayer.sunnahDescription)
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
                Spacer()
                if hasArrived {
                    Button(action: onToggleSunnah) {
                        HStack(spacing: 5) {
                            Image(systemName: sunnahDone ? "checkmark.circle.fill" : "circle")
                                .contentTransition(.symbolEffect(.replace))
                                .symbolEffect(.bounce, value: sunnahDone)
                            Text(sunnahDone ? "Prayed" : "Mark")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(sunnahDone ? Theme.accent : Theme.subtle)
                    }
                    .buttonStyle(PressableStyle())
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "lock.fill")
                        Text("Locked")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.subtle.opacity(0.5))
                }
            }

            if let witrDone {
                Divider().overlay(Theme.subtle.opacity(0.2))

                HStack(spacing: 8) {
                    Text("Witr")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.text)
                    Text("after Isha · 1–3 rakats")
                        .font(.caption)
                        .foregroundStyle(Theme.subtle)
                    Spacer()
                    if hasArrived {
                        Button { onToggleWitr?() } label: {
                            HStack(spacing: 5) {
                                Image(systemName: witrDone ? "checkmark.circle.fill" : "circle")
                                    .contentTransition(.symbolEffect(.replace))
                                    .symbolEffect(.bounce, value: witrDone)
                                Text(witrDone ? "Prayed" : "Mark")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(witrDone ? Theme.accent : Theme.subtle)
                        }
                        .buttonStyle(PressableStyle())
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: "lock.fill")
                            Text("Locked")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.subtle.opacity(0.5))
                    }
                }
            }
        }
        .padding(18)
        .softCard(elevated: isNext)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1.5)
        )
        .overlay(alignment: .leading) {
            // A soft accent rail down the left edge of a completed prayer.
            RoundedRectangle(cornerRadius: 3)
                .fill(Theme.accent)
                .frame(width: 4)
                .padding(.vertical, 22)
                .opacity(fardDone ? 1 : 0)
        }
        .opacity(hasArrived ? 1 : 0.6)
        .sensoryFeedback(.impact(weight: .light), trigger: fardDone)
        .sensoryFeedback(.selection, trigger: sunnahDone)
        .sensoryFeedback(.selection, trigger: witrDone)
        .animation(Theme.motion, value: fardDone)
        .animation(Theme.motion, value: isNext)
        .animation(Theme.motion, value: hasArrived)
    }

    private var icon: some View {
        Image(systemName: prayer.symbolName)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(iconGradient, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .shadow(color: iconShadow.opacity(hasArrived ? 0.5 : 0), radius: 6, y: 3)
            .saturation(hasArrived ? 1 : 0)
    }

    private var nextBadge: some View {
        Text("NEXT")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Theme.primary, in: Capsule())
            .foregroundStyle(.white)
    }

    private var borderColor: Color {
        if isNext { return Theme.primary.opacity(0.55) }
        if fardDone { return Theme.accent.opacity(0.28) }
        return .clear
    }

    private var iconGradient: LinearGradient {
        let colors: [Color] = switch prayer {
        case .fajr: [Color(hex: 0x6366F1), Color(hex: 0xF59E0B)]
        case .dhuhr: [Color(hex: 0xFBBF24), Color(hex: 0xF97316)]
        case .asr: [Color(hex: 0xFB923C), Color(hex: 0xEF4444)]
        case .maghrib: [Color(hex: 0xF472B6), Color(hex: 0x7C3AED)]
        case .isha: [Color(hex: 0x4F46E5), Color(hex: 0x1E1B4B)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var iconShadow: Color {
        switch prayer {
        case .fajr: Color(hex: 0xF59E0B)
        case .dhuhr: Color(hex: 0xF97316)
        case .asr: Color(hex: 0xEF4444)
        case .maghrib: Color(hex: 0x7C3AED)
        case .isha: Color(hex: 0x4F46E5)
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 16) {
            PrayerCard(
                prayer: .fajr,
                time: .now,
                isNext: true,
                countdown: "in 1h 05m",
                hasArrived: false,
                fardDone: false,
                sunnahDone: false,
                onToggleFard: {},
                onToggleSunnah: {}
            )
            PrayerCard(
                prayer: .dhuhr,
                time: .now,
                isNext: false,
                countdown: nil,
                hasArrived: true,
                fardDone: true,
                sunnahDone: true,
                onToggleFard: {},
                onToggleSunnah: {}
            )
        }
        .padding()
    }
}
