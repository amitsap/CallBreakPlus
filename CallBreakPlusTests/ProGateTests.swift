import Testing
@testable import CallBreakPlus

@Suite("Pro Gate")
struct ProGateTests {
    @Test func proPassesVariantsThrough() {
        let rules = ProGate.rules(base: .standard, roundCount: 10, thokThreshold: 11, hasPro: true)
        #expect(rules.roundCount == 10)
        #expect(rules.instantWinBid == 11)
    }

    @Test func freeForcesDefaultLengthAndThreshold() {
        let rules = ProGate.rules(base: .standard, roundCount: 3, thokThreshold: 13, hasPro: false)
        #expect(rules.roundCount == 5)
        #expect(rules.instantWinBid == 8)
    }

    @Test(arguments: [false, true])
    func thokOffStaysOffWithOrWithoutPro(hasPro: Bool) {
        let rules = ProGate.rules(base: .standard, roundCount: 5, thokThreshold: nil, hasPro: hasPro)
        #expect(rules.instantWinBid == nil)
    }

    @Test func baseRulesSurviveTheGate() {
        var base = RuleSet.standard
        base.canDiscardWhenCantOvertrump = false
        base.redealOnWeakHand = false
        let rules = ProGate.rules(base: base, roundCount: 10, thokThreshold: 9, hasPro: false)
        #expect(!rules.canDiscardWhenCantOvertrump)
        #expect(!rules.redealOnWeakHand)
        #expect(rules.mustGoHigher)
        #expect(rules.mustTrump)
    }

    @Test @MainActor func newGameWithoutProUsesTodaysRules() {
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.hasPro = { false }

        viewModel.startNewGame()
        viewModel.pauseGame()
        #expect(viewModel.gameState.rules.roundCount == 5)
        #expect(viewModel.gameState.rules.instantWinBid == 8)

        viewModel.instantWinEnabled = false
        viewModel.startNewGame()
        viewModel.pauseGame()
        #expect(viewModel.gameState.rules.instantWinBid == nil)
    }

    /// The variants default to the free values, so a paying player's games don't change
    /// until they choose a variant.
    @Test @MainActor func newGameWithProUsesTodaysRules() {
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.hasPro = { true }

        viewModel.startNewGame()
        viewModel.pauseGame()
        #expect(viewModel.gameState.rules.roundCount == 5)
        #expect(viewModel.gameState.rules.instantWinBid == 8)
    }

    @Test @MainActor func newGameWithProUsesTheChosenVariants() {
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.hasPro = { true }
        viewModel.roundCount = 10
        viewModel.thokThreshold = 11

        viewModel.startNewGame()
        viewModel.pauseGame()
        #expect(viewModel.gameState.rules.roundCount == 10)
        #expect(viewModel.gameState.rules.instantWinBid == 11)
        #expect(viewModel.effectiveRoundCount == 10)
        #expect(viewModel.effectiveThokThreshold == 11)
    }

    /// A refund falls back to the free rules without rewriting the choice, so buying
    /// again restores it.
    @Test @MainActor func newGameWithoutProKeepsTheChoiceButPlaysFreeRules() {
        let defaults = scratchDefaults()
        let viewModel = GameViewModel(defaults: defaults)
        viewModel.hasPro = { true }
        viewModel.roundCount = 3
        viewModel.thokThreshold = 13
        viewModel.hasPro = { false }

        viewModel.startNewGame()
        viewModel.pauseGame()
        #expect(viewModel.gameState.rules.roundCount == 5)
        #expect(viewModel.gameState.rules.instantWinBid == 8)
        #expect(viewModel.effectiveRoundCount == 5)
        #expect(viewModel.effectiveThokThreshold == 8)
        #expect(viewModel.roundCount == 3)
        #expect(viewModel.thokThreshold == 13)
        #expect(GameViewModel(defaults: defaults).roundCount == 3)
    }

    @Test @MainActor func variantsPersist() {
        let defaults = scratchDefaults()
        let viewModel = GameViewModel(defaults: defaults)
        viewModel.roundCount = 10
        viewModel.thokThreshold = 9

        let reloaded = GameViewModel(defaults: defaults)
        #expect(reloaded.roundCount == 10)
        #expect(reloaded.thokThreshold == 9)
    }

    @Test @MainActor func unknownStoredVariantsLoadAsDefaults() {
        let defaults = scratchDefaults()
        defaults.set(7, forKey: "settings.roundCount")
        defaults.set(14, forKey: "settings.thokThreshold")

        let viewModel = GameViewModel(defaults: defaults)
        #expect(viewModel.roundCount == 5)
        #expect(viewModel.thokThreshold == 8)
    }

    @Test(arguments: CardBack.allCases)
    func proKeepsEveryBack(back: CardBack) {
        #expect(ProGate.cardBack(selected: back, hasPro: true) == back)
    }

    @Test(arguments: CardBack.allCases)
    func freeShowsOnlyFreeBacks(back: CardBack) {
        #expect(ProGate.cardBack(selected: back, hasPro: false) == (back.isPro ? .blue : back))
    }

    /// Stored values from before Pro must keep meaning what they meant.
    @Test func storedBackValuesSurvive() {
        #expect(CardBack(stored: 0) == .blue)
        #expect(CardBack(stored: 1) == .red)
        #expect(CardBack(stored: 99) == .blue)
        #expect(CardBack(stored: -1) == .blue)
        #expect(CardBack.allCases.filter { !$0.isPro } == [.blue, .red])
    }

    /// A refund shows Blue but keeps the stored choice, so buying again restores it.
    @Test @MainActor func refundFallsBackWithoutForgettingTheChoice() {
        let defaults = scratchDefaults()
        var hasPro = true
        let viewModel = GameViewModel(defaults: defaults)
        viewModel.hasPro = { hasPro }
        viewModel.cardBack = .mandala
        #expect(viewModel.effectiveCardBack == .mandala)

        hasPro = false
        #expect(viewModel.effectiveCardBack == .blue)
        #expect(viewModel.cardBack == .mandala)

        let reloaded = GameViewModel(defaults: defaults)
        reloaded.hasPro = { true }
        #expect(reloaded.effectiveCardBack == .mandala)
    }

    @Test @MainActor func storedRedBackLoads() {
        let defaults = scratchDefaults()
        defaults.set(1, forKey: "settings.cardBack")
        let viewModel = GameViewModel(defaults: defaults)
        #expect(viewModel.cardBack == .red)
        #expect(viewModel.effectiveCardBack == .red)
    }
}
