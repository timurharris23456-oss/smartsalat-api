//
//  QiblaView.swift
//  salattracker
//
//  Live Qibla compass: points toward the Kaaba in Mecca using the device
//  heading and the user's location (Adhan's Qibla direction).
//

import SwiftUI
import CoreLocation
import Adhan

struct QiblaView: View {
    @ObservedObject var store: PrayerStore
    @ObservedObject var locationManager: LocationManager

    private static let kaaba = CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262)

    /// Qibla bearing in degrees clockwise from true north.
    private var qiblaBearing: Double {
        let c = store.currentCoordinate
        return Qibla(coordinates: Coordinates(latitude: c.latitude, longitude: c.longitude)).direction
    }

    private var heading: Double? { locationManager.heading }

    /// A continuous, unwrapped heading for the visuals so rotation always
    /// takes the shortest path across north (no 359°→0° spin glitch).
    @State private var displayedHeading: Double = 0
    @State private var hasHeading = false

    /// Angle (from the top of the screen) at which to draw the Qibla marker:
    /// its bearing minus where the phone is pointing.
    private var markerAngle: Double { qiblaBearing - (heading ?? 0) }

    /// How far off from facing the Qibla, in degrees (0 = aligned).
    private var offBy: Double {
        let raw = (markerAngle.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        return min(raw, 360 - raw)
    }

    private var isAligned: Bool { heading != nil && offBy <= 6 }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 8)
            compass
            Spacer(minLength: 8)
            readout
            Spacer()
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            locationManager.startHeading()
            updateDisplayedHeading(locationManager.heading)
        }
        .onDisappear { locationManager.stopHeading() }
        .onChange(of: locationManager.heading) { _, newHeading in
            updateDisplayedHeading(newHeading)
        }
    }

    /// Advances `displayedHeading` by the shortest signed delta to the new
    /// reading, keeping the value continuous across the 0/360 boundary.
    private func updateDisplayedHeading(_ newHeading: Double?) {
        guard let newHeading else { return }
        guard hasHeading else {
            hasHeading = true
            displayedHeading = newHeading
            return
        }
        var delta = (newHeading - displayedHeading).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 } else if delta < -180 { delta += 360 }
        withAnimation(.easeOut(duration: 0.15)) {
            displayedHeading += delta
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Face the Kaaba in Mecca")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.primary)
            Text("Qibla Finder")
                .font(.largeTitle.bold())
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var compass: some View {
        ZStack {
            // Outer dial that rotates so N stays at true north.
            CompassDial()
                .rotationEffect(.degrees(-displayedHeading))

            // Fixed reference pointer at the top (the way the phone faces).
            VStack {
                Triangle()
                    .fill(isAligned ? Theme.accent : Theme.subtle)
                    .frame(width: 20, height: 12)
                Spacer()
            }
            .padding(.top, -6)

            // Qibla marker on the dial (drawn at its bearing on the dial).
            qiblaMarker
                .rotationEffect(.degrees(qiblaBearing - displayedHeading))

            // Center hub.
            Circle()
                .fill(Theme.surface)
                .frame(width: 74, height: 74)
                .shadow(color: Theme.shadow.opacity(0.2), radius: 8, y: 4)
            VStack(spacing: 2) {
                Text("\(Int(qiblaBearing.rounded()))°")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(Theme.text)
                Text(cardinal(qiblaBearing))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.subtle)
            }
        }
        .frame(width: 300, height: 300)
    }

    private var qiblaMarker: some View {
        VStack(spacing: 4) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 26))
                .foregroundStyle(isAligned ? Theme.accent : Theme.primary)
            Text("🕋")
                .font(.system(size: 24))
            Spacer()
        }
        .frame(height: 300)
    }

    private var readout: some View {
        VStack(spacing: 10) {
            if isAligned {
                Label("Facing the Qibla", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.accent)
            } else if heading != nil {
                Text("Turn \(turnHint)")
                    .font(.headline)
                    .foregroundStyle(Theme.text)
            } else {
                Label("Compass unavailable on this device", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtle)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 24) {
                stat(title: "Qibla", value: "\(Int(qiblaBearing.rounded()))° \(cardinal(qiblaBearing))")
                stat(title: "Distance to Mecca", value: distanceString)
            }
            .padding(.top, 4)

            Text(store.selectedCity.map { "From \($0.id)" } ?? "From your location")
                .font(.caption)
                .foregroundStyle(Theme.subtle)
        }
        .padding(.bottom, 8)
    }

    private func stat(title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.callout.weight(.bold))
                .foregroundStyle(Theme.text)
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.surface)
        )
    }

    // MARK: - Helpers

    private var turnHint: String {
        // Positive markerAngle means the Qibla is to the right; rotate the phone that way.
        let signed = (markerAngle.truncatingRemainder(dividingBy: 360) + 540)
            .truncatingRemainder(dividingBy: 360) - 180
        let dir = signed >= 0 ? "right" : "left"
        return "\(dir) \(Int(offBy.rounded()))°"
    }

    private func cardinal(_ deg: Double) -> String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let i = Int((deg / 45).rounded()) % 8
        return dirs[(i + 8) % 8]
    }

    private var distanceString: String {
        let c = store.currentCoordinate
        let here = CLLocation(latitude: c.latitude, longitude: c.longitude)
        let mecca = CLLocation(latitude: Self.kaaba.latitude, longitude: Self.kaaba.longitude)
        let km = here.distance(from: mecca) / 1000
        return km >= 100 ? "\(Int(km.rounded())) km" : String(format: "%.1f km", km)
    }
}

/// A compass dial with cardinal labels and tick marks.
private struct CompassDial: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.surface)
                .shadow(color: Theme.shadow.opacity(0.18), radius: 16, y: 8)
            Circle()
                .strokeBorder(Theme.subtle.opacity(0.25), lineWidth: 1)

            ForEach(0..<72) { i in
                Rectangle()
                    .fill(Theme.subtle.opacity(i % 9 == 0 ? 0.7 : 0.3))
                    .frame(width: i % 9 == 0 ? 2.5 : 1.5, height: i % 9 == 0 ? 14 : 7)
                    .offset(y: -136)
                    .rotationEffect(.degrees(Double(i) / 72 * 360))
            }

            ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { idx, label in
                Text(label)
                    .font(.headline.bold())
                    .foregroundStyle(label == "N" ? Theme.primary : Theme.subtle)
                    .rotationEffect(.degrees(-Double(idx) * 90)) // keep glyph upright
                    .offset(y: -110)
                    .rotationEffect(.degrees(Double(idx) * 90))  // position around dial
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
