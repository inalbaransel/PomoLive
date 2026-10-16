import Foundation
import WidgetKit

/// Keeps the widgets' snapshot in step with the app: today's focus, streak, goal and the desk.
/// Watches the stores and rewrites the shared snapshot only when what widgets show has changed.
@MainActor
final class WidgetBridge {
    private var last: WidgetSnapshot?

    func start(_ app: AppModel) {
        Task { [weak self, weak app] in
            let changes = Observations {
                guard let app else { return nil as SnapshotInputs? }
                return SnapshotInputs(
                    summary: app.stats.summary.map { [$0.todayMs, $0.weekMs, Int64($0.streakDays)] },
                    goal: app.user?.dailyGoalMinutes,
                    desk: app.seat.desk,
                    phase: app.seat.phase.map { $0 == .focus },
                    signedIn: app.phase == .signedIn
                )
            }
            for await _ in changes {
                guard let app else { return }
                self?.write(from: app)
            }
        }
    }

    private func write(from app: AppModel) {
        guard app.phase == .signedIn else {
            WidgetSnapshot(todayMs: 0, weekMs: 0, streakDays: 0, dailyGoalMinutes: nil, desk: nil,
                           day: Calendar.current.startOfDay(for: .now), updatedAt: .now).save()
            WidgetCenter.shared.reloadAllTimelines()
            last = nil
            return
        }
        let clock = app.time.clock
        let desk = app.seat.desk.map { desk -> WidgetSnapshot.Desk in
            let reading = desk.timer.reading(at: clock.now)
            let resting = reading.phase == .rest
            return WidgetSnapshot.Desk(
                categoryName: desk.category.displayName,
                categorySymbol: desk.category.symbol,
                focusingSince: resting || reading.phaseEndsAt != nil
                    ? nil : Date.now.addingTimeInterval(-Double(reading.focusedMs) / 1000),
                phaseEndsAt: reading.phaseEndsAt.map(clock.localDate),
                isResting: resting
            )
        }
        var snapshot = WidgetSnapshot(
            todayMs: app.stats.summary?.todayMs ?? last?.todayMs ?? 0,
            weekMs: app.stats.summary?.weekMs ?? last?.weekMs ?? 0,
            streakDays: app.stats.summary?.streakDays ?? last?.streakDays ?? 0,
            dailyGoalMinutes: app.user?.dailyGoalMinutes,
            desk: desk,
            day: Calendar.current.startOfDay(for: .now),
            updatedAt: .now
        )
        // Ignore timestamps when deciding whether anything visible changed.
        if var previous = last {
            previous.updatedAt = snapshot.updatedAt
            if previous == snapshot { return }
        }
        snapshot.save()
        last = snapshot
        WidgetCenter.shared.reloadAllTimelines()
    }
}

private struct SnapshotInputs: Equatable, Sendable {
    var summary: [Int64]?
    var goal: Int?
    var desk: DeskRecord?
    var phase: Bool?
    var signedIn: Bool
}
