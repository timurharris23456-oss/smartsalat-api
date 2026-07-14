import SwiftUI
import CoreLocation

struct PrayerTimesView: View {
    @StateObject private var locationManager = LocationManager()
    @Environment(\.scenePhase) private var scenePhase

    private let service = PrayerTimeService()
    @State private var todaysPrayers: DailyPrayers?
    @State private var nextPrayer: (name: String, time: Date)?

    var body: some View {
        NavigationStack {
            List {
                if let next = nextPrayer {
                    Section("Next Prayer") {
                        VStack(alignment: .leading) {
                            Text(next.name).font(.title2).bold()
                            Text(next.time, style: .relative)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if let prayers = todaysPrayers {
                    Section("Today") {
                        ForEach(prayers.all, id: \.name) { prayer in
                            HStack {
                                Text(prayer.name)
                                Spacer()
                                Text(prayer.time, style: .time)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Text("Waiting for location…")
                }
            }
            .navigationTitle("Prayer Times")
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.coordinate?.latitude) { _, _ in
            refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            refresh()
        }
    }

    private func refresh() {
        guard let coord = locationManager.coordinate else { return }
        todaysPrayers = service.prayers(on: Date(), at: coord)
        nextPrayer = service.nextPrayer(at: coord)
        NotificationScheduler.shared.rescheduleUpcoming(service: service, coordinate: coord)
    }
}
