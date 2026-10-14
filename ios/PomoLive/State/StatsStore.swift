import Observation

/// The İstatistik tab: summary numbers, the last 7 days and paged session history.
@MainActor
@Observable
final class StatsStore {
    private(set) var summary: StatsSummary?
    private(set) var history: [HistoryEntry] = []
    private(set) var hasMoreHistory = false
    var error: LibraryError?

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private var isLoadingHistory = false

    init(socket: LibrarySocket) {
        self.socket = socket
    }

    func refresh() async {
        do {
            async let summary = socket.send(StatsSummaryCommand())
            async let page = socket.send(HistoryCommand(before: nil))
            let (newSummary, newPage) = try await (summary, page)
            self.summary = newSummary
            history = newPage.entries
            hasMoreHistory = newPage.hasMore
        } catch {
            if summary == nil { self.error = LibraryError(error) }
        }
    }

    func loadMoreHistory() async {
        guard hasMoreHistory, !isLoadingHistory, let oldest = history.last else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }
        guard let page = try? await socket.send(HistoryCommand(before: oldest.startedAt)) else { return }
        history += page.entries
        hasMoreHistory = page.hasMore
    }

    func reset() {
        summary = nil
        history = []
        hasMoreHistory = false
    }
}
