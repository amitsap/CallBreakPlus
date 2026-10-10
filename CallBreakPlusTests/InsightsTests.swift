import Foundation
import Testing
@testable import CallBreakPlus

@Suite("Insights")
struct InsightsTests {
    private func game(_ n: Int, _ difficulty: BotDifficulty = .intermediate, made: Int = 5, of placed: Int = 5, score: Double = 0, won: Bool = false, rounds: Int = 5) -> GameSummary {
        GameSummary(won: won, difficulty: difficulty, totalScore: score, bidsMet: made, totalBids: placed,
                    date: Date(timeIntervalSince1970: TimeInterval(n) * 3600), roundCount: rounds)
    }

    /// Scores compare only within one game length; the trend is a rate and keeps every game.
    @Test func scoreSeriesKeepsFiveRoundGamesAndRenumbers() {
        let history = [game(4, score: 6), game(3, score: 40, rounds: 10), game(2, score: 3, rounds: 3), game(1, score: 9)]
        let insights = Insights(history: history, difficulty: nil)
        #expect(insights.points.map(\.score) == [9, 3, 40, 6])
        #expect(insights.scorePoints.map(\.score) == [9, 6])
        #expect(insights.scorePoints.map(\.game) == [1, 2])
        #expect(insights.scorePoints.last?.callRate == insights.points.last?.callRate)
    }

    @Test func scoreSeriesIsEmptyWithoutFiveRoundGames() {
        let insights = Insights(history: [game(1, rounds: 3)], difficulty: nil)
        #expect(insights.points.count == 1)
        #expect(insights.scorePoints.isEmpty)
    }

    @Test func pointsRunOldestFirst() {
        let history = [game(3, score: 9.1), game(2, score: -4), game(1, score: 12.3, won: true)]
        let insights = Insights(history: history, difficulty: nil)
        #expect(insights.points.map(\.game) == [1, 2, 3])
        #expect(insights.points.map(\.score) == [12.3, -4, 9.1])
        #expect(insights.points.map(\.won) == [true, false, false])
    }

    @Test func filterKeepsOneDifficultyAndRenumbers() {
        let history = [game(4, .advanced), game(3, .beginner), game(2, .advanced, score: 7), game(1, .beginner)]
        let insights = Insights(history: history, difficulty: .advanced)
        #expect(insights.points.count == 2)
        #expect(insights.points.map(\.game) == [1, 2])
        #expect(insights.points.first?.score == 7)
    }

    @Test func noGamesGivesNoPoints() {
        #expect(Insights(history: [], difficulty: nil).points.isEmpty)
        #expect(Insights(history: [game(1, .beginner)], difficulty: .advanced).points.isEmpty)
    }

    /// The trend pools calls across the window rather than averaging per-game rates.
    @Test func trendPoolsCallsOverTheWindow() {
        // Oldest first: 5 of 5, then a Thok game that ended after 1 call, missed.
        let history = [game(2, made: 0, of: 1), game(1, made: 5, of: 5)]
        let points = Insights(history: history, difficulty: nil).points
        #expect(points[0].callRate == 1)
        #expect(points[1].callRate == 5.0 / 6.0)
    }

    @Test func trendForgetsGamesOlderThanTheWindow() {
        // 15 games: the oldest 5 made nothing, the newest 10 made every call.
        let history = (1...15).reversed().map { n in game(n, made: n <= 5 ? 0 : 5, of: 5) }
        let points = Insights(history: history, difficulty: nil).points
        #expect(points[4].callRate == 0)
        #expect(points[9].callRate == 0.5)
        #expect(points[14].callRate == 1)
    }

    @Test func gameWithNoCallsCountsAsZero() {
        let points = Insights(history: [game(1, made: 0, of: 0)], difficulty: nil).points
        #expect(points[0].callRate == 0)
    }
}
