import Charts
import SwiftUI

/// The İstatistik tab: headline numbers, the last 7 days by category, the category mix and recent sessions.
struct StatsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var stats = app.stats

        NavigationStack {
            ScrollView {
                if let summary = app.stats.summary {
                    VStack(spacing: 16) {
                        metrics(summary)
                        WeekChart(days: summary.last7Days)
                        if !summary.categories.isEmpty {
                            CategoryBreakdown(categories: summary.categories)
                        }
                        recentSessions
                    }
                    .padding(16)
                } else {
                    ProgressView()
                        .padding(.top, 120)
                }
            }
            .navigationTitle("İstatistik")
            .refreshable { await app.stats.refresh() }
            .task(id: app.connection) {
                if app.connection == .online { await app.stats.refresh() }
            }
            .errorAlert($stats.error)
        }
    }

    private func metrics(_ summary: StatsSummary) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricCard(title: "Bugün", value: formattedFocus(summary.todayMs), symbol: "sun.max.fill")
            MetricCard(title: "Bu Hafta", value: formattedFocus(summary.weekMs), symbol: "calendar")
            MetricCard(title: "Seri", value: "\(summary.streakDays) gün", symbol: "flame.fill")
            MetricCard(title: "Toplam · \(summary.sessionCount) seans", value: formattedFocus(summary.totalMs), symbol: "hourglass")
        }
    }

    @ViewBuilder
    private var recentSessions: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Son Oturumlar")
                    .font(.title3.weight(.bold))
                Spacer()
                if !app.stats.history.isEmpty {
                    NavigationLink("Tümü") { HistoryView() }
                        .font(.subheadline.weight(.semibold))
                }
            }
            if app.stats.history.isEmpty {
                ContentUnavailableView(
                    "Henüz oturum yok",
                    systemImage: "books.vertical",
                    description: Text("Bir odada masaya oturup en az bir dakika odaklandığında burada görünür.")
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(app.stats.history.prefix(5)) { entry in
                        HistoryRow(entry: entry)
                            .padding(.vertical, 10)
                        if entry.id != app.stats.history.prefix(5).last?.id { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title2, design: .monospaced, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

/// Minutes per day, stacked by category.
private struct WeekChart: View {
    let days: [DayTotal]

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Son 7 Gün")
                .font(.title3.weight(.bold))
            if days.allSatisfy({ $0.totalMs == 0 }) {
                Text("Bu hafta henüz odak süren yok. İlk oturumun burada çubuk olarak belirecek.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            } else {
                chart
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    private var chart: some View {
        Chart {
            ForEach(days) { day in
                let date = Self.parser.date(from: day.date) ?? .now
                if day.byCategory.isEmpty {
                    BarMark(x: .value("Gün", date, unit: .day), y: .value("Dakika", 0))
                }
                ForEach(day.byCategory) { category in
                    BarMark(
                        x: .value("Gün", date, unit: .day),
                        y: .value("Dakika", Double(category.ms) / 60_000)
                    )
                    .foregroundStyle(by: .value("Kategori", "\(category.emoji) \(category.name)"))
                    .cornerRadius(4)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
            }
        }
        .chartYAxisLabel("dk")
        .chartLegend(position: .bottom, alignment: .leading)
        .frame(height: 220)
    }
}

/// Last 30 days by category, as a donut and a ranked list.
private struct CategoryBreakdown: View {
    let categories: [CategoryTotal]

    private var total: Int64 { categories.reduce(0) { $0 + $1.ms } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kategoriler · 30 Gün")
                .font(.title3.weight(.bold))
            HStack(spacing: 16) {
                Chart(categories) { category in
                    SectorMark(angle: .value("Süre", category.ms), innerRadius: .ratio(0.62), angularInset: 1.5)
                        .foregroundStyle(by: .value("Kategori", "\(category.emoji) \(category.name)"))
                        .cornerRadius(3)
                }
                .chartLegend(.hidden)
                .frame(width: 120, height: 120)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(categories.prefix(5)) { category in
                        HStack {
                            Text("\(category.emoji) \(category.name)")
                                .lineLimit(1)
                            Spacer()
                            Text(formattedFocus(category.ms))
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            Text(entry.category.emoji)
                .font(.title3)
                .frame(width: 40, height: 40)
                .glassEffect(.regular, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.note ?? entry.category.name)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(entry.roomName) · \(entry.mode == .pomodoro ? "Pomodoro" : "Kronometre")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedFocus(entry.focusedMs))
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                Text(Date(timeIntervalSince1970: Double(entry.startedAt) / 1000), format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
