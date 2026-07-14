//
//  ContentView.swift
//  salattracker
//
//  Created by Timur Harris on 7/3/26.
//

import SwiftUI
import Combine
import UIKit

struct ContentView: View {
    @EnvironmentObject private var store: PrayerStore
    @EnvironmentObject private var auth: AuthManager
    @StateObject private var locationManager = LocationManager()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var now = Date()
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var appeared = false
    @State private var showCelebration = false
    @State private var selectedTab: Tab = .tracker
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dynamic

    private enum Tab { case tracker, qibla, streaks }

    private let clock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            Group {
                switch selectedTab {
                case .tracker: trackerScreen
                case .qibla: QiblaView(store: store, locationManager: locationManager)
                case .streaks: SalatStreaksView(store: store)
                }
            }
            .transition(.opacity)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { bottomBar }
        .task {
            store.start()
            locationManager.requestLocation()
            if await NotificationScheduler.shared.requestPermission() {
                store.scheduleNotifications()
            }
        }
        .onReceive(locationManager.$coordinate) { coordinate in
            if let coordinate {
                store.updateLocation(coordinate)
            }
        }
        .onReceive(clock) { date in
            now = date
            store.tick(now: date)
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSettings = false }
                        }
                    }
            }
            .environmentObject(auth)
            .preferredColorScheme(resolvedColorScheme)
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                HistoryView(store: store)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showHistory = false }
                        }
                    }
            }
            .preferredColorScheme(resolvedColorScheme)
        }
        .onChange(of: showSettings) { _, isShowing in
            if !isShowing {
                store.reloadPreferences()
                if store.selectedCity == nil {
                    locationManager.requestLocation()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, store.selectedCity == nil {
                locationManager.requestLocation()
            }
        }
        .onChange(of: store.record(for: now).countsForStreak) { wasCounting, isCounting in
            if isCounting && !wasCounting {
                withAnimation(.easeOut(duration: 0.3)) { showCelebration = true }
            }
        }
        .sensoryFeedback(.success, trigger: store.record(for: now).isComplete) { _, isComplete in
            isComplete
        }
        .sensoryFeedback(.impact(flexibility: .solid, intensity: 1), trigger: showCelebration) { _, shown in
            shown
        }
        .overlay {
            if showCelebration {
                StreakCelebrationView(streak: store.streak)
                    .contentShape(Rectangle())
                    .onTapGesture { dismissCelebration() }
                    .task {
                        try? await Task.sleep(for: .seconds(3))
                        dismissCelebration()
                    }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .preferredColorScheme(resolvedColorScheme)
    }

    /// Light/dark resolved from the appearance setting; Dynamic follows the sun.
    private var resolvedColorScheme: ColorScheme {
        switch appearanceMode {
        case .light: .light
        case .dark: .dark
        case .dynamic: store.isDaytime(at: now) ? .light : .dark
        }
    }

    private func dismissCelebration() {
        guard showCelebration else { return }
        withAnimation(.easeInOut(duration: 0.35)) { showCelebration = false }
    }

    // MARK: - Tracker screen

    private var trackerScreen: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                AyahOfTheDayView(
                    ayah: AyahLibrary.ayah(on: now, afterFajr: store.todayTimes[.fajr])
                )
                streakHero
                prayerList
                locationFootnote
                    .padding(.top, 4)
            }
            .animation(.easeInOut(duration: 0.4), value: AyahLibrary.ayah(on: now, afterFajr: store.todayTimes[.fajr]))
            .padding(.horizontal)
            .padding(.bottom, 16)
            .onAppear { appeared = true }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            tabButton(.tracker, label: "Salat Tracker") {
                Image("SujoodIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 26)
            }
            tabButton(.qibla, label: "Qibla Finder") {
                Image("QiblaIcon")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
            }
            tabButton(.streaks, label: "SalatStreaks") {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 20))
                    .frame(width: 40, height: 26)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background {
            Rectangle()
                .fill(.regularMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.subtle.opacity(0.2))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton<Icon: View>(_ tab: Tab, label: String, @ViewBuilder icon: () -> Icon) -> some View {
        Button {
            withAnimation(Theme.motion) { selectedTab = tab }
        } label: {
            VStack(spacing: 3) {
                icon()
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(selectedTab == tab ? Theme.primary : Theme.subtle)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(hijriDate)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                Text("SmartSalat")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.text)
                Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtle)
            }
            Spacer()
            HStack(spacing: 10) {
                circleButton("calendar") { showHistory = true }
                circleButton("gearshape.fill") { showSettings = true }
            }
        }
        .padding(.top, 8)
    }

    private func circleButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3)
                .foregroundStyle(Theme.subtle)
                .frame(width: 46, height: 46)
                .background(Theme.surface, in: Circle())
                .shadow(color: Theme.shadow.opacity(0.16), radius: 8, y: 4)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: - Streak hero

    private var streakHero: some View {
        let done = store.record(for: now).fard.count
        let total = Prayer.allCases.count
        let progress = Double(done) / Double(total)
        let complete = done == total
        let ringColor = complete ? Theme.accent : Theme.primary
        let message: String = done == 0
            ? "Pray one salah to keep your streak going"
            : complete
                ? "Mashallah — all prayers complete today"
                : "Streak secured · \(done) of \(total) today"

        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.glow.opacity(0.4))
                    .frame(width: 150, height: 150)
                    .blur(radius: 46)

                Circle()
                    .stroke(Theme.primary.opacity(0.14), lineWidth: 12)
                    .frame(width: 150, height: 150)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 150, height: 150)
                    .shadow(color: ringColor.opacity(0.4), radius: 6)

                Text("🔥")
                    .font(.system(size: 72))
                Text("\(store.streak)")
                    .font(.system(size: 27, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .contentTransition(.numericText())
                    .offset(y: 18)
            }
            .animation(.spring(response: 0.55, dampingFraction: 0.7), value: progress)
            .animation(.spring(response: 0.55, dampingFraction: 0.7), value: store.streak)

            VStack(spacing: 4) {
                Text("\(store.streak) day streak")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.text)
                    .contentTransition(.numericText())
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtle)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Prayer list

    private var prayerList: some View {
        let record = store.record(for: now)
        let next = nextPrayer
        return VStack(spacing: 16) {
            ForEach(Array(Prayer.allCases.enumerated()), id: \.element.id) { index, prayer in
                PrayerCard(
                    prayer: prayer,
                    time: store.todayTimes[prayer],
                    isNext: next?.prayer == prayer,
                    countdown: next.flatMap { $0.prayer == prayer ? countdownText(to: $0.time) : nil },
                    hasArrived: store.todayTimes[prayer].map { $0 <= now } ?? true,
                    fardDone: record.fard.contains(prayer),
                    sunnahDone: record.sunnah.contains(prayer),
                    onToggleFard: { store.toggleFard(prayer) },
                    onToggleSunnah: { store.toggleSunnah(prayer) },
                    timeZone: store.displayTimeZone,
                    witrDone: prayer == .isha ? record.witr : nil,
                    onToggleWitr: prayer == .isha ? { store.toggleWitr() } : nil
                )
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
                .animation(.spring(response: 0.5, dampingFraction: 0.82).delay(Double(index) * 0.07), value: appeared)
            }
        }
    }

    @ViewBuilder
    private var locationFootnote: some View {
        Group {
            if let city = store.selectedCity {
                Label("Times for \(city.id) · local time", systemImage: "building.2")
            } else if locationManager.isDenied {
                VStack(spacing: 6) {
                    Text("Location access is off — times shown are approximate.")
                    Button("Open Settings") {
                        openURL(URL(string: UIApplication.openSettingsURLString)!)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                }
            } else if !store.hasPreciseLocation {
                Label("Finding your location…", systemImage: "location")
            } else {
                Label("Times for your location", systemImage: "location.fill")
            }
        }
        .font(.caption)
        .foregroundStyle(Theme.subtle)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Derived values

    private var hijriDate: String {
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.locale = Locale(identifier: "en_US")
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: now) + " AH"
    }

    private var nextPrayer: (prayer: Prayer, time: Date)? {
        for prayer in Prayer.allCases {
            if let time = store.todayTimes[prayer], time > now {
                return (prayer, time)
            }
        }
        if let fajr = store.tomorrowFajr {
            return (.fajr, fajr)
        }
        return nil
    }

    private func countdownText(to date: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSince(now) / 60))
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "in \(h)h \(m)m" : "in \(m)m"
    }
}

#Preview {
    ContentView()
}
