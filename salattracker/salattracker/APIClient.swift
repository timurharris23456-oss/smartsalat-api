//
//  APIClient.swift
//  salattracker
//
//  Talks to the SmartSalat backend (accounts + record sync).
//

import Foundation

struct APIClient {
    /// The API base URL. Read from the `APIBaseURL` key in Info.plist so you can
    /// point the app at your deployed server without touching code. Falls back to
    /// localhost for simulator development.
    var baseURL: URL = {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
           !raw.isEmpty, let url = URL(string: raw) {
            return url
        }
        return URL(string: "https://smartsalat-api.onrender.com")!
    }()

    struct AuthResponse: Codable {
        let token: String
        let username: String
        let friendCode: String?
    }

    struct MeResponse: Codable {
        let username: String
        let friendCode: String
    }

    struct RemoteFriend: Codable {
        let username: String
        let streak: Int
        let completedToday: [String]
    }

    /// A day's record as the server represents it.
    struct RemoteDay: Codable {
        var fard: [String]
        var sunnah: [String]
        var witr: Bool
    }

    enum APIError: LocalizedError {
        case server(String)
        case unreachable

        var errorDescription: String? {
            switch self {
            case .server(let message): message
            case .unreachable: "Can't reach the server. Is it running?"
            }
        }
    }

    // MARK: - Auth

    /// The device's current offset from UTC, in minutes — so the server can
    /// compute the user's local "today" for streaks and friend progress.
    private var tzOffsetMinutes: Int { TimeZone.current.secondsFromGMT() / 60 }

    func register(username: String, password: String) async throws {
        _ = try await send("/register", method: "POST",
                           body: ["username": username, "password": password, "tzOffset": tzOffsetMinutes])
    }

    func login(username: String, password: String) async throws -> AuthResponse {
        let data = try await send("/login", method: "POST",
                                  body: ["username": username, "password": password, "tzOffset": tzOffsetMinutes])
        return try JSONDecoder().decode(AuthResponse.self, from: data)
    }

    func logout(token: String) async {
        _ = try? await send("/logout", method: "POST", body: nil, token: token)
    }

    /// Permanently delete the signed-in account and all its data on the server.
    func deleteAccount(token: String) async throws {
        _ = try await send("/account", method: "DELETE", body: nil, token: token)
    }

    // MARK: - Records

    func fetchRecords(token: String) async throws -> [String: RemoteDay] {
        let data = try await send("/records", method: "GET", body: nil, token: token)
        struct Wrapper: Codable { let records: [String: RemoteDay] }
        return try JSONDecoder().decode(Wrapper.self, from: data).records
    }

    func saveRecords(_ records: [String: RemoteDay], token: String) async throws {
        let payload = records.mapValues { ["fard": $0.fard, "sunnah": $0.sunnah, "witr": $0.witr] as [String: Any] }
        _ = try await send("/records", method: "PUT", body: ["records": payload], token: token)
    }

    // MARK: - Account & friends

    func me(token: String) async throws -> MeResponse {
        let data = try await send("/me", method: "GET", body: nil, token: token)
        return try JSONDecoder().decode(MeResponse.self, from: data)
    }

    func fetchFriends(token: String) async throws -> [RemoteFriend] {
        let data = try await send("/friends", method: "GET", body: nil, token: token)
        struct Wrapper: Codable { let friends: [RemoteFriend] }
        return try JSONDecoder().decode(Wrapper.self, from: data).friends
    }

    func addFriend(code: String, token: String) async throws {
        _ = try await send("/friends/add", method: "POST", body: ["code": code], token: token)
    }

    func fetchRequests(token: String) async throws -> [String] {
        let data = try await send("/friends/requests", method: "GET", body: nil, token: token)
        struct Wrapper: Codable { let requests: [String] }
        return try JSONDecoder().decode(Wrapper.self, from: data).requests
    }

    func acceptFriend(username: String, token: String) async throws {
        _ = try await send("/friends/accept", method: "POST", body: ["username": username], token: token)
    }

    func declineFriend(username: String, token: String) async throws {
        _ = try await send("/friends/decline", method: "POST", body: ["username": username], token: token)
    }

    // MARK: - Transport

    @discardableResult
    private func send(_ path: String, method: String, body: [String: Any]?, token: String? = nil) async throws -> Data {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.unreachable
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.unreachable }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw APIError.server(detail ?? "Request failed (\(http.statusCode))")
        }
        return data
    }
}
