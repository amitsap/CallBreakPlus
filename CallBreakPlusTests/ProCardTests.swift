import Testing
@testable import CallBreakPlus

@Suite("Pro Card")
struct ProCardTests {
    @Test @MainActor func showsFromTheTenthGame() {
        let defaults = scratchDefaults()
        #expect(!GameViewModel(defaults: defaults).shouldShowProCard(gamesPlayed: 9))
        #expect(GameViewModel(defaults: defaults).shouldShowProCard(gamesPlayed: 10))
    }

    @Test @MainActor func showsToAPlayerAlreadyPastTenGames() {
        #expect(GameViewModel(defaults: scratchDefaults()).shouldShowProCard(gamesPlayed: 140))
    }

    @Test @MainActor func showsOnceEver() {
        let defaults = scratchDefaults()
        let viewModel = GameViewModel(defaults: defaults)
        #expect(viewModel.shouldShowProCard(gamesPlayed: 10))
        #expect(!viewModel.shouldShowProCard(gamesPlayed: 11))
        #expect(!GameViewModel(defaults: defaults).shouldShowProCard(gamesPlayed: 12))
    }

    @Test @MainActor func neverShowsToProOwners() {
        let defaults = scratchDefaults()
        let viewModel = GameViewModel(defaults: defaults)
        viewModel.hasPro = { true }
        #expect(!viewModel.shouldShowProCard(gamesPlayed: 10))
        // Declining it as an owner doesn't spend it: a refund later still gets the card.
        #expect(GameViewModel(defaults: defaults).shouldShowProCard(gamesPlayed: 11))
    }

    @Test @MainActor func neverInARatingSession() {
        let defaults = scratchDefaults()
        let viewModel = GameViewModel(defaults: defaults)
        for _ in 1...3 { _ = viewModel.shouldRequestReview(afterWin: true) }
        #expect(viewModel.reviewRequestedThisSession)
        #expect(!viewModel.shouldShowProCard(gamesPlayed: 10))
        // The next session still gets it.
        #expect(GameViewModel(defaults: defaults).shouldShowProCard(gamesPlayed: 11))
    }

    @Test @MainActor func suppressesTheRatingPromptAfterIt() {
        let viewModel = GameViewModel(defaults: scratchDefaults())
        #expect(viewModel.shouldShowProCard(gamesPlayed: 10))
        let requestedAt = (1...20).filter { _ in viewModel.shouldRequestReview(afterWin: true) }
        #expect(requestedAt.isEmpty)
    }

    @Test @MainActor func savingPreferencesLeavesTheFlagAlone() {
        let defaults = scratchDefaults()
        let viewModel = GameViewModel(defaults: defaults)
        #expect(viewModel.shouldShowProCard(gamesPlayed: 10))
        viewModel.fastPlayEnabled.toggle()
        #expect(!GameViewModel(defaults: defaults).shouldShowProCard(gamesPlayed: 11))
    }

    @Test @MainActor func tenthGameOverShowsTheCardAndANewGameClearsIt() async throws {
        let repository = RecordingStatsRepository()
        repository.priorGames = 9
        let viewModel = GameViewModel(statsRepository: repository, defaults: scratchDefaults())
        viewModel.gameState = stateWithCompletedRound(priorRoundCount: 4)

        viewModel.resumeGame()
        try await Task.sleep(for: .milliseconds(700))
        #expect(viewModel.showingGameOver)
        #expect(viewModel.showingProCard)
        #expect(!viewModel.reviewDueAtGameOver)

        viewModel.startNewGame()
        #expect(!viewModel.showingProCard)
        viewModel.stopGame()
    }

    @Test @MainActor func aGameOverDueBothRequestsTheRatingAndDefersTheCard() async throws {
        let defaults = scratchDefaults()
        let earlierSession = GameViewModel(defaults: defaults)
        for _ in 1...2 { _ = earlierSession.shouldRequestReview(afterWin: true) }
        let repository = RecordingStatsRepository()
        repository.priorGames = 9
        let viewModel = GameViewModel(statsRepository: repository, defaults: defaults)
        viewModel.gameState = stateWithCompletedRound(priorRoundCount: 4)

        viewModel.resumeGame()
        try await Task.sleep(for: .milliseconds(700))
        #expect(viewModel.showingGameOver)
        #expect(viewModel.reviewDueAtGameOver)
        #expect(!viewModel.showingProCard)
        viewModel.stopGame()
        // The card isn't spent: the next session gets it.
        #expect(GameViewModel(defaults: defaults).shouldShowProCard(gamesPlayed: 11))
    }

    @Test @MainActor func ninthGameOverShowsNoCard() async throws {
        let repository = RecordingStatsRepository()
        repository.priorGames = 8
        let viewModel = GameViewModel(statsRepository: repository, defaults: scratchDefaults())
        viewModel.gameState = stateWithCompletedRound(priorRoundCount: 4)

        viewModel.resumeGame()
        try await Task.sleep(for: .milliseconds(700))
        #expect(viewModel.showingGameOver)
        #expect(!viewModel.showingProCard)
        viewModel.stopGame()
    }
}
