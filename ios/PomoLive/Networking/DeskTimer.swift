import Foundation

enum TimerMode: String, Codable, Sendable {
    case pomodoro = "POMODORO"
    case stopwatch = "STOPWATCH"
}

enum TimerPhase: Sendable {
    case focus, rest
}

struct TimerReading: Equatable, Sendable {
    var phase: TimerPhase
    var phaseStartedAt: Int64
    /// `nil` for a stopwatch, which has no planned end.
    var phaseEndsAt: Int64?
    var focusedMs: Int64
}

/// A desk's own timer. Same arithmetic as the server's `desk-timer.ts`: everything derives from
/// stored anchors, so it stays right while the app is suspended and on every device.
enum DeskTimer: Codable, Hashable, Sendable {
    case pomodoro(focusMinutes: Int, breakMinutes: Int, anchorAt: Int64, bankedFocusMs: Int64)
    case stopwatch(running: Bool, since: Int64, bankedFocusMs: Int64)

    var mode: TimerMode {
        switch self {
        case .pomodoro: .pomodoro
        case .stopwatch: .stopwatch
        }
    }

    func reading(at now: Int64) -> TimerReading {
        switch self {
        case .stopwatch(let running, let since, let banked):
            return TimerReading(
                phase: running ? .focus : .rest,
                phaseStartedAt: since,
                phaseEndsAt: nil,
                focusedMs: banked + (running ? max(0, now - since) : 0)
            )
        case .pomodoro(let focusMinutes, let breakMinutes, let anchorAt, let banked):
            let focusMs = Int64(focusMinutes) * 60_000
            let periodMs = focusMs + Int64(breakMinutes) * 60_000
            let elapsed = max(0, now - anchorAt)
            let cycles = elapsed / periodMs
            let withinCycle = elapsed - cycles * periodMs
            let cycleStart = anchorAt + cycles * periodMs
            let inFocus = withinCycle < focusMs
            return TimerReading(
                phase: inFocus ? .focus : .rest,
                phaseStartedAt: inFocus ? cycleStart : cycleStart + focusMs,
                phaseEndsAt: inFocus ? cycleStart + focusMs : cycleStart + periodMs,
                focusedMs: banked + cycles * focusMs + min(withinCycle, focusMs)
            )
        }
    }

    /// Upcoming pomodoro phase boundaries after `now`, for scheduling notifications.
    func upcomingPhaseChanges(after now: Int64, count: Int) -> [(at: Int64, phase: TimerPhase)] {
        guard case .pomodoro(let focusMinutes, let breakMinutes, _, _) = self else { return [] }
        var changes: [(at: Int64, phase: TimerPhase)] = []
        var reading = reading(at: now)
        while changes.count < count, let end = reading.phaseEndsAt {
            let next: TimerPhase = reading.phase == .focus ? .rest : .focus
            changes.append((end, next))
            let length = Int64(next == .focus ? focusMinutes : breakMinutes) * 60_000
            reading = TimerReading(phase: next, phaseStartedAt: end, phaseEndsAt: end + length, focusedMs: 0)
        }
        return changes
    }

    // MARK: Codable — `{ "mode": "POMODORO", ... }` as on the server

    private enum CodingKeys: String, CodingKey {
        case mode, focusMinutes, breakMinutes, anchorAt, bankedFocusMs, running, since
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let banked = try container.decode(Int64.self, forKey: .bankedFocusMs)
        switch try container.decode(TimerMode.self, forKey: .mode) {
        case .pomodoro:
            self = .pomodoro(
                focusMinutes: try container.decode(Int.self, forKey: .focusMinutes),
                breakMinutes: try container.decode(Int.self, forKey: .breakMinutes),
                anchorAt: try container.decode(Int64.self, forKey: .anchorAt),
                bankedFocusMs: banked
            )
        case .stopwatch:
            self = .stopwatch(
                running: try container.decode(Bool.self, forKey: .running),
                since: try container.decode(Int64.self, forKey: .since),
                bankedFocusMs: banked
            )
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        switch self {
        case .pomodoro(let focusMinutes, let breakMinutes, let anchorAt, let banked):
            try container.encode(focusMinutes, forKey: .focusMinutes)
            try container.encode(breakMinutes, forKey: .breakMinutes)
            try container.encode(anchorAt, forKey: .anchorAt)
            try container.encode(banked, forKey: .bankedFocusMs)
        case .stopwatch(let running, let since, let banked):
            try container.encode(running, forKey: .running)
            try container.encode(since, forKey: .since)
            try container.encode(banked, forKey: .bankedFocusMs)
        }
    }
}

/// What the reader picks when sitting down.
enum TimerSetup: Hashable, Sendable, Encodable {
    case pomodoro(focusMinutes: Int, breakMinutes: Int)
    case stopwatch

    private enum CodingKeys: String, CodingKey { case mode, focusMinutes, breakMinutes }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pomodoro(let focusMinutes, let breakMinutes):
            try container.encode(TimerMode.pomodoro, forKey: .mode)
            try container.encode(focusMinutes, forKey: .focusMinutes)
            try container.encode(breakMinutes, forKey: .breakMinutes)
        case .stopwatch:
            try container.encode(TimerMode.stopwatch, forKey: .mode)
        }
    }
}
