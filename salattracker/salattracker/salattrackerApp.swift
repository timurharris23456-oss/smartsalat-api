//
//  salattrackerApp.swift
//  salattracker
//
//  Created by Timur Harris on 7/3/26.
//

import SwiftUI
import UIKit

/// Holds the latest APNs device token and hands it to whoever is listening
/// (AuthManager), bridging the UIKit app-delegate callback into the app.
@MainActor
final class PushRegistrar {
    static let shared = PushRegistrar()
    private(set) var token: String?
    var onToken: ((String) -> Void)?

    func deliver(_ token: String) {
        self.token = token
        onToken?(token)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in PushRegistrar.shared.deliver(hex) }
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Push isn't available yet (e.g. the capability isn't enabled) — ignore.
    }
}

@main
struct salattrackerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: PrayerStore
    @StateObject private var auth: AuthManager

    init() {
        let store = PrayerStore()
        _store = StateObject(wrappedValue: store)
        _auth = StateObject(wrappedValue: AuthManager(store: store))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(auth)
        }
    }
}

/// Gates the app behind privacy-policy acceptance, then login.
struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("acceptedPrivacyVersion") private var acceptedPrivacyVersion = 0

    var body: some View {
        if acceptedPrivacyVersion < PrivacyPolicy.currentVersion {
            PrivacyPolicyView {
                withAnimation { acceptedPrivacyVersion = PrivacyPolicy.currentVersion }
            }
        } else if auth.isSignedIn {
            ContentView()
        } else {
            LoginView()
        }
    }
}
