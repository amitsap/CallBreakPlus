import Foundation
import Testing
@testable import CallBreakPlus

@Suite("Statistics Panel States")
struct StatisticsModelTests {
    @Test @MainActor func startsLoadingRatherThanShowingZeros() {
        let model = StatisticsModel(repository: StubStatsRepository(stats: PlayerStats()))
        guard case .loading = model.state else {
            Issue.record("Expected .loading before the fetch, got \(model.state)")
            return
        }
    }

    @Test @MainActor func noFinishedGameIsTheFirstRunState() async {
        let model = StatisticsModel(repository: StubStatsRepository(stats: PlayerStats()))
        await model.load()
        guard case .empty = model.state else {
            Issue.record("Expected .empty, got \(model.state)")
            return
        }
    }

    @Test @MainActor func aFailedFetchIsTheErrorState() async {
        let model = StatisticsModel(repository: StubStatsRepository(stats: nil))
        await model.load()
        guard case .failed = model.state else {
            Issue.record("Expected .failed, got \(model.state)")
            return
        }
    }

    @Test @MainActor func retryAfterAFailureLoads() async {
        let repo = StubStatsRepository(stats: nil)
        let model = StatisticsModel(repository: repo)
        await model.load()
        await repo.setStats(PlayerStats(gamesPlayed: 2, gamesWon: 1))
        await model.load()
        guard case .loaded(let stats, let recent) = model.state else {
            Issue.record("Expected .loaded, got \(model.state)")
            return
        }
        #expect(stats.gamesPlayed == 2)
        #expect(recent.count == 1)
    }

    @Test @MainActor func resetReturnsToTheFirstRunState() async {
        let repo = StubStatsRepository(stats: PlayerStats(gamesPlayed: 3, gamesWon: 2))
        let model = StatisticsModel(repository: repo)
        await model.load()
        await model.reset()
        #expect(!model.resetFailed)
        guard case .empty = model.state else {
            Issue.record("Expected .empty after reset, got \(model.state)")
            return
        }
    }

    @Test @MainActor func aFailedResetKeepsTheStatsAndSaysSo() async {
        let repo = StubStatsRepository(stats: PlayerStats(gamesPlayed: 3, gamesWon: 2), resetFails: true)
        let model = StatisticsModel(repository: repo)
        await model.load()
        await model.reset()
        #expect(model.resetFailed)
        guard case .loaded(let stats, _) = model.state else {
            Issue.record("Expected .loaded after a failed reset, got \(model.state)")
            return
        }
        #expect(stats.gamesPlayed == 3)
    }
}

/// `stats == nil` makes every fetch throw.
private actor StubStatsRepository: StatsRepository {
    struct Failure: Error {}

    private var stats: PlayerStats?
    private let resetFails: Bool

    init(stats: PlayerStats?, resetFails: Bool = false) {
        self.stats = stats
        self.resetFails = resetFails
    }

    func setStats(_ stats: PlayerStats?) {
        self.stats = stats
    }

    func recordGameResult(_ result: GameResult) async throws {}

    func fetchStats() async throws -> PlayerStats {
        guard let stats else { throw Failure() }
        return stats
    }

    func fetchRecentGames(limit: Int) async throws -> [GameSummary] {
        guard let stats else { throw Failure() }
        guard stats.gamesPlayed > 0 else { return [] }
        return [GameSummary(won: true, difficulty: .intermediate, totalScore: 12.3, bidsMet: 4, totalBids: 5, date: .now, roundCount: 5)]
    }

    func resetStats() async throws {
        if resetFails { throw Failure() }
        stats = PlayerStats()
    }
}
