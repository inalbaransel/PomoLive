import Charts
import SwiftUI

/// The İstatistik tab, in the spirit of Fitness and Screen Time: one headline number,
/// the week as a simple bar chart, categories as proportion bars, then recent sessions.
struct StatsView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        @Bindable var stats = app.stats

        NavigationStack {
            List {
                if let summary = app.stats.summary, !summary.isUnlocked {
                    Section {
                        StatsUnlockCard(summary: summary)
                    }
                    recentSessions
                } else if let summary = app.stats.summary {
                    Section {
                        StatsHeadline(summary: summary, dailyGoalMinutes: app.user?.dailyGoalMinutes, weeklyGoalMinutes: app.user?.weeklyGoalMinutes)
                    }

                    if let badges = summary.badges {
                        Section("Rozetler") { BadgeShelf(badges: badges) }
                    }

                    Section("Son 7 Gün") {
                        WeekChart(days: summary.last7Days)
                    }

                    if !summary.categories.isEmpty {
                        Section {
                            ForEach(summary.categories.prefix(6)) { category in
                                CategoryRow(category: category, share: CategoryRow.share(of: category, in: summary.categories))
                            }
                        } header: {
                            Text("Kategoriler")
                        } footer: {
                            Text("Son 30 gün")
                        }
                    }

                    recentSessions
                } else {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("İstatistik")
            .refreshable { await app.stats.refresh() }
            // Reload whenever the tab appears, the connection comes back or a session ends.
            .task(id: RefreshKey(connection: app.connection, deskId: app.seat.desk?.deskId)) {
                if app.connection == .online { await app.stats.refresh() }
            }
            .errorAlert($stats.error)
        }
    }

    @ViewBuilder
    private var recentSessions: some View {
        Section("Son Oturumlar") {
            if app.stats.history.isEmpty {
                ContentUnavailableView(
                    "Henüz oturum yok",
                    systemImage: "books.vertical",
                    description: Text("Bir odada masaya oturup en az bir dakika odaklandığında burada görünür.")
                )
            } else {
                ForEach(app.stats.history.prefix(5)) { entry in
                    HistoryRow(entry: entry)
                }
                NavigationLink("Tüm Geçmiş") { HistoryView() }
            }
        }
    }
}

private struct RefreshKey: Hashable {
    var connection: AppModel.Connection
    var deskId: String?
}

/// Activity-style concentric rings: daily goal outside, weekly inside. Overflow past 100% wraps.
struct GoalRings: View {
    let daily: Double?
    let weekly: Double?

    var body: some View {
        ZStack {
            if let daily { ring(daily, color: .accentColor, inset: 0) }
            if let weekly { ring(weekly, color: .green, inset: daily == nil ? 0 : 16) }
            if (daily ?? 0) >= 1 {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.8, bounce: 0.2), value: daily)
        .animation(.spring(duration: 0.8, bounce: 0.2), value: weekly)
        .accessibilityElement()
        .accessibilityLabel("Hedef ilerlemesi")
    }

