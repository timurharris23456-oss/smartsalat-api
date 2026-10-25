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
    @Published private(set) var avatarData: Data?
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
            avatarData = me.avatar.flatMap { Data(base64Encoded: $0) }
        }
    }

    /// The user's friends, as leaderboard entries.
    func friends() async throws -> [StreakEntry] {
        guard let token else { return [] }
        let remote = try await api.fetchFriends(token: token)
        FriendsCache.save(remote, for: username)
        return remote.map(Self.entry(from:))
    }

    /// The last-synced friends, loaded from the on-device cache so the list can
    /// appear instantly on launch while a fresh copy loads in the background.
    func cachedFriends() -> [StreakEntry] {
        guard let username else { return [] }
        return FriendsCache.load(for: username).map(Self.entry(from:))
    }

    private static func entry(from f: APIClient.RemoteFriend) -> StreakEntry {
        StreakEntry(
            id: f.username,
            name: f.username,
            streak: f.streak,
            completedToday: Set(f.completedToday.compactMap(Prayer.init(rawValue:))),
            avatar: f.avatar.flatMap { Data(base64Encoded: $0) }
        )
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

    func removeFriend(_ username: String) async throws {
        guard let token else { return }
        try await api.removeFriend(username: username, token: token)
    }

    func register(username: String, password: String, avatar: Data? = nil) async {
        await perform {
            try await api.register(username: username, password: password)
            let auth = try await api.login(username: username, password: password)
            finishSignIn(auth)
            // Upload the chosen profile picture, if any, now that we're signed in.
            if let avatar, let token {
                try await api.setAvatar(jpeg: avatar, token: token)
                avatarData = avatar
            }
        }
    }

    /// Set or replace the signed-in user's profile picture (a small JPEG).
    func setAvatar(_ jpeg: Data) async {
        guard let token else { return }
        await perform {
            try await api.setAvatar(jpeg: jpeg, token: token)
            avatarData = jpeg
        }
    }

    func removeAvatar() async {
        guard let token else { return }
        await perform {
            try await api.removeAvatar(token: token)
            avatarData = nil
        }
    }

    func signIn(username: String, password: String) async {
        await perform {
            let auth = try await api.login(username: username, password: password)
            finishSignIn(auth)
        }
        // Load the account's profile picture (not part of the login response).
        if isSignedIn { await refreshMe() }
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
            FriendsCache.clear(for: username)
            clearSession()
        }
    }

    private func clearSession() {
        token = nil
        username = nil
        avatarData = nil
        UserDefaults.standard.removeObject(forKey: Keys.token)
        UserDefaults.standard.removeObject(forKey: Keys.username)
        store.endSession()
    }

    private func finishSignIn(_ auth: APIClient.AuthResponse) {
        token = auth.token
        username = auth.username
        friendCode = auth.friendCode
        avatarData = nil   // cleared now; loaded fresh for this account via refreshMe
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

/// A small on-device cache of the last-synced friends, stored per user as JSON
/// in the caches directory so the leaderboard can render instantly on launch.
private enum FriendsCache {
    private static func fileURL(for user: String) -> URL? {
        let safe = user.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? user
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        return dir?.appendingPathComponent("friends_\(safe).json")
    }

    static func save(_ friends: [APIClient.RemoteFriend], for user: String?) {
        guard let user, let url = fileURL(for: user),
              let data = try? JSONEncoder().encode(friends) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load(for user: String) -> [APIClient.RemoteFriend] {
        guard let url = fileURL(for: user), let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([APIClient.RemoteFriend].self, from: data)
        else { return [] }
        return list
    }

    static func clear(for user: String?) {
        guard let user, let url = fileURL(for: user) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
