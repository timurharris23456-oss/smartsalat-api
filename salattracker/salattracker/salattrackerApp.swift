//
//  salattrackerApp.swift
//  salattracker
//
//  Created by Timur Harris on 7/3/26.
//

import SwiftUI

@main
struct salattrackerApp: App {
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
