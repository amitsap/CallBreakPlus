import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var viewModel: GameViewModel
    @State private var showingGame = false
    @State private var showingStats = false

    init(modelContainer: ModelContainer, statsUnavailable: Bool = false) {
        let repo = SwiftDataStatsRepository(modelContainer: modelContainer)
        _viewModel = State(initialValue: GameViewModel(statsRepository: repo, statsUnavailable: statsUnavailable))
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
                    onNewGame: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingGame = true
                        }
                        viewModel.startNewGame()
                    },
                    onSettings: {
                        viewModel.showingSettings = true
                    },
                    onStats: {
                        showingStats = true
                    }
                )
                .statusBarHidden()
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $viewModel.showingSettings) {
            SettingsView(viewModel: viewModel)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(false)
        }
        .sheet(isPresented: $showingStats) {
            StatisticsView(statsRepository: viewModel.statsRepository, statsUnavailable: viewModel.statsUnavailable)
                .presentationDetents([.medium])
                .interactiveDismissDisabled(false)
        }
    }
}
