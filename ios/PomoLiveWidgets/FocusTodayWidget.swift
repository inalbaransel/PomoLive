import SwiftUI
import WidgetKit

/// Today's focus on the home and lock screens: the goal ring, streak and, while seated, a live
/// timer with a tap back to the desk.
struct FocusTodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FocusToday", provider: Provider()) { entry in
            FocusTodayView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.12, green: 0.11, blue: 0.24), Color(red: 0.06, green: 0.06, blue: 0.12)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .widgetURL(URL(string: "pomolive://desk"))
        }
        .configurationDisplayName("Bugünkü Odak")
        .description("Günlük hedefin, serin ve masadaysan canlı sayaç.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct FocusEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

private struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> FocusEntry {
        FocusEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusEntry) -> Void) {
        completion(FocusEntry(date: .now, snapshot: context.isPreview ? .placeholder : (WidgetSnapshot.load() ?? .placeholder)))
    }

    /// One entry now; the next reload comes at the pomodoro phase change, at midnight (so today
    /// resets) or within the hour, whichever is first. The app also reloads on every change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusEntry>) -> Void) {
        let snapshot = WidgetSnapshot.load() ?? WidgetSnapshot(
            todayMs: 0, weekMs: 0, streakDays: 0, dailyGoalMinutes: nil, desk: nil,
            day: Calendar.current.startOfDay(for: .now), updatedAt: .now
        )
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        let candidates = [snapshot.desk?.phaseEndsAt, midnight, Date.now.addingTimeInterval(3600)].compactMap { $0 }
        let next = candidates.filter { $0 > .now }.min() ?? midnight
        completion(Timeline(entries: [FocusEntry(date: .now, snapshot: snapshot)], policy: .after(next)))
    }
}

private let accent = Color(red: 0.55, green: 0.55, blue: 1)

struct FocusTodayView: View {
    let entry: FocusEntry
    @Environment(\.widgetFamily) private var family

    private var snapshot: WidgetSnapshot { entry.snapshot }
    private var today: Int64 { snapshot.todayMs(at: entry.date) }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: Home screen

    private var small: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                GoalRing(progress: snapshot.goalProgress, lineWidth: 7)
                    .frame(width: 46, height: 46)
                Spacer()
                StreakBadge(days: snapshot.streakDays)
            }
            Spacer(minLength: 0)
            if let desk = snapshot.desk {
                DeskLine(desk: desk, compact: true)
            } else {
                Text("Bugün")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Text(formatted(today))
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            if let goal = snapshot.dailyGoalMinutes {
                Text("Hedef \(formatted(Int64(goal) * 60_000))")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 18) {
            ZStack {
                GoalRing(progress: snapshot.goalProgress, lineWidth: 11)
                VStack(spacing: 0) {
                    Text(formatted(today))
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("bugün")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
                .padding(14)
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 10) {
                if let desk = snapshot.desk {
                    DeskLine(desk: desk, compact: false)
                } else {
                    Label("Masada değilsin", systemImage: "chair.lounge")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                HStack(spacing: 16) {
                    Metric(title: "Bu hafta", value: formatted(snapshot.weekMs))
                    Metric(title: "Seri", value: String(localized: "\(snapshot.streakDays) gün"))
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Lock screen

    private var circular: some View {
        Gauge(value: snapshot.goalProgress ?? 0) {
            Image(systemName: "brain.head.profile.fill")
        } currentValueLabel: {
            Text(shortMinutes(today))
                .font(.system(.body, design: .rounded, weight: .semibold))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            if let desk = snapshot.desk {
                Label(desk.categoryName, systemImage: desk.categorySymbol)
                    .font(.headline)
                    .widgetAccentable()
                DeskTimerText(desk: desk)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
            } else {
                Label("Bugün", systemImage: "brain.head.profile.fill")
                    .font(.headline)
                    .widgetAccentable()
                Text(formatted(today))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
            }
            Text("\(snapshot.streakDays) gün seri")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        if let desk = snapshot.desk {
            Label(desk.isResting ? String(localized: "Molada") : desk.categoryName, systemImage: desk.categorySymbol)
        } else {
            Label("Bugün \(formatted(today)) · \(snapshot.streakDays) gün seri", systemImage: "brain.head.profile.fill")
        }
    }

    // MARK: Formatting

    private func formatted(_ ms: Int64) -> String {
        Duration.seconds(ms / 60_000 * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(.app))
    }

    /// "95" minutes, or "2s" hours, for the tight circular gauge.
    private func shortMinutes(_ ms: Int64) -> String {
        let minutes = ms / 60_000
        return minutes < 100 ? "\(minutes)" : String(localized: "\(minutes / 60) sa")
    }
}

private struct GoalRing: View {
    let progress: Double?
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress ?? 0, 0.001))
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if (progress ?? 0) >= 1 {
                Image(systemName: "checkmark")
                    .font(.system(size: lineWidth * 1.6, weight: .bold))
                    .foregroundStyle(accent)
            }
        }
    }
}

private struct StreakBadge: View {
    let days: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
            Text(verbatim: "\(days)")
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(days > 0 ? .orange : .white.opacity(0.4))
    }
}

private struct DeskLine: View {
    let desk: WidgetSnapshot.Desk
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(desk.isResting ? String(localized: "Molada") : desk.categoryName,
                  systemImage: desk.isResting ? "cup.and.saucer.fill" : desk.categorySymbol)
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .foregroundStyle(desk.isResting ? .mint : .green)
                .lineLimit(1)
            if !compact {
                DeskTimerText(desk: desk)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

/// A live clock the system updates without waking the widget: counting down a pomodoro phase or
/// up for a running stopwatch.
private struct DeskTimerText: View {
    let desk: WidgetSnapshot.Desk

    var body: some View {
        if let end = desk.phaseEndsAt, end > .now {
            Text(timerInterval: Date.now...end, countsDown: true)
                .monospacedDigit()
        } else if let since = desk.focusingSince {
            Text(since, style: .timer)
                .monospacedDigit()
        } else {
            Text("Duraklatıldı")
        }
    }
}

private struct Metric: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.55))
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

#Preview(as: .systemMedium) {
    FocusTodayWidget()
} timeline: {
    FocusEntry(date: .now, snapshot: .placeholder)
}
