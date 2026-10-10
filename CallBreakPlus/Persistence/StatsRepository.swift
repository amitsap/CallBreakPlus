import Foundation

protocol StatsRepository: Sendable {
    func recordGameResult(_ result: GameResult) async throws
    func fetchStats() async throws -> PlayerStats
    func fetchRecentGames(limit: Int) async throws -> [GameSummary]
    func resetStats() async throws
}

struct GameSummary: Identifiable, Sendable {
    var id: Date { date }
    let won: Bool
    let difficulty: BotDifficulty
    let totalScore: Double
    let bidsMet: Int
    let totalBids: Int
    let date: Date
    let roundCount: Int
}

struct GameResult: Sendable {
    let won: Bool
    let difficulty: BotDifficulty
    let totalScore: Double
    let roundScores: [Double]
    let bids: [Int]
    let tricksWon: [Int]
    let date: Date
    let roundCount: Int
}

struct PlayerStats: Sendable {
    var gamesPlayed: Int = 0
    var gamesWon: Int = 0
    var bestRoundScore: Double = 0
    var currentWinStreak: Int = 0
    var longestWinStreak: Int = 0
    var totalBids: Int = 0
    var bidsMet: Int = 0

    var beginnerGames: Int = 0
    var beginnerWins: Int = 0
    var intermediateGames: Int = 0
    var intermediateWins: Int = 0
    var advancedGames: Int = 0
    var advancedWins: Int = 0
    /// Over standard 5-round games only, since a game's length scales its score.
    var averageScore: Double = 0

    var winRate: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(gamesWon) / Double(gamesPlayed)
    }

    var bidAccuracy: Double {
        guard totalBids > 0 else { return 0 }
        return Double(bidsMet) / Double(totalBids)
    }
}
