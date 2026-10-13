import Foundation

/// Maps between the device clock and the server clock, so countdowns agree across devices
/// without the server ever streaming ticks.
struct ServerClock: Sendable {
    private(set) var offsetMs: Int64 = 0

    var now: Int64 { Self.deviceNow() + offsetMs }

    func localDate(_ serverMs: Int64) -> Date {
        Date(timeIntervalSince1970: Double(serverMs - offsetMs) / 1000)
    }

    /// NTP-style estimate assuming the reply took as long to travel back as the request took to arrive.
    mutating func calibrate(serverTime: Int64, sentAt: Int64, receivedAt: Int64) {
        offsetMs = serverTime - (sentAt + receivedAt) / 2
    }

    static func deviceNow() -> Int64 {
        Int64((Date().timeIntervalSince1970 * 1000).rounded())
    }
}
