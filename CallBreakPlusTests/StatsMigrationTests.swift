import Foundation
import Testing
import SwiftData
@testable import CallBreakPlus

private final class FixtureBundle {}

@MainActor
@Suite("Stats Migration")
struct StatsMigrationTests {
    /// `Fixtures/StatsV1.store` is a store the pre-variant build wrote, before the schema
    /// was versioned: 34 games, 17 won, scores summing to 170.8, streak 2 (longest 5).
    /// Opened in place it would be migrated, so each test opens its own copy.
    private func copyOfShippedStore() throws -> URL {
        let fixture = try #require(Bundle(for: FixtureBundle.self).url(forResource: "StatsV1", withExtension: "store"))
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appending(path: "default.store")
        try FileManager.default.copyItem(at: fixture, to: url)
        return url
    }

    @Test func shippedStoreOpensWithItsRecordsIntact() async throws {
        let url = try copyOfShippedStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let repo = SwiftDataStatsRepository(modelContainer: try StatsMigrationPlan.container(ModelConfiguration(url: url)))

        let stats = try await repo.fetchStats()
        #expect(stats.gamesPlayed == 34)
        #expect(stats.gamesWon == 17)
        #expect(stats.currentWinStreak == 2)
        #expect(stats.longestWinStreak == 5)
        #expect(stats.beginnerGames + stats.intermediateGames + stats.advancedGames == 34)

        let games = try await repo.fetchRecentGames(limit: 100)
        #expect(games.count == 34)
        #expect(games.allSatisfy { $0.roundCount == 5 })
        #expect(abs(games.reduce(0) { $0 + $1.totalScore } - 170.8) < 0.001)
        #expect(abs(stats.averageScore - 170.8 / 34) < 0.001)
    }

    @Test func migratedStoreKeepsNewGamesAcrossReopening() async throws {
        let url = try copyOfShippedStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let configuration = ModelConfiguration(url: url)
        let game = GameResult(won: true, difficulty: .advanced, totalScore: 31.2, roundScores: [10, 11, 10.2],
                              bids: [10, 11, 10], tricksWon: [10, 11, 12], date: .now, roundCount: 3)
        do {
            let repo = SwiftDataStatsRepository(modelContainer: try StatsMigrationPlan.container(configuration))
            try await repo.recordGameResult(game)
        }

        let reopened = SwiftDataStatsRepository(modelContainer: try StatsMigrationPlan.container(configuration))
        let games = try await reopened.fetchRecentGames(limit: 100)
        #expect(games.count == 35)
        #expect(games.first?.roundCount == 3)
        #expect(games.dropFirst().allSatisfy { $0.roundCount == 5 })
        let stats = try await reopened.fetchStats()
        #expect(stats.currentWinStreak == 3)
        #expect(abs(stats.averageScore - 170.8 / 34) < 0.001)
    }
}
