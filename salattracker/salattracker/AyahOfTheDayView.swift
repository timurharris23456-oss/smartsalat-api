//
//  AyahOfTheDayView.swift
//  salattracker
//

import SwiftUI

struct AyahOfTheDayView: View {
    let ayah: Ayah

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.caption)
                Text("Ayah of the Day")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
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
        AyahOfTheDayView(ayah: AyahLibrary.all[1])
            .padding()
    }
}
