//
//  SalatStreaksView.swift
//  salattracker
//

import SwiftUI

struct SalatStreaksView: View {
    @ObservedObject var store: PrayerStore
    @EnvironmentObject private var auth: AuthManager

    @State private var friends: [StreakEntry] = []
    @State private var requests: [String] = []
    @State private var showAddFriend = false
    @State private var loadState: LoadState = .loading

    private enum LoadState { case loading, loaded, failed }

    private var youEntry: StreakEntry {
        let today = store.record(for: Date())
        return StreakEntry(id: "you", name: "You", streak: store.streak,
                           completedToday: today.fard, isYou: true,
                           avatar: auth.avatarData)
    }

    /// You + friends, ranked by streak.
    private var ranked: [StreakEntry] {
        ([youEntry] + friends).sorted { $0.streak > $1.streak }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header

                if friends.isEmpty {
                    switch loadState {
                    case .loading: loadingView
                    case .failed:  failedView
                    case .loaded:  emptyState
                    }
                }

                ForEach(Array(ranked.enumerated()), id: \.element.id) { index, entry in
                    StreakRow(rank: index + 1, entry: entry)
                }
            }
            .padding()
            .padding(.bottom, 12)
        }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showAddFriend) {
            AddFriendSheet(onChanged: { Task { await load() } })
        }
    }

    /// Load friends (and requests), retrying a few times so a cold server start
    /// doesn't leave the list looking empty. The spinner only shows when there's
    /// nothing on screen yet, so pull-to-refresh stays quiet.
    private func load() async {
        // Show the last-synced friends from the cache instantly, then refresh.
        if friends.isEmpty {
            let cached = auth.cachedFriends()
            if cached.isEmpty {
                loadState = .loading
            } else {
                friends = cached
                loadState = .loaded
            }
        }
        for attempt in 0..<4 {
            if Task.isCancelled { return }
            do {
                let loaded = try await auth.friends()
                friends = loaded
                requests = (try? await auth.friendRequests()) ?? []
                loadState = .loaded
                return
            } catch {
                if attempt == 3 {
                    // Keep showing cached friends if we have them; only surface an
                    // error when there's nothing on screen.
                    if friends.isEmpty { loadState = .failed }
                    return
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Loading your friends…")
                .font(.subheadline)
                .foregroundStyle(Theme.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private var failedView: some View {
        VStack(spacing: 10) {
            Text("Couldn't load your friends.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.subtle)
            Button {
                Task { await load() }
            } label: {
                Text("Try Again")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Streak with your friends")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primary)
                Text("SalatStreaks")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Theme.text)
            }
            Spacer()
            addFriendButton
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var addFriendButton: some View {
        Button {
            showAddFriend = true
        } label: {
            Image(systemName: "person.badge.plus.fill")
                .font(.title3)
                .foregroundStyle(Theme.primary)
                .frame(width: 42, height: 42)
                .background(Theme.surface, in: Circle())
                .shadow(color: Theme.shadow.opacity(0.15), radius: 6, y: 3)
                .overlay(alignment: .bottomLeading) {
                    if !requests.isEmpty {
                        Text("\(requests.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Capsule().fill(.red))
                            .offset(x: -4, y: 4)
                    }
                }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Image(systemName: "arrow.up")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Theme.primary)
                    .padding(.trailing, 22)
            }
            Text("No friends are currently added, add friends here")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.subtle)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .padding(.top, 2)
        .padding(.bottom, 8)
    }
}

private struct StreakRow: View {
    let rank: Int
    let entry: StreakEntry

    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.subtle)
                .frame(width: 18)

            AvatarView(initials: entry.initials, imageData: entry.avatar, filled: entry.isYou)

            VStack(alignment: .leading, spacing: 5) {
                Text(entry.name)
                    .font(.headline)
                    .foregroundStyle(Theme.text)
                HStack(spacing: 6) {
                    ForEach(Prayer.allCases) { prayer in
                        Circle()
                            .fill(entry.completedToday.contains(prayer) ? Theme.accent : Theme.subtle.opacity(0.25))
                            .frame(width: 8, height: 8)
                    }
                    Text("\(entry.completedCount)/5 today")
                        .font(.caption2)
                        .foregroundStyle(Theme.subtle)
                        .padding(.leading, 2)
                }
            }

            Spacer()

            HStack(spacing: 3) {
                Text("🔥")
                Text("\(entry.streak)")
                    .font(.title3.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Theme.text)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(entry.isYou ? Theme.primary.opacity(0.10) : Theme.surface)
                .shadow(color: Theme.shadow.opacity(0.12), radius: 10, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(entry.isYou ? Theme.primary.opacity(0.55) : .clear, lineWidth: 1.5)
        )
    }
}

private struct AddFriendSheet: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    let onChanged: () -> Void

    @State private var requests: [String] = []
    @State private var friends: [StreakEntry] = []
    @State private var friendToRemove: String?
    @State private var code = ""
    @State private var infoMessage: String?
    @State private var errorMessage: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    if !requests.isEmpty {
                        requestsSection
                    }
                    yourCodeSection
                    addByCodeSection
                    if !friends.isEmpty {
                        yourFriendsSection
                    }
                    Spacer()
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
            .confirmationDialog(
                "Remove this friend?",
                isPresented: Binding(get: { friendToRemove != nil },
                                     set: { if !$0 { friendToRemove = nil } }),
                titleVisibility: .visible,
                presenting: friendToRemove
            ) { friend in
                Button("Remove \(friend)", role: .destructive) { removeFriend(friend) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("You'll both be removed from each other's friends list. You can add them again later with their code.")
            }
        }
    }

    // MARK: - Requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FRIEND REQUESTS")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.subtle)

            ForEach(requests, id: \.self) { requester in
                HStack(spacing: 12) {
                    AvatarView(initials: initials(requester))
                    Text(requester)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Button {
                        respond(requester, accept: false)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.subtle)
                            .frame(width: 36, height: 36)
                            .background(Theme.subtle.opacity(0.12), in: Circle())
                    }
                    Button {
                        respond(requester, accept: true)
                    } label: {
                        Text("Accept")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                            .background(Theme.accent, in: Capsule())
                    }
                }
                .padding(12)
                .softCard(cornerRadius: 18)
            }
        }
    }

    // MARK: - Your code

    private var yourCodeSection: some View {
        VStack(spacing: 8) {
            Text("YOUR FRIEND CODE")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.subtle)
            Text(auth.friendCode ?? "––––––")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.primary)
            Text("Share this code so friends can add you")
                .font(.footnote)
                .foregroundStyle(Theme.subtle)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .softCard()
    }

    // MARK: - Add by code

    private var addByCodeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a friend by their code")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.text)

            HStack {
                Image(systemName: "number")
                    .foregroundStyle(Theme.subtle)
                TextField("6-digit code", text: $code)
                    .keyboardType(.numberPad)
                    .onChange(of: code) { _, new in
                        code = String(new.filter(\.isNumber).prefix(6))
                    }
            }
            .padding()
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
            if let infoMessage {
                Text(infoMessage).font(.footnote).foregroundStyle(Theme.accent)
            }

            Button(action: sendRequest) {
                HStack(spacing: 8) {
                    if isWorking { ProgressView().tint(.white) }
                    Text("Send Request").font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(code.count == 6 ? AnyShapeStyle(Theme.primary) : AnyShapeStyle(Theme.subtle),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(code.count != 6 || isWorking)
        }
    }

    // MARK: - Your friends

    private var yourFriendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR FRIENDS")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.subtle)

            ForEach(friends) { friend in
                HStack(spacing: 12) {
                    AvatarView(initials: initials(friend.name), imageData: friend.avatar)
                    Text(friend.name)
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Button(role: .destructive) {
                        friendToRemove = friend.id
                    } label: {
                        Image(systemName: "person.badge.minus")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.red)
                            .frame(width: 36, height: 36)
                            .background(Color.red.opacity(0.12), in: Circle())
                    }
                    .accessibilityLabel("Remove \(friend.name)")
                }
                .padding(12)
                .softCard(cornerRadius: 18)
            }
        }
    }

    // MARK: - Actions

    private func load() async {
        requests = (try? await auth.friendRequests()) ?? []
        friends = (try? await auth.friends()) ?? []
    }

    private func removeFriend(_ username: String) {
        Task {
            do {
                try await auth.removeFriend(username)
                friends.removeAll { $0.id == username }
                onChanged()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func sendRequest() {
        Task {
            isWorking = true
            errorMessage = nil
            infoMessage = nil
            do {
                try await auth.addFriend(code: code)
                infoMessage = "Request sent — they'll need to accept it."
                code = ""
            } catch {
                errorMessage = error.localizedDescription
            }
            isWorking = false
        }
    }

    private func respond(_ username: String, accept: Bool) {
        Task {
            do {
                if accept {
                    try await auth.acceptFriend(username)
                } else {
                    try await auth.declineFriend(username)
                }
                requests.removeAll { $0 == username }
                onChanged()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func initials(_ name: String) -> String {
        let letters = name.split(separator: " ").prefix(2).compactMap(\.first)
        return String(letters).uppercased()
    }
}
