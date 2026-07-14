//
//  LocationManager.swift
//  salattracker
//

import Foundation
import Combine
import CoreLocation

/// Wraps CLLocationManager: requests when-in-use permission and publishes
/// the device's coordinate as fixes arrive.
@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var coordinate: CLLocationCoordinate2D?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Device compass heading in degrees from true north (0–360), or nil if unavailable.
    @Published private(set) var heading: CLLocationDirection?

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    var headingAvailable: Bool { CLLocationManager.headingAvailable() }

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.headingFilter = 1
        authorizationStatus = manager.authorizationStatus
    }

    func startHeading() {
        guard CLLocationManager.headingAvailable() else { return }
        manager.startUpdatingHeading()
    }

    func stopHeading() {
        manager.stopUpdatingHeading()
    }

    /// Asks for when-in-use permission if needed, then requests a single fix.
    /// Once permission is granted, the fix is requested automatically from
    /// the authorization callback.
    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.coordinate = coordinate
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            self.heading = value
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the last published coordinate; callers fall back to saved values.
    }
}
