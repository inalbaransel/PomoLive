import Foundation
import Observation
import UserNotifications

/// Scheduled events of rooms, loaded per room and kept fresh by the server's change pings.
/// Saying "I'm coming" books two local reminders (10 minutes before and at the start), so they
/// arrive even when the app is closed; cancelled or skipped events lose their reminders.
@MainActor
@Observable
final class RoomEventsStore {
    private(set) var byRoom: [String: [RoomEventItem]] = [:]
    var error: LibraryError?

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private let center = UNUserNotificationCenter.current()

    init(socket: LibrarySocket) {
        self.socket = socket
    }

    func events(in roomId: String) -> [RoomEventItem] { byRoom[roomId] ?? [] }

    func load(_ roomId: String) async {
        do {
            let events = try await socket.send(ListRoomEventsCommand(roomId: roomId)).events
            byRoom[roomId] = events
            await syncReminders(roomId: roomId, events: events)
        } catch {
            if byRoom[roomId] == nil { self.error = LibraryError(error) }
        }
    }

    func create(roomId: String, title: String, start: Date, durationMinutes: Int) async throws {
        _ = try await socket.send(CreateRoomEventCommand(
            roomId: roomId, title: title,
            startsAt: Int64(start.timeIntervalSince1970 * 1000), durationMinutes: durationMinutes
        ))
        await load(roomId)
    }

    func delete(_ event: RoomEventItem) async {
        do {
            _ = try await socket.send(DeleteRoomEventCommand(eventId: event.id))
            await load(event.roomId)
        } catch {
            self.error = LibraryError(error)
        }
    }

    func setGoing(_ event: RoomEventItem, _ going: Bool) async {
        do {
            _ = try await socket.send(RsvpRoomEventCommand(eventId: event.id, going: going))
            if going { _ = try? await center.requestAuthorization(options: [.alert, .sound]) }
            await load(event.roomId)
        } catch {
            self.error = LibraryError(error)
        }
    }

    func apply(_ event: LibraryEvent) {
        guard case .roomEventsChanged(let roomId) = event, byRoom[roomId] != nil else { return }
        Task { await load(roomId) }
    }

    func reset() {
        byRoom = [:]
    }

    // MARK: Reminders

    private static func identifiers(_ event: RoomEventItem) -> [String] {
        ["event-\(event.roomId)-\(event.id)-soon", "event-\(event.roomId)-\(event.id)-start"]
    }

    /// Reminders exist exactly for the events in `roomId` the reader is going to.
    private func syncReminders(roomId: String, events: [RoomEventItem]) async {
        let pending = await center.pendingNotificationRequests().map(\.identifier)
            .filter { $0.hasPrefix("event-\(roomId)-") }
        let wanted = events.filter(\.isGoing)
        let keep = Set(wanted.flatMap(Self.identifiers))
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { !keep.contains($0) })

        let now = Date.now
        for event in wanted {
            let ids = Self.identifiers(event)
            for (id, fireAt, isStart) in [(ids[0], event.start.addingTimeInterval(-600), false), (ids[1], event.start, true)]
            where fireAt > now && !pending.contains(id) {
                let content = UNMutableNotificationContent()
                content.title = isStart
                    ? String(localized: "\(event.title) başladı")
                    : String(localized: "\(event.title) 10 dakika sonra")
                content.body = String(localized: "Odaya gir, masana otur.")
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireAt.timeIntervalSince(now), repeats: false)
                try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }
}
