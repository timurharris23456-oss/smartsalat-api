//
//  StreakCelebrationView.swift
//  salattracker
//
//  Full-screen reward shown when all five fard prayers are completed and
//  the day's streak ticks up: a flame burst with "Streak Updated!".
//

import SwiftUI

struct StreakCelebrationView: View {
    let streak: Int

    @State private var flameIn = false
    @State private var burst = false

    private let embers = (0..<24).map { _ in Ember.random() }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(flameIn ? 1 : 0)

            // Rising embers behind the flame.
            ZStack {
                ForEach(embers) { ember in
                    Text(ember.symbol)
                        .font(.system(size: ember.size))
                        .offset(
                            x: ember.xStart + (burst ? ember.drift : 0),
                            y: burst ? -ember.rise : 50
                        )
                        .opacity(burst ? 0 : 0.9)
                        .animation(
                            .easeOut(duration: ember.duration).delay(ember.delay),
                            value: burst
                        )
                }
            }
            .offset(y: -30)

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Theme.glow.opacity(0.55))
                        .frame(width: 220, height: 220)
                        .blur(radius: 55)
                        .scaleEffect(flameIn ? 1 : 0.3)
                    Text("🔥")
                        .font(.system(size: 132))
                        .scaleEffect(flameIn ? 1 : 0.2)
                        .rotationEffect(.degrees(flameIn ? 0 : -14))
                        .shadow(color: Theme.primary.opacity(0.5), radius: 24, y: 8)
                }

                VStack(spacing: 6) {
                    Text("Streak Updated!")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.text)
                    Text("\(streak) day streak")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Theme.primary)
                }
                .opacity(flameIn ? 1 : 0)
                .offset(y: flameIn ? 0 : 14)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                flameIn = true
            }
            burst = true
        }
    }
}

private struct Ember: Identifiable {
    let id = UUID()
    let xStart: CGFloat
    let drift: CGFloat
    let rise: CGFloat
    let size: CGFloat
    let delay: Double
    let duration: Double
    let symbol: String

    static func random() -> Ember {
        Ember(
            xStart: .random(in: -150...150),
            drift: .random(in: -45...45),
            rise: .random(in: 200...380),
            size: .random(in: 12...30),
            delay: .random(in: 0...0.45),
            duration: .random(in: 1.0...1.9),
            symbol: ["🔥", "✨", "🔥"].randomElement()!
        )
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        StreakCelebrationView(streak: 4)
    }
}
