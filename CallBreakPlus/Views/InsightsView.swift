import Charts
import SwiftUI

/// Statistics' Insights card: the player's own score chart, opening the Insights
/// page with Pro and blurred without it.
struct InsightsCard: View {
    let history: [GameSummary]
    let hasPro: Bool
    let onOpen: () -> Void
    /// Without Pro, tapping the blurred card opens the Pro panel.
    let onUnlock: () -> Void

    /// The card's chart shows the latest games only; the page shows them all.
    static let previewGames = 20

    var body: some View {
        let points = Insights(history: Array(history.prefix(Self.previewGames)), difficulty: nil).scorePoints
        Group {
            if hasPro {
                Button(action: onOpen) { card(points) }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Insights")
                    .accessibilityHint("Shows your score and calls made over every game")
            } else {
                Button(action: onUnlock) { card(points) }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Insights, Pro: unlock to see your score chart")
                    .accessibilityHint("Opens Call Break+ Pro")
                    .accessibilityAddTraits(.isButton)
            }
        }
    }

    private func card(_ points: [Insights.Point]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Insights")
                    .font(TableType.headline)
                    .foregroundStyle(TablePalette.ink)
                Spacer(minLength: 4)
                if hasPro {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(TablePalette.faded)
                } else {
                    ProBadge()
                }
            }
            ScoreChart(points: points, compact: true)
                .frame(height: 64)
                .blur(radius: hasPro ? 0 : 5)
                .accessibilityHidden(true)
            Text(hasPro ? "Score and calls made, every game" : "Unlock Insights")
                .font(hasPro ? TableType.caption : TableType.body)
                .foregroundStyle(hasPro ? TablePalette.faded : TablePalette.paperGreen)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// The Insights page inside the Statistics panel: a difficulty filter, the score
/// chart, the call-accuracy trend and every game.
struct InsightsPage: View {
    let history: [GameSummary]
    @Binding var difficulty: BotDifficulty?
    let scoreText: (Double) -> String

    var body: some View {
        let insights = Insights(history: history, difficulty: difficulty)
        let points = insights.points
        VStack(alignment: .leading, spacing: 10) {
            Picker("Difficulty", selection: $difficulty) {
                Text("All").tag(BotDifficulty?.none)
                ForEach(BotDifficulty.allCases, id: \.self) { Text($0.title).tag(BotDifficulty?.some($0)) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)

            if points.isEmpty {
                Text(difficulty.map { "No \($0.title) games yet. Finish one and it shows up here." } ?? "No games yet.")
                    .font(TableType.body)
                    .foregroundStyle(TablePalette.faded)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            chartBox("Score per game", caption: "5-round games, wins in green") {
                                ScoreChart(points: insights.scorePoints, compact: false)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(scoreSummary(insights.scorePoints))

                            chartBox("Calls made", caption: "Over your last \(Insights.trendWindow) games") {
                                CallTrendChart(points: points)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(trendSummary(points))
                        }

                        Text(points.count == 1 ? "1 game" : "\(points.count) games")
                            .font(TableType.headline)
                            .foregroundStyle(TablePalette.ink)
                            .accessibilityAddTraits(.isHeader)
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(points.reversed()) { point in
                                GameRow(won: point.won, date: point.date, detail: GameRow.detail(point.difficulty, roundCount: point.roundCount), score: scoreText(point.score))
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }
            }
        }
    }

    private func chartBox<Chart: View>(_ title: String, caption: String, @ViewBuilder chart: () -> Chart) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(TableType.headline)
                .foregroundStyle(TablePalette.ink)
            Text(caption)
                .font(TableType.caption)
                .foregroundStyle(TablePalette.faded)
                .padding(.bottom, 6)
            chart()
                .frame(height: 130)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }

    private func scoreSummary(_ points: [Insights.Point]) -> String {
        guard !points.isEmpty else { return "Score per game: no 5-round games yet" }
        let scores = points.map(\.score)
        let best = scores.max() ?? 0
        let average = scores.reduce(0, +) / Double(scores.count)
        return "Score per game over \(points.count) games: best \(scoreText(best)), average \(scoreText((average * 10).rounded() / 10)), latest \(scoreText(scores.last ?? 0))"
    }

    private func trendSummary(_ points: [Insights.Point]) -> String {
        let latest = (points.last?.callRate ?? 0).formatted(.percent.precision(.fractionLength(0)))
        return "Calls made over your last \(Insights.trendWindow) games: \(latest)"
    }
}

/// One finished game: result, date, a detail line and the total score.
struct GameRow: View {
    let won: Bool
    let date: Date
    let detail: String
    let score: String

