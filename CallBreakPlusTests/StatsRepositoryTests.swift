import Foundation
import Testing
import SwiftData
@testable import CallBreakPlus

@MainActor
@Suite("Stats Repository")
struct StatsRepositoryTests {
    private func makeContainer() -> ModelContainer {
        try! StatsMigrationPlan.container(ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func makeFileBackedContainer() -> (container: ModelContainer, storeURL: URL) {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString + ".store")
        let container = try! StatsMigrationPlan.container(ModelConfiguration(url: url))
        return (container, url)
    }

    private func makeResult(won: Bool, difficulty: BotDifficulty = .intermediate, date: Date, totalScore: Double? = nil, roundCount: Int = 5) -> GameResult {
        GameResult(
            won: won, difficulty: difficulty, totalScore: totalScore ?? (won ? 30 : 10),
            roundScores: [30], bids: [3], tricksWon: won ? [3] : [2], date: date, roundCount: roundCount
        )
    }

    @Test func recordedGameKeepsItsLength() async throws {
        let repo = SwiftDataStatsRepository(modelContainer: makeContainer())
        try await repo.recordGameResult(makeResult(won: true, date: Date(timeIntervalSince1970: 0), roundCount: 10))
        try await repo.recordGameResult(makeResult(won: true, date: Date(timeIntervalSince1970: 1), roundCount: 3))

        let recent = try await repo.fetchRecentGames(limit: 2)
        #expect(recent.map(\.roundCount) == [3, 10])
    }

    /// A game's length scales its score, so the average leaves out 3- and 10-round games.
    @Test func averageScoreCountsFiveRoundGamesOnly() async throws {
        let repo = SwiftDataStatsRepository(modelContainer: makeContainer())
        try await repo.recordGameResult(makeResult(won: true, date: Date(timeIntervalSince1970: 0), totalScore: 20))
        try await repo.recordGameResult(makeResult(won: true, date: Date(timeIntervalSince1970: 1), totalScore: 30))
        try await repo.recordGameResult(makeResult(won: true, date: Date(timeIntervalSince1970: 2), totalScore: 70, roundCount: 10))
        try await repo.recordGameResult(makeResult(won: false, date: Date(timeIntervalSince1970: 3), totalScore: 2, roundCount: 3))

        let stats = try await repo.fetchStats()
        #expect(stats.gamesPlayed == 4)
        #expect(stats.averageScore == 25)
    }

    @Test func averageScoreIsZeroWithoutFiveRoundGames() async throws {
        let repo = SwiftDataStatsRepository(modelContainer: makeContainer())
        try await repo.recordGameResult(makeResult(won: true, date: Date(timeIntervalSince1970: 0), totalScore: 70, roundCount: 10))

        #expect(try await repo.fetchStats().averageScore == 0)
    }

    @Test func recordingAWonGameUpdatesStatsAndStreak() async throws {
        let repo = SwiftDataStatsRepository(modelContainer: makeContainer())
        try await repo.recordGameResult(makeResult(won: true, difficulty: .advanced, date: Date()))

        let stats = try await repo.fetchStats()
        #expect(stats.gamesPlayed == 1)
        #expect(stats.gamesWon == 1)
        #expect(stats.advancedGames == 1)
        #expect(stats.advancedWins == 1)
        #expect(stats.currentWinStreak == 1)
        #expect(stats.longestWinStreak == 1)
    }

    @Test func winLossSequenceTracksCurrentAndLongestStreak() async throws {
        let repo = SwiftDataStatsRepository(modelContainer: makeContainer())
        let base = Date(timeIntervalSince1970: 0)
        try await repo.recordGameResult(makeResult(won: true, date: base))
        try await repo.recordGameResult(makeResult(won: true, date: base.addingTimeInterval(1)))
        try await repo.recordGameResult(makeResult(won: false, date: base.addingTimeInterval(2)))
        try await repo.recordGameResult(makeResult(won: true, date: base.addingTimeInterval(3)))

        let stats = try await repo.fetchStats()
        #expect(stats.currentWinStreak == 1)
        #expect(stats.longestWinStreak == 2)
    }

    @Test func fetchRecentGamesReturnsNewestFirstAndCapped() async throws {
        let repo = SwiftDataStatsRepository(modelContainer: makeContainer())
        let base = Date(timeIntervalSince1970: 0)
        for i in 0..<5 {
            try await repo.recordGameResult(makeResult(won: true, date: base.addingTimeInterval(Double(i))))
        }

        let recent = try await repo.fetchRecentGames(limit: 3)
        #expect(recent.map(\.date) == [
            base.addingTimeInterval(4), base.addingTimeInterval(3), base.addingTimeInterval(2),
        ])
    }

    @Test func resetStatsClearsEverything() async throws {
        let repo = SwiftDataStatsRepository(modelContainer: makeContainer())
        try await repo.recordGameResult(makeResult(won: true, date: Date()))
        try await repo.resetStats()

        let stats = try await repo.fetchStats()
        #expect(stats.gamesPlayed == 0)
        #expect(stats.currentWinStreak == 0)
        let recent = try await repo.fetchRecentGames(limit: 3)
        #expect(recent.isEmpty)
    }

    // Proves rollback semantics are viable at all for resetStats. `context.delete(model:)`
    // (a batch/predicate delete) executes immediately against the store and is NOT undone
    // by rollback() — verified separately. Object-level `context.delete(_:)` on fetched
    // instances, exercised here, is what resetStats must use for its rollback-on-failed-save
    // guarantee to actually hold.
    @Test func rollbackUndoesUnsavedObjectDeletes() async throws {
        let container = makeContainer()
        let repo = SwiftDataStatsRepository(modelContainer: container)
        try await repo.recordGameResult(makeResult(won: true, date: Date(timeIntervalSince1970: 0)))
        try await repo.recordGameResult(makeResult(won: true, date: Date(timeIntervalSince1970: 1)))

        let context = container.mainContext
        let records = try context.fetch(FetchDescriptor<GameRecord>())
        for record in records { context.delete(record) }
        context.rollback()

        let stats = try await repo.fetchStats()
        #expect(stats.gamesPlayed == 2)
    }

    // Same guarantee as rollbackUndoesUnsavedObjectDeletes, but against the file-backed
    // SQLite store production actually uses — the in-memory store alone doesn't prove
    // rollback() behaves the same way against SQLite's on-disk WAL.
    @Test func rollbackUndoesUnsavedObjectDeletesOnFileBackedStore() async throws {
        let (container, storeURL) = makeFileBackedContainer()
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let repo = SwiftDataStatsRepository(modelContainer: container)
        try await repo.recordGameResult(makeResult(won: true, date: Date(timeIntervalSince1970: 0)))
        try await repo.recordGameResult(makeResult(won: true, date: Date(timeIntervalSince1970: 1)))

        let context = container.mainContext
        let records = try context.fetch(FetchDescriptor<GameRecord>())
        for record in records { context.delete(record) }
        context.rollback()

        let stats = try await repo.fetchStats()
        #expect(stats.gamesPlayed == 2)
    }
}
