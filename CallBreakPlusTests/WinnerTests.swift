import Testing
@testable import CallBreakPlus

@Suite("Winner Resolution")
struct WinnerTests {
    @Test @MainActor func equalTopScoresCreateCoWinners() {
        var state = GameState()
        state.scoreTenths = [.bottom: 31, .right: 31, .top: 20, .left: -10]
        state.phase = .gameOver

        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.gameState = state

        #expect(viewModel.winners == [.bottom, .right])
        #expect(viewModel.winner() == nil)
    }

    @Test @MainActor func instantWinHasOnlyOneWinner() {
        var state = GameState()
        state.scoreTenths = [.bottom: 40, .right: 80, .top: 80, .left: 10]
        state.instantWinner = .bottom
        state.phase = .gameOver

        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.gameState = state
        #expect(viewModel.winners == [.bottom])
    }
}
