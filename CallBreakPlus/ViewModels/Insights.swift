import Foundation

/// The Pro Insights series for one difficulty or all: each game's total score and
/// the call-accuracy trend, oldest game first. Scores compare only across games of
/// one length, so the score series keeps standard 5-round games; the trend is a rate
/// and keeps every game.
struct Insights {
    struct Point: Identifiable, Equatable {
        /// 1 for the oldest game shown.
        let game: Int
        let score: Double
        let won: Bool
        let difficulty: BotDifficulty
        /// Calls made over calls placed across this game and up to `trendWindow - 1`
        /// games before it, pooled so a short Thok game doesn't weigh like a full one.
        let callRate: Double
        let date: Date
        let roundCount: Int
        var id: Int { game }
    }

    static let trendWindow = 10

    /// Every game, for the trend and the game list.
    let points: [Point]
    /// The 5-round games, numbered from 1, for the score chart.
    let scorePoints: [Point]

    /// `history` is newest first, as the repository returns it.
    init(history: [GameSummary], difficulty: BotDifficulty?) {
        let games = history.reversed().filter { difficulty == nil || $0.difficulty == difficulty }
        let points = games.indices.map { index in
            let window = games[max(0, index - Self.trendWindow + 1)...index]
            let placed = window.reduce(0) { $0 + $1.totalBids }
            let made = window.reduce(0) { $0 + $1.bidsMet }
            let game = games[index]
            return Point(
                game: index + 1,
                score: game.totalScore,
                won: game.won,
                difficulty: game.difficulty,
                callRate: placed == 0 ? 0 : Double(made) / Double(placed),
                date: game.date,
                roundCount: game.roundCount
            )
        }
        self.points = points
        scorePoints = points.filter { $0.roundCount == RuleSet.standard.roundCount }.enumerated().map { offset, point in
            Point(game: offset + 1, score: point.score, won: point.won, difficulty: point.difficulty,
                  callRate: point.callRate, date: point.date, roundCount: point.roundCount)
        }
    }
}
