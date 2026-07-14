import Foundation
import Adhan
import CoreLocation

struct DailyPrayers {
    let date: Date
    let fajr: Date
    let sunrise: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date

    var all: [(name: String, time: Date)] {
        [("Fajr", fajr), ("Sunrise", sunrise), ("Dhuhr", dhuhr),
         ("Asr", asr), ("Maghrib", maghrib), ("Isha", isha)]
    }
}

final class PrayerTimeService {

    func calculationParams() -> CalculationParameters {
        let methodName = UserDefaults.standard.string(forKey: "calcMethod") ?? "northAmerica"

        var params: CalculationParameters
        switch methodName {
        case "muslimWorldLeague": params = CalculationMethod.muslimWorldLeague.params
        case "egyptian":          params = CalculationMethod.egyptian.params
        case "karachi":           params = CalculationMethod.karachi.params
        case "ummAlQura":         params = CalculationMethod.ummAlQura.params
        case "dubai":             params = CalculationMethod.dubai.params
        case "kuwait":            params = CalculationMethod.kuwait.params
        case "qatar":             params = CalculationMethod.qatar.params
        case "singapore":         params = CalculationMethod.singapore.params
        case "turkey":            params = CalculationMethod.turkey.params
        case "tehran":            params = CalculationMethod.tehran.params
        default:                  params = CalculationMethod.northAmerica.params // ISNA
        }
        // Standard Asr (Shafi/Maliki/Hanbali) — the most universal default.
        params.madhab = .shafi
        return params
    }

    func prayers(on date: Date, at coordinate: CLLocationCoordinate2D,
                 timeZone: TimeZone = .current) -> DailyPrayers? {
        let coords = Coordinates(latitude: coordinate.latitude,
                                 longitude: coordinate.longitude)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.year, .month, .day], from: date)

        guard let times = PrayerTimes(coordinates: coords,
                                      date: comps,
                                      calculationParameters: calculationParams())
        else { return nil }

        return DailyPrayers(date: date,
                            fajr: times.fajr, sunrise: times.sunrise,
                            dhuhr: times.dhuhr, asr: times.asr,
                            maghrib: times.maghrib, isha: times.isha)
    }

    /// The next upcoming prayer from now (checks today, then tomorrow's Fajr).
    func nextPrayer(at coordinate: CLLocationCoordinate2D) -> (name: String, time: Date)? {
        let now = Date()
        if let today = prayers(on: now, at: coordinate),
           let next = today.all.first(where: { $0.time > now && $0.name != "Sunrise" }) {
            return next
        }
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: now)!
        if let t = prayers(on: tomorrow, at: coordinate) {
            return ("Fajr", t.fajr)
        }
        return nil
    }
}
