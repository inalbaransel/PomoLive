import Foundation
import Observation

/// The chat of the room the reader is looking at: its recent history, live messages, who is typing
/// and how many messages arrived while the chat was closed. Sends are optimistic: a message shows up
/// at once and is matched to the server's copy by its `clientId`, or marked failed for a retry.
@MainActor
@Observable
final class ChatStore {
    struct Entry: Identifiable, Hashable {
        enum State: Hashable {
            case sending, sent, failed
        }

        var message: ChatMessage
        var state: State

        var id: String { message.clientId }
    }

    private(set) var roomId: String?
    private(set) var entries: [Entry] = []
    private(set) var hasMore = false
    private(set) var isLoading = false
    private(set) var typing: [PublicUser] = []
    private(set) var unreadCount = 0
    /// Whether the chat sheet is on screen; unread messages are only counted while it is not.
    var isOpen = false {
        didSet { if isOpen { unreadCount = 0 } }
    }
    var error: LibraryError?
    var userId: String?

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private var typingExpiry: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var lastTypingPing = Date.distantPast

    private static let typingVisibleFor = Duration.seconds(4)
    private static let typingPingInterval: TimeInterval = 2.5

    init(socket: LibrarySocket) {
        self.socket = socket
    }

    /// Loads the latest page for `roomId`; called whenever a room is entered or re-entered.
    func open(roomId: String) async {
        if self.roomId != roomId { reset() }
        self.roomId = roomId
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await socket.send(ChatHistoryCommand())
            guard self.roomId == roomId else { return }
            let pending = entries.filter { $0.state != .sent }
            entries = page.messages.map { Entry(message: $0, state: .sent) }
            for entry in pending where !entries.contains(where: { $0.id == entry.id }) { entries.append(entry) }
            hasMore = page.hasMore
        } catch {
            self.error = LibraryError(error)
        }
    }

    func loadOlder() async {
        guard hasMore, !isLoading, let roomId, let oldest = entries.first(where: { $0.state == .sent }) else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let page = try await socket.send(ChatHistoryCommand(before: oldest.message.createdAt))
            guard self.roomId == roomId else { return }
            let known = Set(entries.map(\.id))
            entries.insert(contentsOf: page.messages.filter { !known.contains($0.clientId) }.map { Entry(message: $0, state: .sent) }, at: 0)
            hasMore = page.hasMore
        } catch {
            self.error = LibraryError(error)
        }
    }

    func send(_ text: String, as user: PublicUser) {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, let roomId else { return }
        let message = ChatMessage(
            id: UUID().uuidString, clientId: UUID().uuidString, roomId: roomId, user: user,
            body: String(body.prefix(500)), createdAt: ServerClock.deviceNow()
        )
        entries.append(Entry(message: message, state: .sending))
        deliver(message)
    }

    func retry(_ entry: Entry) {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].state = .sending
        deliver(entry.message)
    }

    func discard(_ entry: Entry) {
        entries.removeAll { $0.id == entry.id }
    }

    func delete(_ entry: Entry) async {
        guard entry.state == .sent else { return discard(entry) }
        do {
            _ = try await socket.send(DeleteChatCommand(messageId: entry.message.id))
            entries.removeAll { $0.id == entry.id }
        } catch {
            self.error = LibraryError(error)
        }
    }

    /// Drops everything a newly blocked reader said or is saying.
    func hideMessages(from userId: String) {
        entries.removeAll { $0.message.user.id == userId }
        clearTyping(userId)
    }

    /// Tells the room the reader is typing, at most once every couple of seconds.
    func userIsTyping() {
        guard Date.now.timeIntervalSince(lastTypingPing) > Self.typingPingInterval else { return }
        lastTypingPing = .now
        Task { _ = try? await socket.send(ChatTypingCommand()) }
    }

    func apply(_ event: LibraryEvent) {
        switch event {
        case .chatMessage(let message):
            guard message.roomId == roomId else { return }
            clearTyping(message.user.id)
            if let index = entries.firstIndex(where: { $0.id == message.clientId }) {
                entries[index] = Entry(message: message, state: .sent)
            } else {
                entries.append(Entry(message: message, state: .sent))
                if !isOpen, message.user.id != userId { unreadCount += 1 }
            }
        case .chatDeleted(let roomId, let messageId):
            guard roomId == self.roomId else { return }
            entries.removeAll { $0.message.id == messageId }
        case .chatTyping(let roomId, let user):
            guard roomId == self.roomId, user.id != userId else { return }
            if !typing.contains(where: { $0.id == user.id }) { typing.append(user) }
            typingExpiry[user.id]?.cancel()
            typingExpiry[user.id] = Task { [weak self] in
                try? await Task.sleep(for: Self.typingVisibleFor)
                guard !Task.isCancelled else { return }
                self?.clearTyping(user.id)
            }
        default:
            break
        }
    }

    func reset() {
        roomId = nil
        entries = []
        hasMore = false
        typing = []
        unreadCount = 0
        typingExpiry.values.forEach { $0.cancel() }
        typingExpiry = [:]
    }

    private func deliver(_ message: ChatMessage) {
        Task {
            do {
                let result = try await socket.send(SendChatCommand(body: message.body, clientId: message.clientId))
                if let index = entries.firstIndex(where: { $0.id == message.clientId }) {
                    entries[index] = Entry(message: result.message, state: .sent)
                }
            } catch {
                if let index = entries.firstIndex(where: { $0.id == message.clientId }) {
                    entries[index].state = .failed
                }
                if case .server(code: "RATE_LIMITED", _) = LibraryError(error) { self.error = LibraryError(error) }
            }
        }
    }

    private func clearTyping(_ userId: String) {
        typingExpiry[userId]?.cancel()
        typingExpiry[userId] = nil
        typing.removeAll { $0.id == userId }
    }
}
