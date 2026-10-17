import Foundation
import Observation

/// The İstatistik tab: summary numbers, the last 7 days and paged session history. Notices badges
/// earned since the last look (streaks are badges too) and offers one to celebrate.
@MainActor
@Observable
final class StatsStore {
    private(set) var summary: StatsSummary?
    private(set) var history: [HistoryEntry] = []
    private(set) var hasMoreHistory = false
    var error: LibraryError?
    /// A badge earned since the last refresh, waiting to be celebrated.
    var celebration: Celebration?
    var userId: String?

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
            noticeNewBadges(in: newSummary)
            Task { await WeeklySummary.schedule(with: newSummary) }
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

    /// Remembers which badges the reader has already seen per account. The very first look only
    /// records them, so badges earned before this version never pop up all at once.
    private func noticeNewBadges(in summary: StatsSummary) {
        guard let userId, let badges = summary.badges else { return }
        let key = "\(Preferences.celebratedBadges).\(userId)"
        let earned = Set(badges.filter(\.earned).map(\.id))
        let seen = UserDefaults.standard.stringArray(forKey: key).map(Set.init)
        UserDefaults.standard.set(Array(earned.union(seen ?? [])), forKey: key)
        guard let seen else { return }
        let fresh = badges.filter { $0.earned && !seen.contains($0.id) }
        // Streaks first: they are the ones people chase day after day.
        if let badge = fresh.first(where: { $0.id.hasPrefix("streak") }) ?? fresh.first {
            celebration = Celebration(badge: badge)
        }
    }

    func reset() {
        WeeklySummary.cancel()
        celebration = nil
        summary = nil
        history = []
        hasMoreHistory = false
    }
}
