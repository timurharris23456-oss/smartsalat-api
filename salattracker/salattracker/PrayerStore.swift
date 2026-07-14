//
//  PrayerStore.swift
//  salattracker
//

import Foundation
import Combine
import CoreLocation

@MainActor
final class PrayerStore: ObservableObject {
    @Published private(set) var records: [String: DayRecord] = [:]
    @Published private(set) var todayTimes: [Prayer: Date] = [:]
    @Published private(set) var tomorrowFajr: Date?
    @Published private(set) var sunrise: Date?
    @Published private(set) var hasPreciseLocation = false
    @Published private(set) var selectedCity: City?

    private enum Keys {
        static let latitude = "savedLatitude"
        static let longitude = "savedLongitude"
        /// Records are cached per account so signed-in users never see each other's data.
        static func records(for username: String) -> String { "prayerRecords_\(username)" }
    }

    private let service = PrayerTimeService()
    private let api = APIClient()
    private var coordinate: CLLocationCoordinate2D?
    private var computedForDayKey = ""

    /// The signed-in account this store is syncing for.
    private var session: (username: String, token: String)?

    /// Times are displayed in the selected city's local time zone,
    /// or the device's when following GPS.
    var displayTimeZone: TimeZone {
        selectedCity?.timeZone ?? .current
    }

    /// The coordinate the app is currently using (selected city, GPS fix,
    /// or a time-zone estimate) — used for the Qibla direction.
    var currentCoordinate: CLLocationCoordinate2D { effectiveCoordinate }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    func start() {
        loadSavedLocation()
        reloadPreferences()
    }

    // MARK: - Account session & sync

    /// Begin syncing for a signed-in account: show the local cache instantly,
    /// then pull the latest from the server.
    func startSession(username: String, token: String) {
        session = (username, token)
        loadRecords(for: username)
        recomputeTimes()
        Task { await syncDown() }
    }

    /// Clear the current account's data from memory on sign out.
    func endSession() {
        session = nil
        records = [:]
    }

    /// Pull the account's records from the server (server is source of truth on login).
    func syncDown() async {
        guard let session else { return }
        do {
            let remote = try await api.fetchRecords(token: session.token)
            records = remote.mapValues { day in
                DayRecord(
                    fard: Set(day.fard.compactMap(Prayer.init(rawValue:))),
                    sunnah: Set(day.sunnah.compactMap(Prayer.init(rawValue:))),
                    witr: day.witr
                )
            }
            saveRecords()
        } catch {
            // Offline / server down — keep the local cache.
        }
    }

    /// Push local records up to the account.
    func syncUp() async {
        guard let session else { return }
        let remote = records.mapValues { rec in
            APIClient.RemoteDay(
                fard: rec.fard.map(\.rawValue),
                sunnah: rec.sunnah.map(\.rawValue),
                witr: rec.witr
            )
        }
        try? await api.saveRecords(remote, token: session.token)
    }

    /// Re-reads the selected city and calculation settings (edited in
    /// SettingsView via UserDefaults) and recomputes times.
    func reloadPreferences() {
        selectedCity = City.loadSelected()
        recomputeTimes()
    }

    /// Recomputes prayer times when the calendar day rolls over.
    func tick(now: Date) {
        if Self.dayKey(for: now) != computedForDayKey {
            recomputeTimes(now: now)
        }
    }

    // MARK: - Daily records

    static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    func record(for date: Date) -> DayRecord {
        records[Self.dayKey(for: date)] ?? DayRecord()
    }

    func toggleFard(_ prayer: Prayer, on date: Date = Date()) {
        var rec = record(for: date)
        if rec.fard.contains(prayer) {
            rec.fard.remove(prayer)
        } else {
            rec.fard.insert(prayer)
        }
        records[Self.dayKey(for: date)] = rec
        persist()
    }

    func toggleSunnah(_ prayer: Prayer, on date: Date = Date()) {
        var rec = record(for: date)
        if rec.sunnah.contains(prayer) {
            rec.sunnah.remove(prayer)
        } else {
            rec.sunnah.insert(prayer)
        }
        records[Self.dayKey(for: date)] = rec
        persist()
    }

    func toggleWitr(on date: Date = Date()) {
        var rec = record(for: date)
        rec.witr.toggle()
        records[Self.dayKey(for: date)] = rec
        persist()
    }

    // MARK: - History

    /// The earliest day the user has any record for (else today).
    var startDate: Date {
        let calendar = Calendar.current
        let recorded = records.keys.compactMap { Self.dayKeyFormatter.date(from: $0) }
        return recorded.min().map { calendar.startOfDay(for: $0) }
            ?? calendar.startOfDay(for: Date())
    }

