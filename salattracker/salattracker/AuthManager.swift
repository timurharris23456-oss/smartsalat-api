//
//  AuthManager.swift
//  salattracker
//
//  Owns the signed-in session and drives the PrayerStore's account sync.
//

import Foundation
import Combine

@MainActor
final class AuthManager: ObservableObject {
    @Published private(set) var username: String?
    @Published private(set) var friendCode: String?
    @Published var errorMessage: String?
    @Published var isWorking = false

    var isSignedIn: Bool { token != nil }

    private var token: String?
    private let api = APIClient()
    private let store: PrayerStore

    private enum Keys {
        static let token = "authToken"
        static let username = "authUsername"
    }

    init(store: PrayerStore) {
        self.store = store
        token = UserDefaults.standard.string(forKey: Keys.token)
        username = UserDefaults.standard.string(forKey: Keys.username)
        if let token, let username {
            store.startSession(username: username, token: token)
            Task { await refreshMe() }
        }
    }

    // MARK: - Friends

    /// Refresh the signed-in user's own friend code from the server.
    func refreshMe() async {
        guard let token else { return }
        if let me = try? await api.me(token: token) {
            friendCode = me.friendCode
        }
    }

    /// The user's friends, as leaderboard entries.
    func friends() async throws -> [StreakEntry] {
        guard let token else { return [] }
        return try await api.fetchFriends(token: token).map {
            StreakEntry(
                id: $0.username,
                name: $0.username,
                streak: $0.streak,
                completedToday: Set($0.completedToday.compactMap(Prayer.init(rawValue:)))
            )
        }
    }

    func addFriend(code: String) async throws {
        guard let token else { return }
        try await api.addFriend(code: code, token: token)
    }

    /// Usernames of people who have requested to be your friend.
    func friendRequests() async throws -> [String] {
        guard let token else { return [] }
        return try await api.fetchRequests(token: token)
    }

    func acceptFriend(_ username: String) async throws {
        guard let token else { return }
        try await api.acceptFriend(username: username, token: token)
    }

    func declineFriend(_ username: String) async throws {
        guard let token else { return }
        try await api.declineFriend(username: username, token: token)
    }

    func register(username: String, password: String) async {
        await perform {
            try await api.register(username: username, password: password)
            let auth = try await api.login(username: username, password: password)
            finishSignIn(auth)
        }
    }

    func signIn(username: String, password: String) async {
        await perform {
            let auth = try await api.login(username: username, password: password)
            finishSignIn(auth)
        }
    }

    func signOut() {
        if let token {
            Task { await api.logout(token: token) }
        }
        clearSession()
    }

    /// Permanently delete the account and all its data on the server, then
    /// return to the signed-out state. Leaves the session intact on failure.
    func deleteAccount() async {
        guard let token else { return }
        await perform {
            try await api.deleteAccount(token: token)
            clearSession()
        }
    }

    private func clearSession() {
        token = nil
        username = nil
        UserDefaults.standard.removeObject(forKey: Keys.token)
        UserDefaults.standard.removeObject(forKey: Keys.username)
        store.endSession()
    }

    private func finishSignIn(_ auth: APIClient.AuthResponse) {
        token = auth.token
        username = auth.username
        friendCode = auth.friendCode
        UserDefaults.standard.set(auth.token, forKey: Keys.token)
        UserDefaults.standard.set(auth.username, forKey: Keys.username)
        store.startSession(username: auth.username, token: auth.token)
    }

    private func perform(_ action: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        do {
            try await action()
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
