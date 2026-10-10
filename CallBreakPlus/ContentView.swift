import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var viewModel: GameViewModel
    @State private var showingGame = false
    @State private var menuPanel: PanelKind?
    @State private var statsVersion = 0

    init(modelContainer: ModelContainer, statsUnavailable: Bool = false, proStore: ProStore) {
        let repo = SwiftDataStatsRepository(modelContainer: modelContainer)
        let viewModel = GameViewModel(statsRepository: repo, statsUnavailable: statsUnavailable)
        viewModel.hasPro = { proStore.hasPro }
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        ZStack {
            if showingGame {
                GameTableView(
                    viewModel: viewModel,
                    onQuit: {
                        viewModel.stopGame()
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showingGame = false
                        }
                    }
                )
                .statusBarHidden()
                .transition(.opacity)
            } else {
                MainMenuView(
                    viewModel: viewModel,
                    statsVersion: statsVersion,
                    onNewGame: startGame,
                    onHowToPlay: { openMenuPanel(.howToPlay) },
                    onSettings: { openMenuPanel(.settings) },
                    onStats: { openMenuPanel(.statistics) }
                )
                .statusBarHidden()
                .transition(.opacity)
            }

            if let panel = menuPanel, !showingGame {
                PanelScreen(kind: panel, viewModel: viewModel, gameInProgress: false, onDealGame: startGame, onClose: closeMenuPanel)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(30)
            }
        }
        .environment(\.tableTheme, viewModel.effectiveTableTheme.theme)
    }

    private func openMenuPanel(_ panel: PanelKind) {
        withAnimation(.spring(duration: 0.25)) { menuPanel = panel }
    }

    private func closeMenuPanel() {
        withAnimation(.spring(duration: 0.25)) { menuPanel = nil }
        statsVersion += 1
    }

    private func startGame() {
        menuPanel = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            showingGame = true
        }
        viewModel.startNewGame()
    }
}
