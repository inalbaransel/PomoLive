import Observation

/// The device-to-server clock offset, shared by every store and view that shows a timer.
@MainActor
@Observable
final class ServerTime {
    private(set) var clock = ServerClock()

    func calibrate(serverTime: Int64, sentAt: Int64) {
        clock.calibrate(serverTime: serverTime, sentAt: sentAt, receivedAt: ServerClock.deviceNow())
    }
}
