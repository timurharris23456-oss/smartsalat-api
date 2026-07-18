import SwiftUI
import MapKit
import CoreLocation

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("calcMethod") private var calcMethod = "northAmerica"
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .dynamic

    @State private var selectedCity = City.loadSelected()
    @State private var cityQuery = ""
    @State private var searchResults: [City] = []
    @State private var isSearching = false
    @State private var searchFailed = false
    @State private var showPrivacy = false
    @State private var showDeleteConfirm = false

    private let methods: [(key: String, label: String)] = [
        ("northAmerica", "ISNA (North America)"),
        ("muslimWorldLeague", "Muslim World League"),
        ("egyptian", "Egyptian General Authority"),
        ("karachi", "Univ. of Islamic Sciences, Karachi"),
        ("ummAlQura", "Umm al-Qura (Makkah)"),
        ("dubai", "Dubai"),
        ("kuwait", "Kuwait"),
        ("qatar", "Qatar"),
        ("singapore", "Singapore"),
        ("turkey", "Diyanet (Turkey)"),
        ("tehran", "Tehran")
    ]

    var body: some View {
        Form {
            Section {
                Button {
                    selectedCity = nil
                    City.saveSelected(nil)
                    searchResults = []
                } label: {
                    HStack {
                        Label("Use My Location (GPS)", systemImage: "location.fill")
                        Spacer()
                        if selectedCity == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .foregroundStyle(.primary)

                if let city = selectedCity {
                    HStack {
                        Label(city.id, systemImage: "building.2.fill")
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundStyle(.green)
                    }
                }

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Type a city, e.g. Springfield, Virginia", text: $cityQuery)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit(runSearch)
                    if isSearching {
                        ProgressView()
                    }
                }

                if searchFailed {
                    Text("No matches found — try adding the state or country.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                ForEach(searchResults) { result in
                    Button {
                        selectedCity = result
                        City.saveSelected(result)
                        searchResults = []
                        cityQuery = ""
                    } label: {
                        Label(result.id, systemImage: "mappin.circle")
                    }
                }
            } header: {
                Text("Location")
            } footer: {
                Text("Times follow your GPS location, or a city you set here. Type a city, press search, then tap a match.")
            }

            Section {
                Picker("Appearance", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Label(mode.label, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Appearance")
            } footer: {
                Text("Dynamic follows the sun for your location — light after sunrise, dark after sunset.")
            }

            Section {
                Picker("Calculation Method", selection: $calcMethod) {
                    ForEach(methods, id: \.key) { Text($0.label).tag($0.key) }
                }
            } header: {
                Text("Calculation")
            }

            Section {
                if let username = auth.username {
                    LabeledContent("Signed in as", value: username)
                }
                Button(role: .destructive) {
                    auth.signOut()
                } label: {
                    Text("Sign Out")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    if auth.isWorking {
                        ProgressView()
                    } else {
                        Text("Delete Account")
                    }
                }
                .disabled(auth.isWorking)
            } header: {
                Text("Account")
            } footer: {
                Text("Deleting your account permanently removes your prayer history, streaks, and friends. This can't be undone.")
            }

            Section {
                Button {
                    showPrivacy = true
                } label: {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.subtle)
                    }
                }
                .tint(Theme.text)
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPrivacy) {
            NavigationStack {
                PrivacyPolicyView()
                    .navigationTitle("Privacy Policy")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .confirmationDialog("Delete your account?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete Account", role: .destructive) {
                Task { await auth.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all your data on our servers. This can't be undone.")
        }
    }

    private func runSearch() {
        let query = cityQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        searchFailed = false
        Task {
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = query
            request.resultTypes = .address
            let response = try? await MKLocalSearch(request: request).start()
            var seen = Set<String>()
            searchResults = (response?.mapItems ?? [])
                .compactMap { cityResult(from: $0) }
                .filter { seen.insert($0.id).inserted }
            isSearching = false
            searchFailed = searchResults.isEmpty
        }
    }

    private func cityResult(from item: MKMapItem) -> City? {
        let coordinate = item.location.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let address = item.addressRepresentations
        return City(
            name: address?.cityWithContext ?? item.name ?? cityQuery,
            country: address?.regionName ?? "",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timeZoneID: item.timeZone?.identifier ?? TimeZone.current.identifier
        )
    }
}
