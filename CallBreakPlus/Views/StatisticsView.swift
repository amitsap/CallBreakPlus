import SwiftUI

struct StatisticsView: View {
    let viewModel: GameViewModel
    /// Offered on the first-run state when a new game can start from here (the menu, not Pause).
    let onDealGame: (() -> Void)?
    @State private var model: StatisticsModel
    @State private var showingResetConfirmation = false
    @State private var showingInsights = false
    @State private var insightsDifficulty: BotDifficulty?
    @Environment(ProStore.self) private var proStore
    @Environment(\.openProPanel) private var openProPanel

    init(viewModel: GameViewModel, onDealGame: (() -> Void)?) {
        self.viewModel = viewModel
        self.onDealGame = onDealGame
        _model = State(initialValue: StatisticsModel(repository: viewModel.statsRepository))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task { await model.load() }
        .onChange(of: proStore.hasPro) { _, hasPro in
            // A refund closes Insights; the page behind it shows the locked card.
            if !hasPro { showingInsights = false }
        }
        .alert("Reset Statistics?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                Task { await model.reset() }
            }
        } message: {
            Text("All game records will be permanently deleted.")
        }
        .alert("Statistics could not be reset", isPresented: $model.resetFailed) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your records are unchanged. Please try again.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .loading:
            VStack(spacing: 10) {
                ProgressView()
                    .tint(TablePalette.faded)
                Text("Loading your games…")
                    .font(TableType.body)
                    .foregroundStyle(TablePalette.faded)
            }
        case .empty:
            emptyState
        case .failed:
            failedState
        case .loaded(let stats, let history):
            if showingInsights {
                InsightsPage(history: history, difficulty: $insightsDifficulty, scoreText: viewModel.scoreString)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
            } else {
                loadedState(stats, history: history)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 2) {
            if showingInsights {
                Button {
                    showingInsights = false
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(TablePalette.ink)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Statistics")
                .padding(.leading, -12)
            }
            Text(showingInsights ? "Insights" : "Statistics")
                .font(TableType.title)
                .foregroundStyle(TablePalette.ink)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(minHeight: 44)
        .padding(.top, 6)
        .padding(.horizontal, 20)
    }

    // MARK: - First run and failure

    private var emptyState: some View {
        VStack(spacing: 8) {
            ZStack {
                ForEach(0..<3, id: \.self) { index in
                    let offset = Double(index - 1)
                    CardView(card: Card(suit: .spades, rank: .ace), isFaceUp: false, cardBack: viewModel.effectiveCardBack)
                        .scaleEffect(0.6)
                        .rotationEffect(.degrees(offset * 10), anchor: .bottom)
                        .offset(x: offset * 18)
                }
            }
            .frame(height: 64)
            .accessibilityHidden(true)

            Text("No games yet")
                .font(TableType.title)
                .foregroundStyle(TablePalette.ink)
            Text("Finish a game and your win rate, calls made and streaks show up here.")
                .font(TableType.body)
                .foregroundStyle(TablePalette.faded)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            if let onDealGame {
                OverlayButton("Deal a game", action: onDealGame)
                    .frame(width: 200)
                    .padding(.top, 6)
            }
            unavailableNotice
        }
        .padding(.horizontal, 20)
    }

    private var failedState: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(TablePalette.thokOrange)
                .accessibilityHidden(true)
            Text("Statistics couldn’t be loaded")
                .font(TableType.title)
                .foregroundStyle(TablePalette.ink)
            Text("Something went wrong reading your games. Try again.")
                .font(TableType.body)
                .foregroundStyle(TablePalette.faded)
                .multilineTextAlignment(.center)
            OverlayButton("Retry") {
                Task { await model.load() }
            }
            .frame(width: 200)
            .padding(.top, 6)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Loaded

    private func loadedState(_ stats: PlayerStats, history: [GameSummary]) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    tile("Played", value: "\(stats.gamesPlayed)", detail: "\(stats.gamesWon) won")
                    tile("Win rate", value: percent(stats.winRate), detail: nil)
                    tile("Calls made", value: percent(stats.bidAccuracy), detail: "\(stats.bidsMet) of \(stats.totalBids)")
                    tile("Best streak", value: "\(stats.longestWinStreak)", detail: "now \(stats.currentWinStreak)")
                }

                HStack(alignment: .top, spacing: 24) {
                    InsightsCard(history: history, hasPro: proStore.hasPro, onOpen: { showingInsights = true }, onUnlock: { openProPanel?() })
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        columnHeading("By difficulty")
                        ForEach(BotDifficulty.allCases, id: \.self) { difficulty in
                            difficultyRow(difficulty, record: stats.record(at: difficulty))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 8) {
                        columnHeading("Recent")
                        ForEach(history.prefix(3)) { game in
                            GameRow(won: game.won, date: game.date, detail: GameRow.detail(game.difficulty, roundCount: game.roundCount), score: viewModel.scoreString(game.totalScore))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .center) {
                    unavailableNotice
                    Spacer(minLength: 12)
                    Button("Reset statistics…") { showingResetConfirmation = true }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(TablePalette.destructiveRed)
                        .frame(minHeight: 44)
                        .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
    }

    @ViewBuilder
    private var unavailableNotice: some View {
        if viewModel.statsUnavailable {
            Text("Stats can’t be saved on this device right now. This session’s numbers are temporary.")
                .font(TableType.caption)
                .foregroundStyle(TablePalette.faded)
        }
    }

    private func tile(_ label: String, value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundStyle(TablePalette.faded)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(TablePalette.ink)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(TablePalette.faded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private func columnHeading(_ title: String) -> some View {
        Text(title)
            .font(TableType.headline)
            .foregroundStyle(TablePalette.ink)
            .accessibilityAddTraits(.isHeader)
    }

    private func difficultyRow(_ difficulty: BotDifficulty, record: (wins: Int, games: Int)) -> some View {
        let rate = record.games > 0 ? Double(record.wins) / Double(record.games) : 0
        return HStack(spacing: 8) {
            Text(difficulty.title)
                .font(TableType.body)
                .foregroundStyle(TablePalette.ink)
                .frame(width: 58, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(TablePalette.cardRuled.opacity(0.35))
                    Capsule()
                        .fill(TablePalette.accentGreen)
                        .frame(width: geo.size.width * rate)
                }
            }
            .frame(height: 8)
            Text(record.games > 0 ? "\(record.wins) of \(record.games)" : "Not played")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(record.games > 0 ? TablePalette.ink : TablePalette.faded)
                .frame(width: 70, alignment: .trailing)
        }
        .frame(minHeight: 22)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(record.games > 0
            ? "\(difficulty.title): won \(record.wins) of \(record.games)"
            : "\(difficulty.title): not played")
    }

    private func percent(_ value: Double) -> String {
        value.formatted(.percent.precision(.fractionLength(0)))
    }
}
