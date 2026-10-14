import SwiftUI

/// A desk timer's clock: time left in the pomodoro phase, or total focus for a stopwatch
/// (frozen while paused). Re-reads the timer each second, so phase changes need no extra wiring.
struct TimerText: View {
    let timer: DeskTimer
    let clock: ServerClock

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = clock.now
            let reading = timer.reading(at: now)
            let milliseconds = reading.phaseEndsAt.map { max(0, $0 - now) } ?? reading.focusedMs
            Text(
                Duration.milliseconds(milliseconds),
                format: .time(pattern: milliseconds >= 3_600_000 ? .hourMinuteSecond : .minuteSecond)
            )
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: reading.phaseEndsAt != nil))
        }
    }
}
