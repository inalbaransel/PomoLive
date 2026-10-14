import SwiftUI

/// Every recorded session, grouped by day, loading older pages as the list scrolls.
struct HistoryView: View {
    @Environment(AppModel.self) private var app

    private var days: [(day: Date, entries: [HistoryEntry])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: app.stats.history) {
            calendar.startOfDay(for: Date(timeIntervalSince1970: Double($0.startedAt) / 1000))
        }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0]!) }
    }

    var body: some View {
        List {
            ForEach(days, id: \.day) { day in
                Section {
                    ForEach(day.entries) { entry in
                        HistoryRow(entry: entry)
                            .task {
                                if entry.id == app.stats.history.last?.id { await app.stats.loadMoreHistory() }
                            }
                    }
                } header: {
                    HStack {
                        Text(day.day, format: .dateTime.weekday(.wide).day().month(.wide))
                        Spacer()
                        Text(formattedFocus(day.entries.reduce(0) { $0 + $1.focusedMs }))
                            .monospacedDigit()
                    }
                }
            }
            if app.stats.hasMoreHistory {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Geçmiş")
        .navigationBarTitleDisplayMode(.inline)
    }
}
