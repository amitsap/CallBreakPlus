import Testing
@testable import CallBreakPlus

@Suite("Rating Prompt")
struct RatingPromptTests {
    @Test @MainActor func requestsOnlyOnThirdAndFifteenthWins() {
        let viewModel = GameViewModel(defaults: scratchDefaults())
        let requestedAt = (1...20).filter { _ in viewModel.shouldRequestReview(afterWin: true) }
        #expect(requestedAt == [3, 15])
    }

    @Test @MainActor func lossesNeverRequestOrCount() {
        let viewModel = GameViewModel(defaults: scratchDefaults())
        #expect(!viewModel.shouldRequestReview(afterWin: true))
        #expect(!viewModel.shouldRequestReview(afterWin: true))
        for _ in 1...5 { #expect(!viewModel.shouldRequestReview(afterWin: false)) }
        #expect(viewModel.shouldRequestReview(afterWin: true))
    }

    @Test @MainActor func winCountPersistsAcrossViewModels() {
        let defaults = scratchDefaults()
        let first = GameViewModel(defaults: defaults)
        _ = first.shouldRequestReview(afterWin: true)
        _ = first.shouldRequestReview(afterWin: true)
        let second = GameViewModel(defaults: defaults)
        #expect(second.shouldRequestReview(afterWin: true))
    }

    @Test @MainActor func proCardThisSessionSuppressesPrompt() {
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.proCardShownThisSession = true
        let requestedAt = (1...20).filter { _ in viewModel.shouldRequestReview(afterWin: true) }
        #expect(requestedAt.isEmpty)
    }

    @Test @MainActor func savingPreferencesLeavesWinCountAlone() {
        let defaults = scratchDefaults()
        let viewModel = GameViewModel(defaults: defaults)
        _ = viewModel.shouldRequestReview(afterWin: true)
        _ = viewModel.shouldRequestReview(afterWin: true)
        viewModel.fastPlayEnabled.toggle()
        #expect(GameViewModel(defaults: defaults).shouldRequestReview(afterWin: true))
    }
}