    /// Days to show in history — from the start date up to today, but never
    /// more than `maxDays` back. Newest first.
    func historyDates(maxDays: Int = 30) -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let earliestAllowed = calendar.date(byAdding: .day, value: -(maxDays - 1), to: today) ?? today
        let start = max(startDate, earliestAllowed)
        var dates: [Date] = []
        var day = today
        while day >= start {
            dates.append(day)
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return dates
    }

    /// Consecutive days with at least one fard prayer completed. Today counts
    /// once its first prayer is marked; an untouched today doesn't break
    /// yesterday's run.
    var streak: Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date())
        if !record(for: day).countsForStreak {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while record(for: day).countsForStreak {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    private func loadRecords(for username: String) {
        guard let data = UserDefaults.standard.data(forKey: Keys.records(for: username)),
              let decoded = try? JSONDecoder().decode([String: DayRecord].self, from: data) else {
            records = [:]
            return
        }
        records = decoded
    }

    private func saveRecords() {
        guard let session,
              let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: Keys.records(for: session.username))
    }

    /// Save locally and push to the server (for user-initiated changes).
    private func persist() {
        saveRecords()
        Task { await syncUp() }
    }

    // MARK: - Location & prayer times

    /// Saves a fresh fix from LocationManager and recomputes times.
    func updateLocation(_ coordinate: CLLocationCoordinate2D) {
        guard Self.isPlausible(coordinate) else { return }
        self.coordinate = coordinate
        hasPreciseLocation = true
        UserDefaults.standard.set(coordinate.latitude, forKey: Keys.latitude)
        UserDefaults.standard.set(coordinate.longitude, forKey: Keys.longitude)
        recomputeTimes()
    }

    private func loadSavedLocation() {
        let defaults = UserDefaults.standard
        if let lat = defaults.object(forKey: Keys.latitude) as? Double,
           let lng = defaults.object(forKey: Keys.longitude) as? Double {
            let saved = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            guard Self.isPlausible(saved) else { return }
            coordinate = saved
            hasPreciseLocation = true
        }
    }

    /// A coordinate far outside the device's time zone is almost certainly
    /// a simulator default (e.g. Apple Park while the Mac is set to New
    /// York) — ignore it rather than show times for the wrong region. On
    /// real devices the time zone follows the location, so real fixes pass.
    private static func isPlausible(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let zoneMeridian = Double(TimeZone.current.secondsFromGMT()) / 3600 * 15
        var delta = abs(coordinate.longitude - zoneMeridian)
        if delta > 180 { delta = 360 - delta }
        return delta <= 45
    }

    private func recomputeTimes(now: Date = Date()) {
        let coordinate = effectiveCoordinate
        let timeZone = displayTimeZone
        let today = service.prayers(on: now, at: coordinate, timeZone: timeZone)
        todayTimes = Self.timesByPrayer(today)
        sunrise = today?.sunrise
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now) {
            tomorrowFajr = service.prayers(on: tomorrow, at: coordinate, timeZone: timeZone)?.fajr
        }
        computedForDayKey = Self.dayKey(for: now)
        scheduleNotifications()
    }

    /// (Re)schedule prayer-time notifications for the current location/city.
    func scheduleNotifications() {
        NotificationScheduler.shared.rescheduleUpcoming(
            service: service,
            coordinate: effectiveCoordinate,
            timeZone: displayTimeZone
        )
    }

    /// Whether `date` falls between today's sunrise and sunset (Maghrib),
    /// driving the Dynamic appearance mode. Assumes daytime until times load.
    func isDaytime(at date: Date) -> Bool {
        guard let sunrise, let sunset = todayTimes[.maghrib] else { return true }
        return date >= sunrise && date < sunset
    }

    private static func timesByPrayer(_ daily: DailyPrayers?) -> [Prayer: Date] {
        guard let daily else { return [:] }
        return [
            .fajr: daily.fajr,
            .dhuhr: daily.dhuhr,
            .asr: daily.asr,
            .maghrib: daily.maghrib,
            .isha: daily.isha,
        ]
    }

    /// The selected city wins; otherwise the GPS fix. Until either exists,
    /// place the user from their time zone: a known city in the same zone
    /// if we have one, else a rough estimate from the UTC offset.
    private var effectiveCoordinate: CLLocationCoordinate2D {
        if let selectedCity {
            return CLLocationCoordinate2D(latitude: selectedCity.latitude, longitude: selectedCity.longitude)
        }
        if let coordinate {
            return coordinate
        }
        if let zoneCity = City.all.first(where: { $0.timeZoneID == TimeZone.current.identifier }) {
            return CLLocationCoordinate2D(latitude: zoneCity.latitude, longitude: zoneCity.longitude)
        }
        let offsetHours = Double(TimeZone.current.secondsFromGMT()) / 3600
        return CLLocationCoordinate2D(latitude: 30, longitude: offsetHours * 15)
    }
}
