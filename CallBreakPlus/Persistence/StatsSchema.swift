import Foundation
import SwiftData

/// The models in use: always the latest schema version.
typealias GameRecord = StatsSchemaV2.GameRecord
typealias StreakRecord = StatsSchemaV2.StreakRecord

/// The stats store as shipped before rule variants, when the app had no versioned
/// schema. Frozen: a store from that build must match it exactly to migrate.
enum StatsSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] { [GameRecord.self, StreakRecord.self] }

    @Model
    final class GameRecord {
        var won: Bool
        var difficulty: String
        var totalScore: Double
        var bestRoundScore: Double
        var totalBids: Int
        var bidsMet: Int
        var date: Date

        init(won: Bool, difficulty: String, totalScore: Double, bestRoundScore: Double, totalBids: Int, bidsMet: Int, date: Date) {
            self.won = won
            self.difficulty = difficulty
            self.totalScore = totalScore
            self.bestRoundScore = bestRoundScore
            self.totalBids = totalBids
            self.bidsMet = bidsMet
            self.date = date
        }
    }

    @Model
    final class StreakRecord {
        var currentWinStreak: Int
        var longestWinStreak: Int

        init(currentWinStreak: Int = 0, longestWinStreak: Int = 0) {
            self.currentWinStreak = currentWinStreak
            self.longestWinStreak = longestWinStreak
        }
    }
}

/// Adds each game's length, so scores compare only across games of the same length.
enum StatsSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] { [GameRecord.self, StreakRecord.self] }

    @Model
    final class GameRecord {
        var won: Bool
        var difficulty: String
        var totalScore: Double
        var bestRoundScore: Double
        var totalBids: Int
        var bidsMet: Int
        var date: Date
        /// Rounds the game was set to, not rounds played: a Thok win ends a 5-round game early.
        /// Every game before rule variants was 5 rounds, which the migration fills in.
        var roundCount: Int = 5

        init(won: Bool, difficulty: String, totalScore: Double, bestRoundScore: Double, totalBids: Int, bidsMet: Int, date: Date, roundCount: Int) {
            self.won = won
            self.difficulty = difficulty
            self.totalScore = totalScore
            self.bestRoundScore = bestRoundScore
            self.totalBids = totalBids
            self.bidsMet = bidsMet
            self.date = date
            self.roundCount = roundCount
        }
    }

    @Model
    final class StreakRecord {
        var currentWinStreak: Int
        var longestWinStreak: Int

        init(currentWinStreak: Int = 0, longestWinStreak: Int = 0) {
            self.currentWinStreak = currentWinStreak
            self.longestWinStreak = longestWinStreak
        }
    }
}

enum StatsMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [StatsSchemaV1.self, StatsSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: StatsSchemaV1.self, toVersion: StatsSchemaV2.self)]
    }

    /// The stats container at the latest schema, migrating an older store on open.
    static func container(_ configuration: ModelConfiguration = ModelConfiguration()) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(versionedSchema: StatsSchemaV2.self),
            migrationPlan: StatsMigrationPlan.self,
            configurations: configuration
        )
    }
}