    private func ring(_ progress: Double, color: Color, inset: CGFloat) -> some View {
        ZStack {
            Circle().stroke(color.opacity(0.18), lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(max(progress, 0.001), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(inset)
    }
}

/// "45 dk kaldı" or "Hedef tamam! 🎉" under today's number.
struct GoalCaption: View {
    let doneMs: Int64
    let goalMinutes: Int

    var body: some View {
        let remaining = Int64(goalMinutes) * 60_000 - doneMs
        if remaining <= 0 {
            Label("Günlük hedef tamam", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
        } else {
            Text("Hedefe \(formattedFocus(remaining)) kaldı")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// Shown until the reader has focused on enough separate days for charts to mean something.
struct StatsUnlockCard: View {
    let summary: StatsSummary

    private var required: Int { summary.requiredDays ?? 2 }
    private var done: Int { min(summary.activeDays ?? 0, required) }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: max(Double(done) / Double(required), 0.02))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(verbatim: "\(done)/\(required)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("gün")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 104, height: 104)
            .animation(.smooth, value: done)

            VStack(spacing: 6) {
                Text("İstatistiklerin hazırlanıyor")
                    .font(.headline)
                Text("Anlamlı grafikler için \(required) farklı günde odaklanman gerekiyor. Her gün en az bir oturum tamamla.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if summary.todayMs > 0 {
                Label("Bugün \(formattedFocus(summary.todayMs)) odaklandın", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

/// Today in large rounded numerals, with the week, streak and lifetime total beneath.
struct StatsHeadline: View {
    let summary: StatsSummary
    var dailyGoalMinutes: Int?
    var weeklyGoalMinutes: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bugün Odak")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(formattedFocus(summary.todayMs))
                        .font(.system(size: 44, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.accentColor)
                        .contentTransition(.numericText())
                    if let dailyGoalMinutes {
                        GoalCaption(doneMs: summary.todayMs, goalMinutes: dailyGoalMinutes)
                    }
                }
                Spacer(minLength: 0)
                if dailyGoalMinutes != nil || weeklyGoalMinutes != nil {
                    GoalRings(
                        daily: dailyGoalMinutes.map { Double(summary.todayMs) / Double($0 * 60_000) },
                        weekly: weeklyGoalMinutes.map { Double(summary.weekMs) / Double($0 * 60_000) }
                    )
                    .frame(width: 84, height: 84)
                }
            }
            HStack(alignment: .top) {
                column("Bu Hafta", value: formattedFocus(summary.weekMs),
                       detail: weeklyGoalMinutes.map { String(localized: "Hedef \(formattedFocus(Int64($0) * 60_000))") })
                Divider()
                column("Seri", value: String(localized: "\(summary.streakDays) gün"))
                Divider()
                column("Toplam", value: formattedFocus(summary.totalMs), detail: String(localized: "\(summary.sessionCount) seans"))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 6)
    }

    private func column(_ title: LocalizedStringKey, value: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Focus minutes per day with the week's daily average as a dashed rule.
struct WeekChart: View {
    let days: [DayTotal]

    private static let parser: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private var averageMinutes: Double {
        Double(days.reduce(0) { $0 + $1.totalMs }) / Double(max(days.count, 1)) / 60_000
    }

    var body: some View {
        if days.allSatisfy({ $0.totalMs == 0 }) {
            Text("Bu hafta henüz odak süren yok. İlk oturumun burada görünecek.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Günlük ortalama \(formattedFocus(Int64(averageMinutes * 60_000)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Chart {
                    ForEach(days) { day in
                        BarMark(
                            x: .value("Gün", Self.parser.date(from: day.date) ?? .now, unit: .day),
                            y: .value("Dakika", Double(day.totalMs) / 60_000)
                        )
                        .foregroundStyle(Color.accentColor.gradient)
                        .cornerRadius(5)
                    }
                    RuleMark(y: .value("Ortalama", averageMinutes))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.secondary)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine()
                        AxisValueLabel { if let minutes = value.as(Double.self) { Text("\(Int(minutes)) dk") } }
                    }
                }
                .frame(height: 180)
            }
            .padding(.vertical, 6)
        }
    }
}

/// Screen Time style: icon, name and duration over a bar scaled to the top category.
struct CategoryRow: View {
    let category: CategoryTotal
    let share: Double

    /// `category`'s length relative to the largest one in `all`.
    static func share(of category: CategoryTotal, in all: [CategoryTotal]) -> Double {
        let longest = all.map(\.ms).max() ?? 0
        return longest > 0 ? Double(category.ms) / Double(longest) : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            GlyphIcon(symbol: category.symbol, color: category.color, size: 34)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(category.displayName)
                    Spacer()
                    Text(formattedFocus(category.ms))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Capsule()
                    .fill(.fill.tertiary)
                    .frame(height: 6)
                    .frame(maxWidth: .infinity)
                    .background(alignment: .leading) {
                        GeometryReader { proxy in
                            Capsule()
                                .fill(category.color.color)
                                .frame(width: max(6, proxy.size.width * share))
                        }
                    }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        HStack(spacing: 12) {
            GlyphIcon(symbol: entry.category.symbol, color: entry.category.color, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.note ?? entry.category.displayName)
                    .lineLimit(1)
                Text("\(entry.roomDisplayName) · \(entry.mode.displayName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedFocus(entry.focusedMs))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                Text(Self.when(Date(timeIntervalSince1970: Double(entry.startedAt) / 1000)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "14:05" today, "Dün" yesterday, otherwise a short date, as in Messages and Mail.
    private static func when(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .app)) }
        if calendar.isDateInYesterday(date) { return String(localized: "Dün") }
        return date.formatted(.dateTime.day().month(.abbreviated).locale(.app))
    }
}
