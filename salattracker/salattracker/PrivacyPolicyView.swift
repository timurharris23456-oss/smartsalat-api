//
//  PrivacyPolicyView.swift
//  salattracker
//

import SwiftUI

struct PrivacyPolicyView: View {
    /// When set, the view is the acceptance gate (shows "I Agree"). When nil,
    /// it's read-only (e.g. opened from Settings).
    var onAccept: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Privacy Policy")
                            .font(.largeTitle.bold())
                            .foregroundStyle(Theme.text)
                        Text("Effective \(PrivacyPolicy.effectiveDate)")
                            .font(.footnote)
                            .foregroundStyle(Theme.subtle)
                    }

                    ForEach(Array(PrivacyPolicy.sections.enumerated()), id: \.offset) { _, section in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(section.title)
                                .font(.headline)
                                .foregroundStyle(Theme.text)
                            Text(section.body)
                                .font(.subheadline)
                                .foregroundStyle(Theme.text.opacity(0.85))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    if onAccept != nil {
                        Color.clear.frame(height: 90) // room for the pinned button
                    }
                }
                .padding()
            }

            if let onAccept {
                acceptBar(onAccept)
            }
        }
        .toolbar {
            if onAccept == nil {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func acceptBar(_ onAccept: @escaping () -> Void) -> some View {
        VStack(spacing: 10) {
            Text("By continuing, you agree to this Privacy Policy.")
                .font(.caption)
                .foregroundStyle(Theme.subtle)
            Button(action: onAccept) {
                Text("I Agree & Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding()
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }
}

#Preview {
    PrivacyPolicyView(onAccept: {})
}
