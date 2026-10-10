import SwiftUI

struct MainMenuView: View {
    @Bindable var viewModel: GameViewModel
    /// Bumped by the parent when the stats may have changed (a panel closed), so the menu refetches.
    let statsVersion: Int
    let onNewGame: () -> Void
    let onHowToPlay: () -> Void
    let onSettings: () -> Void
    let onStats: () -> Void

    @State private var stats: MenuStats = .loading
    @AppStorage("onboarding.hasSeenRules") private var hasSeenRules = false

    enum MenuStats {
        case loading, unavailable
        case loaded(PlayerStats)
    }

    var body: some View {
        ZStack {
            TableBackground()
                .ignoresSafeArea()

            HStack(spacing: 20) {
                VStack(spacing: 18) {
                    titleSection
                    MenuFan()
                    HStack(spacing: 8) {
                        howToPlayButton
                        secondaryButton("Stats", icon: "trophy.fill", action: onStats)
                        secondaryButton("Settings", icon: "gearshape.fill", action: onSettings)
                    }
                }
                .frame(maxWidth: .infinity)

                newGameCard
                    .frame(width: 256)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .task(id: statsVersion) { await loadStats() }
        .onAppear {
            guard !hasSeenRules else { return }
            hasSeenRules = true
            onHowToPlay()
        }
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Text("Call").foregroundStyle(.white)
                Text("Break").foregroundStyle(TablePalette.gold)
                Text("+").foregroundStyle(.white.opacity(0.6))
            }
            .font(.system(size: 40, weight: .black, design: .rounded))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Call Break Plus")
            .accessibilityAddTraits(.isHeader)

            Text("Call your hands. Break theirs.")
                .font(TableType.body)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    // MARK: - New game

    private var newGameCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("New game")
                    .font(TableType.kicker)
                    .textCase(.uppercase)
                    .kerning(1)
                    .foregroundStyle(TablePalette.faded)
                Text("Pick your table")
                    .font(TableType.title)
                    .foregroundStyle(TablePalette.ink)
                    .accessibilityAddTraits(.isHeader)
            }

            Picker("Difficulty", selection: $viewModel.botDifficulty) {
                ForEach(BotDifficulty.allCases, id: \.self) { difficulty in
                    Text(difficulty.title).tag(difficulty)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.botDifficulty.summary)
                    .font(TableType.caption)
                    .foregroundStyle(TablePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let record = recordLine {
                    Text(record)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(TablePalette.faded)
                }
            }
            .frame(minHeight: 46, alignment: .top)

            OverlayButton("Deal", action: onNewGame)

            statsStrip
        }
        .padding(16)
        .background(TablePalette.paper, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(TablePalette.rimBrown.opacity(0.5), lineWidth: 1.5))
        .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
    }

    private var recordLine: String? {
        guard case .loaded(let stats) = stats else { return nil }
        let difficulty = viewModel.botDifficulty
        let record = stats.record(at: difficulty)
        guard record.games > 0 else { return "You haven’t played \(difficulty.title) yet." }
        return "You’ve won \(record.wins) of \(record.games) at \(difficulty.title)."
    }

    @ViewBuilder
    private var statsStrip: some View {
        switch stats {
        case .loaded(let stats) where stats.gamesPlayed > 0:
            VStack(spacing: 8) {
                Rectangle().fill(TablePalette.cardRuled.opacity(0.5)).frame(height: 1)
                HStack(spacing: 0) {
                    stripItem("\(stats.gamesPlayed)", label: "played")
                    stripItem(stats.winRate.formatted(.percent.precision(.fractionLength(0))), label: "won")
                    stripItem("\(stats.longestWinStreak)", label: "best streak")
                }
            }
        case .loaded:
            Text("Finish a game to start your record.")
                .font(TableType.caption)
                .foregroundStyle(TablePalette.faded)
                .frame(maxWidth: .infinity)
        case .loading, .unavailable:
            EmptyView()
        }
    }

    private func stripItem(_ value: String, label: String) -> some View {
        VStack(spacing: 0) {
            Text(value)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(TablePalette.ink)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(TablePalette.faded)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Secondary buttons

    private var howToPlayButton: some View {
        Button(action: onHowToPlay) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                VStack(alignment: .leading, spacing: 0) {
                    Text("How to play")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("EN · नेपाली · हिंदी")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .modifier(MenuCapsule())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("How to play")
        .accessibilityHint("In English, Nepali and Hindi")
        .accessibilityAddTraits(.isButton)
    }

    private func secondaryButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .modifier(MenuCapsule())
        }
        .buttonStyle(.plain)
    }

    private func loadStats() async {
        guard let repo = viewModel.statsRepository else {
            stats = .unavailable
            return
        }
        do {
            stats = .loaded(try await repo.fetchStats())
        } catch {
            stats = .unavailable
        }
    }
}

private struct MenuCapsule: ViewModifier {
    func body(content: Content) -> some View {
        content
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(.black.opacity(0.30), in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
            .contentShape(Capsule())
    }
}

/// A fanned hand of real cards under the logo.
private struct MenuFan: View {
    private let cards: [Card] = [
        Card(suit: .spades, rank: .ten),
        Card(suit: .hearts, rank: .jack),
        Card(suit: .clubs, rank: .queen),
        Card(suit: .diamonds, rank: .king),
        Card(suit: .spades, rank: .ace),
    ]

    var body: some View {
        ZStack {
            ForEach(cards.indices, id: \.self) { index in
                let offset = Double(index) - Double(cards.count - 1) / 2
                CardView(card: cards[index])
                    .scaleEffect(0.82)
                    .rotationEffect(.degrees(offset * 9), anchor: .bottom)
                    .offset(x: offset * 30, y: abs(offset) * 4)
            }
        }
        .frame(width: 230, height: 96)
        .accessibilityHidden(true)
    }
}

extension BotDifficulty {
    var title: String {
        switch self {
        case .beginner: "Easy"
        case .intermediate: "Medium"
        case .advanced: "Hard"
        }
    }

    /// One line on how the bots play at this level.
    var summary: String {
        switch self {
        case .beginner: "Bots take a trick when they can and never plan ahead."
        case .intermediate: "Bots track broken suits and duck once they’ve made their call."
        case .advanced: "Bots count cards and stop you one trick short of your call."
        }
    }
}

extension PlayerStats {
    func record(at difficulty: BotDifficulty) -> (wins: Int, games: Int) {
        switch difficulty {
        case .beginner: (beginnerWins, beginnerGames)
        case .intermediate: (intermediateWins, intermediateGames)
        case .advanced: (advancedWins, advancedGames)
        }
    }
}
