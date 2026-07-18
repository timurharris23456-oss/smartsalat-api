//
//  PrivacyPolicy.swift
//  salattracker
//
//  The in-app privacy policy content. Keep the hosted copy (served at
//  /privacy by the backend, which App Store Connect requires as a public URL)
//  in sync with any edits here.
//

import Foundation

enum PrivacyPolicy {
    /// Bump this when the policy materially changes to force users to re-accept.
    static let currentVersion = 1
    static let effectiveDate = "July 11, 2026"

    static let sections: [(title: String, body: String)] = [
        ("Overview",
         """
         SmartSalat ("the App", "we", "us") helps you track your daily prayers, \
         view prayer times, find the Qibla direction, and share prayer streaks \
         with friends. This Privacy Policy explains what information the App \
         collects, how it is used, and the choices you have. By creating an \
         account or using the App, you agree to this policy. The App is operated \
         by Roya Qaemi.
         """),

        ("Information You Provide",
         """
         • Account details: a username and password you choose when you create an \
         account. Your password is stored only as a secure cryptographic hash \
         (bcrypt) — we never store or see your actual password.
         • Prayer activity: the prayers you mark as completed (Fard, Sunnah, and \
         Witr) and the streaks calculated from them.
         • Friends: a friend code generated for your account, and the friend \
         connections and friend requests you create.
         """),

        ("Information Collected Automatically",
         """
         • Location: with your permission, the App uses your device's location to \
         calculate accurate prayer times and the Qibla direction. Your location is \
         used on your device and stored only on your device — it is NOT sent to or \
         stored on our servers. You may instead choose a city manually, or decline \
         location access (times will then be approximate).
         • Notifications: if you allow them, prayer-time reminders are scheduled \
         locally on your device. No data is sent to us to deliver them.
         • Session token: when you sign in, a session token is stored on your \
         device so you stay signed in.
         """),

        ("How We Use Your Information",
         """
         We use your information only to provide the App's features: to track your \
         prayers and streaks, sync your data across your devices through your \
         account, calculate prayer times and Qibla direction, send the prayer-time \
         notifications you enable, and let your friends see your streak. We do not \
         use your information for advertising.
         """),

        ("How Your Information Is Shared",
         """
         • With friends: people you connect with can see your username, your \
         current streak, and which prayers you have completed today.
         • Service providers: your account and prayer data are stored using \
         MongoDB Atlas (database) and our server is hosted on Render. These \
         providers process data solely on our behalf to operate the App.
         • We do NOT sell your data, and the App contains no third-party \
         advertising or analytics trackers.
         • We may disclose information if required by law.
         """),

        ("Data Storage & Security",
         """
         Your account and prayer data are stored on our backend; other data (such \
         as your saved location and session token) is stored locally on your \
         device. Passwords are hashed with bcrypt, and data is transmitted over \
         encrypted HTTPS connections. No method of storage or transmission is \
         100% secure, but we take reasonable measures to protect your information.
         """),

        ("Your Choices & Data Deletion",
         """
         • You can turn location and notification permissions on or off at any \
         time in iOS Settings.
         • You can permanently delete your account and all associated data at any \
         time from within the App: open Settings and tap "Delete Account". This \
         immediately removes your account, prayer records, friend connections, and \
         session from our servers.
         • You may also request deletion by contacting us at \
         timurharris23456@gmail.com.
         """),

        ("Children's Privacy",
         """
         The App is not directed to children under 13, and we do not knowingly \
         collect personal information from children under 13. If you believe a \
         child has provided us information, please contact us and we will delete it.
         """),

        ("Changes to This Policy",
         """
         We may update this Privacy Policy from time to time. Changes take effect \
         when posted in the App, and material changes will require you to accept \
         the updated policy before continuing to use the App.
         """),

        ("Contact",
         """
         If you have any questions about this Privacy Policy or your data, contact \
         us at timurharris23456@gmail.com.
         """),
    ]
}
