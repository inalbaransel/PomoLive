import Charts
import SwiftUI

/// PomoLive Plus statistics: the year as a heat map, the last six months by category, when the
/// reader focuses best, and their whole history as a CSV file.
struct PlusInsightsView: View {
    @Environment(AppModel.self) private var app
    @State private var insights: StatsInsights?
    @State private var csv: URL?
    @State private var isExporting = false
    @State private var error: LibraryError?

    var body: some View {
        List {
            if let insights {
                Section {
                    YearHeatmap(days: insights.days)
                        .listRowInsets(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 14))
                } header: {
                    Text("Son 1 Yıl")
                } footer: {
                    Text("\(insights.days.count) gün odaklandın.")
                }

                Section("Aylık Trend") {
                    MonthlyTrendChart(months: insights.months)
                        .frame(height: 220)
                        .padding(.vertical, 8)
                }

                Section("Seni Tanıyalım") {
                    if let hour = insights.bestHour {
                        LabeledContent {
                            Text(verbatim: String(format: "%02d:00–%02d:00", hour, (hour + 1) % 24))
                        } label: {
                            Label("En verimli saatin", systemImage: "clock.fill")
                        }
                    }
                    if let weekday = insights.bestWeekday {
                        LabeledContent {
                            Text(Self.weekdayName(weekday))
                        } label: {
                            Label("En verimli günün", systemImage: "calendar")
                        }
                    }
                    LabeledContent {
                        Text(formattedFocus(insights.averageSessionMs))
                    } label: {
                        Label("Ortalama oturum", systemImage: "timer")
                    }
                    LabeledContent {
                        Text(formattedFocus(insights.longestSessionMs))
                    } label: {
                        Label("En uzun oturum", systemImage: "trophy.fill")
                    }
                }

                Section {
                    if let csv {
                        ShareLink(item: csv) {
                            Label("CSV Dosyasını Paylaş", systemImage: "square.and.arrow.up")
                        }
                    } else {
                        Button {
                            Task { await export() }
                        } label: {
                            HStack {
                                Label("Tüm Geçmişi Dışa Aktar", systemImage: "tablecells")
                                Spacer()
                                if isExporting { ProgressView() }
                            }
                        }
                        .disabled(isExporting)
                    }
                } footer: {
                    Text("Numbers, Excel ya da Google E-Tablolar ile açabilirsin.")
                }
            } else if error == nil {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Gelişmiş İstatistik")
        .task { await load() }
        .refreshable { await load() }
        .errorAlert($error)
    }

    private func load() async {
        do {
            insights = try await app.socketSend(StatsInsightsCommand()).insights
        } catch {
            self.error = LibraryError(error)
        }
    }

    private func export() async {
        isExporting = true
        defer { isExporting = false }
        do {
            let sessions = try await app.socketSend(ExportStatsCommand()).sessions
            csv = try Self.writeCSV(sessions)
        } catch {
            self.error = LibraryError(error)
        }
    }

    private static func writeCSV(_ sessions: [ExportedSession]) throws -> URL {
        let iso = Date.ISO8601FormatStyle(timeZone: .current)
        func field(_ text: String) -> String { "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\"" }
        var lines = ["start,end,focused_minutes,category,room,mode,note"]
        for session in sessions {
            lines.append([
                Date(timeIntervalSince1970: Double(session.startedAt) / 1000).formatted(iso),
                Date(timeIntervalSince1970: Double(session.endedAt) / 1000).formatted(iso),
                String(session.focusedMs / 60_000),
                field(session.category),
                field(session.roomName),
                session.mode,
                field(session.note ?? ""),
            ].joined(separator: ","))
        }
        let url = FileManager.default.temporaryDirectory.appending(path: "PomoLive.csv")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func weekdayName(_ weekday: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .app
        // 1 = Monday from the server; Calendar's symbols start on Sunday.
        return calendar.standaloneWeekdaySymbols[weekday % 7]
    }
}

/// A GitHub-style year: one square per day in weekly columns, darker for more focus.
private struct YearHeatmap: View {
    let days: [StatsInsights.Day]

    private static let weeks = 53

    var body: some View {
        let byDate = Dictionary(days.map { ($0.date, $0.ms) }, uniquingKeysWith: +)
        let longest = max(byDate.values.max() ?? 1, 1)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        // Columns end with the current week; rows run Monday to Sunday.
        let weekdayIndex = (calendar.component(.weekday, from: today) + 5) % 7
        let start = calendar.date(byAdding: .day, value: -(Self.weeks - 1) * 7 - weekdayIndex, to: today)!

        Canvas { context, size in
            let gap: CGFloat = 2
            let cell = min((size.width - gap * CGFloat(Self.weeks - 1)) / CGFloat(Self.weeks), (size.height - gap * 6) / 7)
            for week in 0..<Self.weeks {
                for weekday in 0..<7 {
                    guard let date = calendar.date(byAdding: .day, value: week * 7 + weekday, to: start), date <= today else { continue }
                    let ms = byDate[Self.key(date)] ?? 0
                    let rect = CGRect(x: CGFloat(week) * (cell + gap), y: CGFloat(weekday) * (cell + gap), width: cell, height: cell)
                    let level = ms == 0 ? 0 : 0.25 + 0.75 * Double(ms) / Double(longest)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: cell * 0.25),
                        with: .color(ms == 0 ? Color.secondary.opacity(0.15) : Color.accentColor.opacity(level))
                    )
                }
            }
        }
        .aspectRatio(CGFloat(Self.weeks) / 7 * 0.98, contentMode: .fit)
        .accessibilityLabel("Son bir yılın odak haritası")
    }

    private static func key(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }
}

/// Six months of focus, stacked by category.
private struct MonthlyTrendChart: View {
    let months: [StatsInsights.Month]

    var body: some View {
        Chart {
            ForEach(months) { month in
                ForEach(month.categories) { category in
                    BarMark(
                        x: .value("Ay", Self.label(month.month)),
                        y: .value("Saat", Double(category.ms) / 3_600_000)
                    )
                    .foregroundStyle(category.color.color.gradient)
                    .cornerRadius(4)
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel { if let hours = value.as(Double.self) { Text("\(Int(hours)) sa") } }
            }
        }
    }

    private static func label(_ month: String) -> String {
        guard let date = try? Date("\(month)-01", strategy: .iso8601.year().month().day()) else { return month }
        return date.formatted(.dateTime.month(.abbreviated).locale(.app))
    }
}

/// What Plus statistics look like, for readers without Plus.
struct PlusInsightsTeaser: View {
    let onUnlock: () -> Void

    var body: some View {
        Button(action: onUnlock) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Gelişmiş İstatistik", systemImage: "chart.bar.xaxis")
                        .font(.headline)
                    Spacer()
                    PlusBadge()
                }
                Text("Yıllık ısı haritası, aylık trendler, en verimli saatin ve tüm geçmişini CSV olarak dışa aktarma.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                    ForEach(0..<4, id: \.self) { row in
                        GridRow {
                            ForEach(0..<20, id: \.self) { column in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor.opacity([0.12, 0.3, 0.6, 0.9][(row * 7 + column * 3) % 4]))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
                .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
