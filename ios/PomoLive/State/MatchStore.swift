import Foundation
import Observation

/// Looking for a study buddy: waiting in the server's queue until someone asking for the same
/// pomodoro length turns up, or giving up after two minutes.
@MainActor
@Observable
final class MatchStore {
    enum State: Equatable {
        case idle
        case waiting(since: Date)
        case found(MatchFound)
        case timedOut
    }

    static let waitLimit: Duration = .seconds(120)

    private(set) var state = State.idle
    var error: LibraryError?

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private var timeout: Task<Void, Never>?

    init(socket: LibrarySocket) {
        self.socket = socket
    }

    func search(focusMinutes: Int, categoryKey: String) async {
        timeout?.cancel()
        state = .waiting(since: .now)
        do {
            let result = try await socket.send(RequestMatchCommand(focusMinutes: focusMinutes, categoryKey: categoryKey))
            // When matched right away, `match:found` arrives as an event and sets the state.
            guard result.status == .waiting, case .waiting = state else { return }
            timeout = Task { [weak self] in
                try? await Task.sleep(for: Self.waitLimit)
                guard !Task.isCancelled, let self, case .waiting = self.state else { return }
                self.state = .timedOut
                _ = try? await self.socket.send(CancelMatchCommand())
            }
        } catch {
            state = .idle
            self.error = LibraryError(error)
        }
    }

    func cancel() {
        timeout?.cancel()
        if case .waiting = state { Task { _ = try? await socket.send(CancelMatchCommand()) } }
        state = .idle
    }

    func apply(_ event: LibraryEvent) {
        guard case .matchFound(let match) = event else { return }
        timeout?.cancel()
        state = .found(match)
    }

    func reset() {
        timeout?.cancel()
        state = .idle
    }
}
