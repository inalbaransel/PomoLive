import Foundation

/// The single WebSocket to the PomoLive server.
///
/// Requests are correlated with replies by `ref`, so callers simply `await send(command)`.
/// Everything the server pushes on its own arrives through `events`.
actor LibrarySocket {
    enum Event: Sendable {
        case disconnected
        case broadcast(LibraryEvent)
    }

    nonisolated let events: AsyncStream<Event>
    private let eventSink: AsyncStream<Event>.Continuation
    private let url: URL
    private let session = URLSession(configuration: .default)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let requestTimeout: Duration = .seconds(10)

    private var task: URLSessionWebSocketTask?
    private var pending: [String: CheckedContinuation<Data, any Error>] = [:]
    private var nextRef = 0

    init(url: URL) {
        self.url = url
        (events, eventSink) = AsyncStream.makeStream(of: Event.self)
    }

    var isConnected: Bool { task != nil }

    /// Opens the socket and waits until the server answers a ping, so the first command cannot race the handshake.
    func connect() async throws {
        disconnect()
        let task = session.webSocketTask(with: url)
        task.maximumMessageSize = 1 << 20
        self.task = task
        task.resume()
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                task.sendPing { error in
                    if let error { continuation.resume(throwing: error) } else { continuation.resume() }
                }
            }
        } catch {
            close(task)
            throw LibraryError(error)
        }
        receive(on: task)
    }

    func disconnect() {
        guard let task else { return }
        task.cancel(with: .normalClosure, reason: nil)
        close(task)
    }

    func send<Command: LibraryCommand>(_ command: Command) async throws -> Command.Result {
        guard let task else { throw LibraryError.offline }
        nextRef += 1
        let ref = "r\(nextRef)"
        let frame = try encoder.encode(OutgoingFrame(event: Command.event, ref: ref, payload: command))

        Task {
            do {
                try await task.send(.string(String(decoding: frame, as: UTF8.self)))
            } catch {
                fail(ref, with: LibraryError(error))
            }
        }
        Task {
            try? await Task.sleep(for: requestTimeout)
            fail(ref, with: LibraryError.timeout)
        }

        let reply = try await withCheckedThrowingContinuation { pending[ref] = $0 }
        do {
            return try decoder.decode(ReplyFrame<Command.Result>.self, from: reply).data.result
        } catch {
            throw LibraryError.malformedResponse
        }
    }

    // MARK: - Receiving

    private func receive(on task: URLSessionWebSocketTask) {
        Task {
            do {
                while true {
                    switch try await task.receive() {
                    case .string(let text): route(Data(text.utf8))
                    case .data(let data): route(data)
                    @unknown default: break
                    }
                }
            } catch {
                close(task)
            }
        }
    }

    private func route(_ data: Data) {
        guard let header = try? decoder.decode(FrameHeader.self, from: data) else { return }
        if header.event == "reply" {
            guard let ref = header.data.ref, let continuation = pending.removeValue(forKey: ref) else { return }
            if let error = header.data.error {
                continuation.resume(throwing: LibraryError.server(code: error.code, message: error.message))
            } else {
                continuation.resume(returning: data)
            }
        } else if let event = decodeBroadcast(header.event, from: data) {
            eventSink.yield(.broadcast(event))
        }
    }

    private func decodeBroadcast(_ event: String, from data: Data) -> LibraryEvent? {
        func payload<Payload: Decodable>(_: Payload.Type) -> Payload? {
            try? decoder.decode(PushFrame<Payload>.self, from: data).data
        }
        switch event {
        case "desk:occupied": return payload(DeskPayload.self).map { .deskOccupied(roomId: $0.roomId, desk: $0.desk) }
        case "desk:updated": return payload(DeskPayload.self).map { .deskUpdated(roomId: $0.roomId, desk: $0.desk) }
        case "desk:vacated":
            return payload(VacatedPayload.self).map { .deskVacated(roomId: $0.roomId, deskId: $0.deskId, userId: $0.userId) }
        case "room:presence":
            return payload(PresencePayload.self).map {
                .presence(roomId: $0.roomId, presenceCount: $0.presenceCount, occupiedCount: $0.occupiedCount)
            }
        case "room:closed": return payload(RoomPayload.self).map { .roomClosed(roomId: $0.roomId) }
        default: return nil
        }
    }

    private func fail(_ ref: String, with error: any Error) {
        pending.removeValue(forKey: ref)?.resume(throwing: error)
    }

    /// Tears down local state for `task`. Ignores tasks that were already replaced by a newer connection.
    private func close(_ task: URLSessionWebSocketTask) {
        guard self.task === task else { return }
        self.task = nil
        for continuation in pending.values { continuation.resume(throwing: LibraryError.offline) }
        pending.removeAll()
        eventSink.yield(.disconnected)
    }
}

// MARK: - Frames

/// `{ "event": ..., "data": { "ref": ..., ...payload } }`
private struct OutgoingFrame<Payload: Encodable>: Encodable {
    let event: String
    let ref: String
    let payload: Payload

    private enum CodingKeys: String, CodingKey { case event, data }
    private enum RefKey: String, CodingKey { case ref }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event, forKey: .event)
        let dataEncoder = container.superEncoder(forKey: .data)
        try payload.encode(to: dataEncoder)
        var refContainer = dataEncoder.container(keyedBy: RefKey.self)
        try refContainer.encode(ref, forKey: .ref)
    }
}

private struct FrameHeader: Decodable {
    struct Body: Decodable {
        struct Failure: Decodable {
            let code: String
            let message: String
        }

        let ref: String?
        let error: Failure?
    }

    let event: String
    let data: Body
}

private struct ReplyFrame<Result: Decodable>: Decodable {
    struct Body: Decodable { let result: Result }
    let data: Body
}

private struct PushFrame<Payload: Decodable>: Decodable {
    let data: Payload
}

private struct DeskPayload: Decodable { let roomId: String; let desk: DeskRecord }
private struct VacatedPayload: Decodable { let roomId: String; let deskId: String; let userId: String }
private struct PresencePayload: Decodable { let roomId: String; let presenceCount: Int; let occupiedCount: Int }
private struct RoomPayload: Decodable { let roomId: String }
