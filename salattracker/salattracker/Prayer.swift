//
//  Prayer.swift
//  salattracker
//

import Foundation

enum Prayer: String, CaseIterable, Codable, Identifiable {
    case fajr, dhuhr, asr, maghrib, isha

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fajr: "Fajr"
        case .dhuhr: "Dhuhr"
        case .asr: "Asr"
        case .maghrib: "Maghrib"
        case .isha: "Isha"
        }
    }

    var arabicName: String {
        switch self {
        case .fajr: "الفجر"
        case .dhuhr: "الظهر"
        case .asr: "العصر"
        case .maghrib: "المغرب"
        case .isha: "العشاء"
        }
    }

    var fardRakats: Int {
        switch self {
        case .fajr: 2
        case .dhuhr: 4
        case .asr: 4
        case .maghrib: 3
        case .isha: 4
        }
    }

    var sunnahDescription: String {
        switch self {
        case .fajr: "2 before"
        case .dhuhr: "4 before · 2 after"
        case .asr: "4 before (optional)"
        case .maghrib: "2 after"
        case .isha: "2 after"
        }
    }

    var symbolName: String {
        switch self {
        case .fajr: "sunrise.fill"
        case .dhuhr: "sun.max.fill"
        case .asr: "sun.min.fill"
        case .maghrib: "sunset.fill"
        case .isha: "moon.stars.fill"
        }
    }
}

struct DayRecord: Codable {
    var fard: Set<Prayer> = []
    var sunnah: Set<Prayer> = []
    /// Witr prayer, prayed after Isha.
    var witr: Bool = false

    /// All five fard prayers done — a "perfect" day.
    var isComplete: Bool { fard.count == Prayer.allCases.count }

    /// Whether this day keeps the streak alive: at least one fard prayer.
    var countsForStreak: Bool { !fard.isEmpty }

    init(fard: Set<Prayer> = [], sunnah: Set<Prayer> = [], witr: Bool = false) {
        self.fard = fard
        self.sunnah = sunnah
        self.witr = witr
    }

    /// Tolerant decoding so records saved before `witr` existed still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fard = try c.decodeIfPresent(Set<Prayer>.self, forKey: .fard) ?? []
        sunnah = try c.decodeIfPresent(Set<Prayer>.self, forKey: .sunnah) ?? []
        witr = try c.decodeIfPresent(Bool.self, forKey: .witr) ?? false
    }
}
