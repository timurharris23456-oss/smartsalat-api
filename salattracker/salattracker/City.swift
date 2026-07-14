//
//  City.swift
//  salattracker
//

import Foundation

/// A selectable city for prayer time calculation. Times for a city are
/// computed at its coordinates and displayed in its local time zone.
struct City: Identifiable, Equatable, Codable {
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
    let timeZoneID: String

    var id: String { country.isEmpty ? name : "\(name), \(country)" }
    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    // MARK: - Selected-city persistence

    private static let selectedKey = "selectedCityData"

    static func loadSelected() -> City? {
        guard let data = UserDefaults.standard.data(forKey: selectedKey) else { return nil }
        return try? JSONDecoder().decode(City.self, from: data)
    }

    static func saveSelected(_ city: City?) {
        if let city, let data = try? JSONEncoder().encode(city) {
            UserDefaults.standard.set(data, forKey: selectedKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedKey)
        }
    }

    static let all: [City] = [
        City(name: "Mecca", country: "Saudi Arabia", latitude: 21.4225, longitude: 39.8262, timeZoneID: "Asia/Riyadh"),
        City(name: "Medina", country: "Saudi Arabia", latitude: 24.5247, longitude: 39.5692, timeZoneID: "Asia/Riyadh"),
        City(name: "Riyadh", country: "Saudi Arabia", latitude: 24.7136, longitude: 46.6753, timeZoneID: "Asia/Riyadh"),
        City(name: "Jeddah", country: "Saudi Arabia", latitude: 21.4858, longitude: 39.1925, timeZoneID: "Asia/Riyadh"),
        City(name: "Dubai", country: "UAE", latitude: 25.2048, longitude: 55.2708, timeZoneID: "Asia/Dubai"),
        City(name: "Abu Dhabi", country: "UAE", latitude: 24.4539, longitude: 54.3773, timeZoneID: "Asia/Dubai"),
        City(name: "Doha", country: "Qatar", latitude: 25.2854, longitude: 51.5310, timeZoneID: "Asia/Qatar"),
        City(name: "Kuwait City", country: "Kuwait", latitude: 29.3759, longitude: 47.9774, timeZoneID: "Asia/Kuwait"),
        City(name: "Amman", country: "Jordan", latitude: 31.9454, longitude: 35.9284, timeZoneID: "Asia/Amman"),
        City(name: "Baghdad", country: "Iraq", latitude: 33.3152, longitude: 44.3661, timeZoneID: "Asia/Baghdad"),
        City(name: "Tehran", country: "Iran", latitude: 35.6892, longitude: 51.3890, timeZoneID: "Asia/Tehran"),
        City(name: "Istanbul", country: "Türkiye", latitude: 41.0082, longitude: 28.9784, timeZoneID: "Europe/Istanbul"),
        City(name: "Ankara", country: "Türkiye", latitude: 39.9334, longitude: 32.8597, timeZoneID: "Europe/Istanbul"),
        City(name: "Cairo", country: "Egypt", latitude: 30.0444, longitude: 31.2357, timeZoneID: "Africa/Cairo"),
        City(name: "Casablanca", country: "Morocco", latitude: 33.5731, longitude: -7.5898, timeZoneID: "Africa/Casablanca"),
        City(name: "Lagos", country: "Nigeria", latitude: 6.5244, longitude: 3.3792, timeZoneID: "Africa/Lagos"),
        City(name: "Nairobi", country: "Kenya", latitude: -1.2921, longitude: 36.8219, timeZoneID: "Africa/Nairobi"),
        City(name: "Karachi", country: "Pakistan", latitude: 24.8607, longitude: 67.0011, timeZoneID: "Asia/Karachi"),
        City(name: "Lahore", country: "Pakistan", latitude: 31.5204, longitude: 74.3587, timeZoneID: "Asia/Karachi"),
        City(name: "Islamabad", country: "Pakistan", latitude: 33.6844, longitude: 73.0479, timeZoneID: "Asia/Karachi"),
        City(name: "Delhi", country: "India", latitude: 28.7041, longitude: 77.1025, timeZoneID: "Asia/Kolkata"),
        City(name: "Mumbai", country: "India", latitude: 19.0760, longitude: 72.8777, timeZoneID: "Asia/Kolkata"),
        City(name: "Dhaka", country: "Bangladesh", latitude: 23.8103, longitude: 90.4125, timeZoneID: "Asia/Dhaka"),
        City(name: "Tashkent", country: "Uzbekistan", latitude: 41.2995, longitude: 69.2401, timeZoneID: "Asia/Tashkent"),
        City(name: "Jakarta", country: "Indonesia", latitude: -6.2088, longitude: 106.8456, timeZoneID: "Asia/Jakarta"),
        City(name: "Kuala Lumpur", country: "Malaysia", latitude: 3.1390, longitude: 101.6869, timeZoneID: "Asia/Kuala_Lumpur"),
        City(name: "Singapore", country: "Singapore", latitude: 1.3521, longitude: 103.8198, timeZoneID: "Asia/Singapore"),
        City(name: "London", country: "United Kingdom", latitude: 51.5074, longitude: -0.1278, timeZoneID: "Europe/London"),
        City(name: "Birmingham", country: "United Kingdom", latitude: 52.4862, longitude: -1.8904, timeZoneID: "Europe/London"),
        City(name: "Paris", country: "France", latitude: 48.8566, longitude: 2.3522, timeZoneID: "Europe/Paris"),
        City(name: "Berlin", country: "Germany", latitude: 52.5200, longitude: 13.4050, timeZoneID: "Europe/Berlin"),
        City(name: "Amsterdam", country: "Netherlands", latitude: 52.3676, longitude: 4.9041, timeZoneID: "Europe/Amsterdam"),
        City(name: "New York", country: "USA", latitude: 40.7128, longitude: -74.0060, timeZoneID: "America/New_York"),
        City(name: "Washington DC", country: "USA", latitude: 38.9072, longitude: -77.0369, timeZoneID: "America/New_York"),
        City(name: "Chicago", country: "USA", latitude: 41.8781, longitude: -87.6298, timeZoneID: "America/Chicago"),
        City(name: "Houston", country: "USA", latitude: 29.7604, longitude: -95.3698, timeZoneID: "America/Chicago"),
        City(name: "Los Angeles", country: "USA", latitude: 34.0522, longitude: -118.2437, timeZoneID: "America/Los_Angeles"),
        City(name: "Toronto", country: "Canada", latitude: 43.6532, longitude: -79.3832, timeZoneID: "America/Toronto"),
        City(name: "Sydney", country: "Australia", latitude: -33.8688, longitude: 151.2093, timeZoneID: "Australia/Sydney"),
        City(name: "Melbourne", country: "Australia", latitude: -37.8136, longitude: 144.9631, timeZoneID: "Australia/Melbourne"),
    ]
}
