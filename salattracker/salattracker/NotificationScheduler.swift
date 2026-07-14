import UserNotifications
import CoreLocation

final class NotificationScheduler {
    static let shared = NotificationScheduler()

    /// Ask for permission to send prayer-time alerts. Returns whether granted.
    @discardableResult
    func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Schedule a local notification at each upcoming prayer time for the next
    /// `days` days. Re-run whenever times change; it clears and re-adds.
    func rescheduleUpcoming(service: PrayerTimeService,
                            coordinate: CLLocationCoordinate2D,
                            timeZone: TimeZone = .current,
                            days: Int = 7) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let now = Date()

        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now),
                  let prayers = service.prayers(on: day, at: coordinate, timeZone: timeZone) else { continue }

            for prayer in prayers.all where prayer.name != "Sunrise" {
                guard prayer.time > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = prayer.name
                content.body = "\(prayer.name) has arrived! Complete it and Allah will reward you!"
                content.sound = .default

                var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: prayer.time)
                comps.timeZone = timeZone   // fire at the right instant even for a selected city
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let id = "\(prayer.name)-\(comps.year!)-\(comps.month!)-\(comps.day!)"

                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }
}
