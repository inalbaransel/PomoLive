import Foundation
import Observation

/// The reader's own desk, wherever it is. Lives above the tabs so the timer keeps going (and shows in
/// the tab bar accessory, Live Activity and notifications) while the reader browses rooms or stats.
@MainActor
@Observable
final class SeatStore {
    private(set) var desk: DeskRecord?
    private(set) var room: RoomState?
    private(set) var phase: TimerPhase?
    var userId: String?
    var error: LibraryError?

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private let time: ServerTime
    @ObservationIgnored private let haptics = ArcadeHaptics()
    @ObservationIgnored private let liveActivity = FocusActivityController()
    @ObservationIgnored private let notifications = PhaseNotifications()
    @ObservationIgnored private var phaseTask: Task<Void, Never>?

    init(socket: LibrarySocket, time: ServerTime) {
        self.socket = socket
        self.time = time
        liveActivity.end()
    }

    func reading(at serverNow: Int64) -> TimerReading? {
        desk?.timer.reading(at: serverNow)
    }

    /// Asks the server where the reader sits, after connecting or reconnecting.
    func refresh() async {
        let sentAt = ServerClock.deviceNow()
        guard let result = try? await socket.send(MySeatCommand()) else { return }
        time.calibrate(serverTime: result.serverTime, sentAt: sentAt)
        update(desk: result.desk, room: result.room)
    }

    func adopt(_ desk: DeskRecord, in room: RoomState) {
        update(desk: desk, room: room)
    }

    func changeTimer(_ action: ChangeTimerCommand.Action) async {
        do {
            let result = try await socket.send(ChangeTimerCommand(action: action))
            update(desk: result.desk, room: room)
            play(.toggleBreak)
        } catch {
            fail(with: error)
        }
    }

    func stand() async {
        do {
            _ = try await socket.send(StandCommand())
            update(desk: nil, room: nil)
            play(.standUp)
        } catch {
            fail(with: error)
        }
    }

    /// Own-desk events arrive from any room, also while the reader is not looking at it.
    func apply(_ event: LibraryEvent) {
        switch event {
        case .deskOccupied(_, let desk), .deskUpdated(_, let desk):
            if desk.userId == userId { update(desk: desk, room: room) }
        case .deskVacated(_, let deskId, let userId):
            if userId == self.userId, deskId == desk?.deskId { update(desk: nil, room: nil) }
        case .roomClosed(let roomId):
            if roomId == room?.id { update(desk: nil, room: nil) }
        case .roomUpdated(let room):
            if room.id == self.room?.id { update(desk: desk, room: room) }
        case .presence, .memberRemoved, .chatMessage, .chatDeleted, .chatTyping, .friendStarted:
            break
        }
    }

    /// Re-applies preferences (e.g. notifications toggled in Profile).
    func preferencesChanged() {
        syncSystemSurfaces()
    }

    func reset() {
        update(desk: nil, room: nil)
    }

    // MARK: - Private

    private func update(desk: DeskRecord?, room: RoomState?) {
        self.desk = desk
        self.room = desk == nil ? nil : room
        schedulePhaseTracking()
        syncSystemSurfaces()
    }

    /// Wakes exactly at each phase boundary to buzz and refresh the Live Activity; no per-second ticking.
    private func schedulePhaseTracking() {
        phaseTask?.cancel()
        phase = reading(at: time.clock.now)?.phase
        phaseTask = Task { [weak self] in
            while let delay = self?.millisecondsToNextPhase() {
                try? await Task.sleep(for: .milliseconds(delay))
                guard !Task.isCancelled, let self else { return }
                let next = self.reading(at: self.time.clock.now)?.phase
                if next != self.phase { self.play(.phaseChange) }
                self.phase = next
                self.syncSystemSurfaces()
            }
        }
    }

    private func millisecondsToNextPhase() -> Int64? {
        guard let end = reading(at: time.clock.now)?.phaseEndsAt else { return nil }
        return max(50, end - time.clock.now + 50)
    }

    private func syncSystemSurfaces() {
        let defaults = UserDefaults.standard
        let notificationsEnabled = defaults.object(forKey: Preferences.phaseNotifications) as? Bool ?? true
        notifications.schedule(for: desk?.timer, categoryName: desk?.category.displayName ?? "", clock: time.clock, enabled: notificationsEnabled)

        guard let desk, let reading = reading(at: time.clock.now) else {
            liveActivity.end()
            return
        }
        liveActivity.sync(
            attributes: FocusActivityAttributes(
                categorySymbol: desk.category.symbol,
                categoryColor: desk.category.color,
                categoryName: desk.category.displayName,
                roomName: room?.displayName ?? "PomoLive",
                avatarSpriteId: desk.avatarSpriteId,
                isPomodoro: desk.timer.mode == .pomodoro
            ),
            state: FocusActivityAttributes.ContentState(
                phase: reading.phase == .focus ? .focus : .rest,
                phaseEndsAt: reading.phaseEndsAt.map(time.clock.localDate),
                countUpFrom: desk.timer.mode == .stopwatch && reading.phase == .focus
                    ? Date.now.addingTimeInterval(-Double(reading.focusedMs) / 1000)
                    : nil,
                focusedMinutes: Int(reading.focusedMs / 60_000)
            )
        )
    }

    private func play(_ pattern: ArcadeHaptics.Pattern) {
        if UserDefaults.standard.object(forKey: Preferences.haptics) as? Bool ?? true { haptics.play(pattern) }
    }

    private func fail(with error: any Error) {
        self.error = LibraryError(error)
        play(.denied)
    }
}
