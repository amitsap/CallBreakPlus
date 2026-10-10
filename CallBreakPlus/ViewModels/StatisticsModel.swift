import Foundation
import Observation

/// What the Statistics panel shows: never invented zeros while loading, after
/// a failure, or before the first finished game.
@MainActor
@Observable
final class StatisticsModel {
    enum State {
        case loading
        /// No finished game yet.
        case empty
        case failed
        /// `history` is newest first, up to `historyLimit` games.
        case loaded(PlayerStats, history: [GameSummary])
    }

    /// Insights reads the whole history; this caps one fetch for a very long-lived install.
    static let historyLimit = 1_000

    private(set) var state: State = .loading
    /// Set when Reset fails; the panel shows it until dismissed.
    var resetFailed = false
    private let repository: (any StatsRepository)?

    init(repository: (any StatsRepository)?) {
        self.repository = repository
    }

    func load() async {
        guard let repository else {
            state = .failed
            return
        }
        state = .loading
        do {
            let stats = try await repository.fetchStats()
            guard stats.gamesPlayed > 0 else {
                state = .empty
                return
            }
            let history = try await repository.fetchRecentGames(limit: Self.historyLimit)
            state = .loaded(stats, history: history)
        } catch {
            state = .failed
        }
    }

    func reset() async {
        guard let repository else { return }
        do {
            try await repository.resetStats()
        } catch {
            resetFailed = true
            return
        }
        await load()
    }
}
