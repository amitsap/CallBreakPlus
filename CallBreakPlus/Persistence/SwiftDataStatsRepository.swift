import Foundation
import SwiftData

final class SwiftDataStatsRepository: StatsRepository, @unchecked Sendable {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @MainActor
    func recordGameResult(_ result: GameResult) async throws {
        let context = modelContainer.mainContext

        let bestRound = result.roundScores.max() ?? 0
        var bidsMet = 0
        for i in 0..<result.bids.count {
            if result.tricksWon[i] >= result.bids[i] { bidsMet += 1 }
        }

        let streakDescriptor = FetchDescriptor<StreakRecord>()
        let streaks = try context.fetch(streakDescriptor)

        let record = GameRecord(
            won: result.won,
            difficulty: result.difficulty.rawValue,
            totalScore: result.totalScore,
            bestRoundScore: bestRound,
            totalBids: result.bids.count,
            bidsMet: bidsMet,
            date: result.date,
            roundCount: result.roundCount
        )
        context.insert(record)

        let streak = streaks.first ?? StreakRecord()
        if streaks.isEmpty { context.insert(streak) }

        if result.won {
            streak.currentWinStreak += 1
            streak.longestWinStreak = max(streak.longestWinStreak, streak.currentWinStreak)
        } else {
            streak.currentWinStreak = 0
        }

        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    @MainActor
    func fetchStats() async throws -> PlayerStats {
        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<GameRecord>()
        let records = try context.fetch(descriptor)

        let streakDescriptor = FetchDescriptor<StreakRecord>()
        let streaks = try context.fetch(streakDescriptor)
        let streak = streaks.first

        var stats = PlayerStats()
        stats.gamesPlayed = records.count
        stats.gamesWon = records.filter(\.won).count
        stats.bestRoundScore = records.map(\.bestRoundScore).max() ?? 0
        stats.totalBids = records.reduce(0) { $0 + $1.totalBids }
        stats.bidsMet = records.reduce(0) { $0 + $1.bidsMet }
        stats.currentWinStreak = streak?.currentWinStreak ?? 0
        stats.longestWinStreak = streak?.longestWinStreak ?? 0
        let standardGames = records.filter { $0.roundCount == RuleSet.standard.roundCount }
        stats.averageScore = standardGames.isEmpty ? 0 : standardGames.reduce(0) { $0 + $1.totalScore } / Double(standardGames.count)

        for record in records {
            switch record.difficulty {
            case "beginner":
                stats.beginnerGames += 1
                if record.won { stats.beginnerWins += 1 }
            case "intermediate":
                stats.intermediateGames += 1
                if record.won { stats.intermediateWins += 1 }
            case "advanced":
                stats.advancedGames += 1
                if record.won { stats.advancedWins += 1 }
            default: break
            }
        }

        return stats
    }

    @MainActor
    func fetchRecentGames(limit: Int) async throws -> [GameSummary] {
        let context = modelContainer.mainContext
        var descriptor = FetchDescriptor<GameRecord>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map { record in
            GameSummary(
                won: record.won,
                difficulty: BotDifficulty(rawValue: record.difficulty) ?? .intermediate,
                totalScore: record.totalScore,
                bidsMet: record.bidsMet,
                totalBids: record.totalBids,
                date: record.date,
                roundCount: record.roundCount
            )
        }
    }

    @MainActor
    func resetStats() async throws {
        let context = modelContainer.mainContext
        do {
            // Deleting fetched objects (rather than the batch `delete(model:)` predicate
            // API) keeps the deletions staged as pending context changes, so a failed
            // save's rollback() actually undoes them instead of the store having already
            // applied a partial batch delete.
            for record in try context.fetch(FetchDescriptor<GameRecord>()) {
                context.delete(record)
            }
            for streak in try context.fetch(FetchDescriptor<StreakRecord>()) {
                context.delete(streak)
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