    /// The difficulty, and the game length when it isn't the standard 5 rounds.
    static func detail(_ difficulty: BotDifficulty, roundCount: Int) -> String {
        roundCount == RuleSet.standard.roundCount ? difficulty.title : "\(difficulty.title) · \(roundCount) rounds"
    }

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(won ? TablePalette.accentGreen : TablePalette.cardRuled)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(won ? "Win" : "Loss") · \(date.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(TableType.body)
                    .foregroundStyle(TablePalette.ink)
                Text(detail)
                    .font(TableType.caption)
                    .foregroundStyle(TablePalette.faded)
            }
            Spacer(minLength: 4)
            Text(score)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(TablePalette.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A small gold "PRO" tag on paper.
struct ProBadge: View {
    var body: some View {
        Text("Pro")
            .font(.system(size: 10, weight: .black, design: .rounded))
            .textCase(.uppercase)
            .kerning(0.8)
            .foregroundStyle(TablePalette.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(TablePalette.gold, in: Capsule())
            .accessibilityLabel("Pro")
    }
}

/// Each game's total score as a bar, green for a win.
private struct ScoreChart: View {
    let points: [Insights.Point]
    let compact: Bool

    var body: some View {
        Chart(points) { point in
            BarMark(x: .value("Game", point.game), y: .value("Score", point.score))
                .foregroundStyle(point.won ? TablePalette.accentGreen : TablePalette.cardRuled)
            RuleMark(y: .value("Zero", 0))
                .foregroundStyle(TablePalette.faded.opacity(0.5))
                .lineStyle(StrokeStyle(lineWidth: 1))
        }
        .chartXAxis(.hidden)
        .chartYAxis(compact ? .hidden : .automatic)
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(TablePalette.cardRuled.opacity(0.35))
                AxisValueLabel().foregroundStyle(TablePalette.faded)
            }
        }
    }
}

/// The share of calls made over the trailing window, game by game.
private struct CallTrendChart: View {
    let points: [Insights.Point]

    var body: some View {
        Chart(points) { point in
            AreaMark(x: .value("Game", point.game), y: .value("Calls made", point.callRate))
                .foregroundStyle(TablePalette.accentGreen.opacity(0.15))
                .interpolationMethod(.monotone)
            LineMark(x: .value("Game", point.game), y: .value("Calls made", point.callRate))
                .foregroundStyle(TablePalette.paperGreen)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            if point.id == points.last?.id {
                PointMark(x: .value("Game", point.game), y: .value("Calls made", point.callRate))
                    .foregroundStyle(TablePalette.paperGreen)
                    .annotation(position: .top, alignment: .trailing) {
                        Text(point.callRate.formatted(.percent.precision(.fractionLength(0))))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(TablePalette.paperGreen)
                    }
            }
        }
        .chartXAxis(.hidden)
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 0.5, 1]) { value in
                AxisGridLine().foregroundStyle(TablePalette.cardRuled.opacity(0.35))
                AxisValueLabel {
                    if let rate = value.as(Double.self) {
                        Text(rate.formatted(.percent.precision(.fractionLength(0))))
                    }
                }
                .foregroundStyle(TablePalette.faded)
            }
        }
    }
}
