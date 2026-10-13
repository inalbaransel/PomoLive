import Foundation

/// The hall's shared pomodoro rhythm. Same formula as the server's `cyclePhaseAt`, so every
/// device shows the same countdown from nothing but the room's anchor time.
struct HallCycle: Equatable, Sendable {
    let phase: CyclePhase
    let endsAt: Int64

    init(room: RoomState, serverNow: Int64) {
        let focusMs = Int64(room.focusMinutes) * 60_000
        let periodMs = focusMs + Int64(room.breakMinutes) * 60_000
        let elapsed = ((serverNow - room.cycleAnchorAt) % periodMs + periodMs) % periodMs
        let periodStart = serverNow - elapsed
        if elapsed < focusMs {
            phase = .focus
            endsAt = periodStart + focusMs
        } else {
            phase = .rest
            endsAt = periodStart + periodMs
        }
    }

    var title: String {
        phase == .focus ? "Salon odakta" : "Salon molada"
    }
}
