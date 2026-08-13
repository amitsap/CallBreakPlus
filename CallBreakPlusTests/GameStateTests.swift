import Foundation
import Testing
@testable import CallBreakPlus

@Suite("Game State Machine")
struct GameStateTests {
    @Test func initialState() {
        let state = GameState()
        #expect(state.phase == .dealing)
        #expect(state.currentRoundNumber == 1)
        #expect(!state.isGameOver)
    }

    @Test func startRoundTransitionsToBidding() {
        var state = GameState()
        var rng = SeededRNG(seed: 42)
        state.startRound(using: &rng)
        let dealer = state.dealer
        #expect(state.phase == .bidding(nextBidder: dealer.next()))
        #expect(state.currentRound != nil)
        for seat in Seat.allCases {
            #expect(state.currentRound?.hands[seat]?.count == 13)
        }
    }

    @Test func startRoundCannotOverwriteAnActiveRound() {
        var state = GameState()
        var rng = SeededRNG(seed: 42)
        state.startRound(using: &rng)
        let originalHands = state.currentRound?.hands
        state.startRound(using: &rng)
        #expect(state.currentRound?.hands == originalHands)
        #expect(state.phase == .bidding(nextBidder: .right))
    }

    @Test func biddingFlowRotatesPlayers() {
        var state = GameState()
        var rng = SeededRNG(seed: 42)
        state.startRound(using: &rng)
        let firstBidder = state.dealer.next()
        var bidder = firstBidder
        for i in 0..<4 {
            #expect(state.phase == .bidding(nextBidder: bidder))
            state.placeBid(seat: bidder, bid: 3)
            bidder = bidder.next()
            if i < 3 {
                #expect(state.phase == .bidding(nextBidder: bidder))
            }
        }
        if case .playing = state.phase {
            // correct
        } else {
            Issue.record("Expected playing phase after all bids")
        }
    }

    @Test func invalidBidIsIgnored() {
        var state = GameState()
        var rng = SeededRNG(seed: 42)
        state.startRound(using: &rng)
        let firstBidder = state.dealer.next()
        state.placeBid(seat: firstBidder, bid: 0)
        #expect(state.currentRound?.bids.isEmpty == true)
        state.placeBid(seat: firstBidder, bid: 14)
        #expect(state.currentRound?.bids.isEmpty == true)
    }

    @Test func wrongSeatCantBid() {
        var state = GameState()
        var rng = SeededRNG(seed: 42)
        state.startRound(using: &rng)
        let firstBidder = state.dealer.next()
        let wrongSeat = firstBidder.next()
        state.placeBid(seat: wrongSeat, bid: 3)
        #expect(state.currentRound?.bids.isEmpty == true)
    }

    @Test func playCardRemovesFromHand() {
        var state = GameState()
        var rng = SeededRNG(seed: 42)
        state.startRound(using: &rng)
        let firstBidder = state.dealer.next()
        var bidder = firstBidder
        for _ in 0..<4 {
            state.placeBid(seat: bidder, bid: 3)
            bidder = bidder.next()
        }

        guard case .playing(_, let currentTurn) = state.phase else {
            Issue.record("Expected playing phase")
            return
        }

        let hand = state.currentRound!.hands[currentTurn]!
        let cardToPlay = hand[0]
        state.playCard(seat: currentTurn, card: cardToPlay)
        #expect(state.currentRound!.hands[currentTurn]!.count == 12)
    }

    @Test func completeTrickAdvancesState() {
        let state = playToTrickComplete(seed: 42)
        if case .trickComplete(let winner) = state.phase {
            #expect(Seat.allCases.contains(winner))
            let totalTricks = Seat.allCases.reduce(0) { $0 + state.currentRound!.tricksWon[$1]! }
            #expect(totalTricks == 1)
        } else if case .roundComplete = state.phase {
            // this could happen if we've played 13 tricks somehow (won't with 1 trick)
        } else {
            Issue.record("Expected trickComplete or roundComplete, got \(state.phase)")
        }
    }

    @Test @MainActor func humanBidContinuesRemainingBotBids() async throws {
        let hands = testHands()
        var state = GameState()
        state.roundStates = [
            RoundState(roundNumber: 1, dealer: .bottom, hands: hands)
        ]
        state.currentRound = RoundState(roundNumber: 2, dealer: .right, hands: hands)
        state.currentRound?.bids[.top] = 2
        state.currentRound?.bids[.left] = 2
        state.phase = .bidding(nextBidder: .bottom)

        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.gameState = state
        viewModel.placeBid(3)

        try await Task.sleep(for: .milliseconds(900))

        #expect(viewModel.currentRound?.bids[.bottom] == 3)
        #expect(viewModel.currentRound?.bids[.right] != nil)
        if case .playing = viewModel.phase {
            // correct
        } else {
            Issue.record("Expected play to start after the final bot bid, got \(viewModel.phase)")
        }
    }

    @Test @MainActor func pauseHaltsBotBiddingAndResumeContinues() async throws {
        var state = GameState()
        state.currentRound = RoundState(roundNumber: 1, dealer: .bottom, hands: testHands())
        state.phase = .bidding(nextBidder: .right)
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.gameState = state

        viewModel.resumeGame()
        try await Task.sleep(for: .milliseconds(150))
        viewModel.pauseGame()

        try await Task.sleep(for: .milliseconds(700))
        #expect(viewModel.currentRound?.bids.count == 0)

        viewModel.resumeGame()
        try await Task.sleep(for: .milliseconds(1500))
        #expect(viewModel.currentRound?.bids[.right] != nil)
        #expect(viewModel.currentRound?.bids[.top] != nil)
        #expect(viewModel.currentRound?.bids[.left] != nil)
        #expect(viewModel.phase == .bidding(nextBidder: .bottom))
        #expect(viewModel.showingBidSelector == true)
    }

    @Test @MainActor func pauseDuringDealSnapsToDealtState() {
        var state = GameState()
        state.currentRound = RoundState(roundNumber: 1, dealer: .bottom, hands: testHands())
        state.phase = .bidding(nextBidder: .right)
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.gameState = state
        viewModel.isDealing = true

        viewModel.pauseGame()

        #expect(viewModel.isDealing == false)
        #expect(viewModel.dealtCardCount == 52)
    }

    @Test @MainActor func difficultySnapshotsAtGameStartNotAtPickerChange() {
        let viewModel = GameViewModel(defaults: scratchDefaults())

        viewModel.botDifficulty = .beginner
        viewModel.startNewGame()
        viewModel.pauseGame()
        #expect(viewModel.activeDifficulty == .beginner)

        viewModel.botDifficulty = .advanced
        #expect(viewModel.activeDifficulty == .beginner)

        viewModel.startNewGame()
        viewModel.pauseGame()
        #expect(viewModel.activeDifficulty == .advanced)
    }

    @Test @MainActor func roundSummaryAutoAdvanceCanSuspendAndResume() async throws {
        let defaults = scratchDefaults()
        defaults.set(true, forKey: "settings.hasSeenRoundSummary")
        let viewModel = GameViewModel(defaults: defaults)
        viewModel.gameState = stateWithCompletedRound()
        viewModel.summaryAutoAdvanceInterval = 0.15

        viewModel.resumeGame()
        try await Task.sleep(for: .milliseconds(40))
        #expect(viewModel.showingRoundSummary)
        #expect(viewModel.summaryAutoAdvanceDeadline != nil)

        viewModel.suspendSummaryCountdown()
        viewModel.suspendSummaryCountdown()
        #expect(viewModel.summaryAutoAdvanceDeadline == nil)
        try await Task.sleep(for: .milliseconds(220))
        #expect(viewModel.showingRoundSummary)

        viewModel.resumeSummaryCountdown()
        try await Task.sleep(for: .milliseconds(220))
        #expect(!viewModel.showingRoundSummary)
        viewModel.pauseGame()
    }

    @Test @MainActor func roundSummaryFirstTimeAndAssistiveTechnologyDoNotAutoAdvance() async throws {
        let firstDefaults = scratchDefaults()
        firstDefaults.removeObject(forKey: "settings.hasSeenRoundSummary")
        let firstViewModel = GameViewModel(defaults: firstDefaults)
        firstViewModel.gameState = stateWithCompletedRound()
        firstViewModel.summaryAutoAdvanceInterval = 0.15
        firstViewModel.resumeGame()
        try await Task.sleep(for: .milliseconds(40))
        #expect(firstViewModel.showingRoundSummary)
        #expect(firstViewModel.summaryAutoAdvanceDeadline == nil)
        firstViewModel.acknowledgeRoundSummary()
        firstViewModel.pauseGame()

        let assistiveDefaults = scratchDefaults()
        assistiveDefaults.set(true, forKey: "settings.hasSeenRoundSummary")
        let assistiveViewModel = GameViewModel(defaults: assistiveDefaults)
        assistiveViewModel.isAssistiveTechRunning = { true }
        assistiveViewModel.gameState = stateWithCompletedRound()
        assistiveViewModel.resumeGame()
        try await Task.sleep(for: .milliseconds(40))
        #expect(assistiveViewModel.showingRoundSummary)
        #expect(assistiveViewModel.summaryAutoAdvanceDeadline == nil)
        assistiveViewModel.acknowledgeRoundSummary()
        assistiveViewModel.pauseGame()
    }

    @Test @MainActor func manualSummaryAcknowledgementCancelsTimerAndIsIdempotent() async throws {
        let defaults = scratchDefaults()
        defaults.set(true, forKey: "settings.hasSeenRoundSummary")
        let viewModel = GameViewModel(defaults: defaults)
        viewModel.gameState = stateWithCompletedRound()
        viewModel.summaryAutoAdvanceInterval = 0.15
        viewModel.resumeGame()
        try await Task.sleep(for: .milliseconds(40))

        viewModel.acknowledgeRoundSummary()
        viewModel.acknowledgeRoundSummary()
        #expect(viewModel.summaryAutoAdvanceDeadline == nil)
        try await Task.sleep(for: .milliseconds(220))
        #expect(!viewModel.showingRoundSummary)
        viewModel.pauseGame()
    }

    @Test @MainActor func lastTrickViewerStopsAndResumesBotFlow() async throws {
        var state = GameState()
        state.currentRound = RoundState(roundNumber: 1, dealer: .bottom, hands: testHands())
        state.phase = .bidding(nextBidder: .right)
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.gameState = state
        viewModel.lastTrickPlays = [TrickPlay(seat: .bottom, card: Card(suit: .clubs, rank: .two))]

        viewModel.resumeGame()
        viewModel.openLastTrick()
        try await Task.sleep(for: .milliseconds(450))
        #expect(viewModel.showingLastTrick)
        #expect(viewModel.currentRound?.bids.isEmpty == true)

        viewModel.closeLastTrick()
        try await Task.sleep(for: .milliseconds(450))
        #expect(viewModel.currentRound?.bids[.right] != nil)
        viewModel.pauseGame()
    }

    @Test @MainActor func lastTrickViewerRejectsDealingAndDuplicateClose() async throws {
        var state = GameState()
        state.currentRound = RoundState(roundNumber: 1, dealer: .bottom, hands: testHands())
        state.phase = .bidding(nextBidder: .bottom)
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.gameState = state
        viewModel.lastTrickPlays = [TrickPlay(seat: .bottom, card: Card(suit: .clubs, rank: .two))]
        viewModel.isDealing = true

        viewModel.openLastTrick()
        #expect(!viewModel.showingLastTrick)

        viewModel.isDealing = false
        viewModel.openLastTrick()
        viewModel.closeLastTrick()
        viewModel.closeLastTrick()
        try await Task.sleep(for: .milliseconds(50))
        #expect(viewModel.showingBidSelector)
        #expect(viewModel.currentRound?.bids.isEmpty == true)
        viewModel.pauseGame()
    }

    @Test @MainActor func lastTrickViewerRejectsEmptyHistoryAndGameOver() async throws {
        var biddingState = GameState()
        biddingState.currentRound = RoundState(roundNumber: 1, dealer: .bottom, hands: testHands())
        biddingState.phase = .bidding(nextBidder: .right)
        let emptyHistoryViewModel = GameViewModel(defaults: scratchDefaults())
        emptyHistoryViewModel.gameState = biddingState

        emptyHistoryViewModel.resumeGame()
        emptyHistoryViewModel.openLastTrick()
        try await Task.sleep(for: .milliseconds(900))
        #expect(!emptyHistoryViewModel.showingLastTrick)
        #expect(emptyHistoryViewModel.currentRound?.bids.isEmpty == false)
        emptyHistoryViewModel.pauseGame()

        var gameOverState = biddingState
        gameOverState.phase = .gameOver
        let gameOverViewModel = GameViewModel(defaults: scratchDefaults())
        gameOverViewModel.gameState = gameOverState
        gameOverViewModel.lastTrickPlays = [TrickPlay(seat: .bottom, card: Card(suit: .clubs, rank: .two))]

        gameOverViewModel.openLastTrick()
        #expect(!gameOverViewModel.showingLastTrick)
        #expect(gameOverViewModel.phase == .gameOver)
    }

    @Test @MainActor func duplicateLastTrickCloseKeepsHumanPlayingTurnStable() async throws {
        var state = GameState()
        state.currentRound = RoundState(roundNumber: 1, dealer: .bottom, hands: testHands())
        state.phase = .playing(leader: .bottom, currentTurn: .bottom)
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.gameState = state
        viewModel.lastTrickPlays = [TrickPlay(seat: .bottom, card: Card(suit: .clubs, rank: .two))]

        viewModel.openLastTrick()
        viewModel.closeLastTrick()
        viewModel.closeLastTrick()
        try await Task.sleep(for: .milliseconds(50))

        #expect(!viewModel.showingLastTrick)
        #expect(viewModel.phase == .playing(leader: .bottom, currentTurn: .bottom))
        #expect(viewModel.currentTrickPlays.isEmpty)
        viewModel.pauseGame()
    }

    @Test func roundOutcomeIsNextRoundForMidGameRound() {
        var state = stateWithCompletedRound()

        #expect(state.roundOutcome() == .nextRound)
        #expect(state.endRound() == .nextRound)
    }

    @Test func roundOutcomeIsGameOverForFinalRound() {
        var state = stateWithCompletedRound(priorRoundCount: 4)

        #expect(state.roundOutcome() == .gameOver)
        #expect(state.endRound() == .gameOver)
    }

    @Test func roundOutcomeIncludesInstantWinnerAndActualBid() {
        var state = stateWithCompletedRound(
            bids: [.bottom: 8, .right: 2, .top: 2, .left: 1],
            tricksWon: [.bottom: 8, .right: 2, .top: 2, .left: 1]
        )

        #expect(state.roundOutcome() == .instantWin(seat: .bottom, bid: 8))
        #expect(state.endRound() == .instantWin(seat: .bottom, bid: 8))
    }

    @Test @MainActor func instantWinPayloadUsesCompletedRoundBid() {
        var state = stateWithCompletedRound(
            bids: [.bottom: 8, .right: 2, .top: 2, .left: 1],
            tricksWon: [.bottom: 8, .right: 2, .top: 2, .left: 1]
        )
        state.endRound()
        let viewModel = GameViewModel(defaults: scratchDefaults())
        viewModel.gameState = state

        guard let instantWin = viewModel.instantWin else {
            Issue.record("Expected completed Thok round to provide a banner payload")
            return
        }
        #expect(instantWin.seat == .bottom)
        #expect(instantWin.bid == 8)
    }

    @Test func roundOutcomeIsInvalidOutsideRoundComplete() {
        var state = GameState()

        #expect(state.roundOutcome() == .invalid)
        #expect(state.endRound() == .invalid)
    }

    @Test func roundOutcomeMatchesEndRoundForEachFixture() {
        var midGame = stateWithCompletedRound()
        let midGameOutcome = midGame.roundOutcome()
        #expect(midGame.endRound() == midGameOutcome)

        var finalRound = stateWithCompletedRound(priorRoundCount: 4)
        let finalRoundOutcome = finalRound.roundOutcome()
        #expect(finalRound.endRound() == finalRoundOutcome)

        var instantWin = stateWithCompletedRound(
            bids: [.bottom: 8, .right: 2, .top: 2, .left: 1],
            tricksWon: [.bottom: 8, .right: 2, .top: 2, .left: 1]
        )
        let instantWinOutcome = instantWin.roundOutcome()
        #expect(instantWin.endRound() == instantWinOutcome)

        var invalid = GameState()
        let invalidOutcome = invalid.roundOutcome()
        #expect(invalid.endRound() == invalidOutcome)
    }

    @Test @MainActor func finalRoundRecordsStatsBeforePauseCanCancelGameFlow() async throws {
        let repository = RecordingStatsRepository()
        let viewModel = GameViewModel(statsRepository: repository, defaults: scratchDefaults())
        viewModel.gameState = stateWithCompletedRound(priorRoundCount: 4)

        viewModel.resumeGame()
        try await Task.sleep(for: .milliseconds(100))
        viewModel.pauseGame()

        #expect(repository.recordedGameCount == 1)

        try await Task.sleep(for: .milliseconds(600))
        #expect(viewModel.showingGameOver)
    }
}

@Suite("Full Game Integration")
struct FullGameIntegrationTests {
    @Test func completeGameBotVsBot() {
        var rng = SeededRNG(seed: 123)
        var state = GameState()

        for _ in 0..<5 {
            state.startRound(using: &rng)

            let firstBidder = state.dealer.next()
            var bidder = firstBidder
            for _ in 0..<4 {
                let hand = state.currentRound!.hands[bidder]!
                let bid = simpleBotBid(hand: hand)
                state.placeBid(seat: bidder, bid: bid)
                bidder = bidder.next()
            }

            for _ in 0..<13 {
                guard case .playing(_, var currentTurn) = state.phase else {
                    Issue.record("Expected playing phase")
                    return
                }

                for _ in 0..<4 {
                    let hand = state.currentRound!.hands[currentTurn]!
                    let legal = LegalMoves.legalCards(
                        for: hand, in: state.currentRound?.currentTrick, rules: state.rules
                    )
                    #expect(!legal.isEmpty, "Legal moves should never be empty during play")
                    let card = legal[0]
                    state.playCard(seat: currentTurn, card: card)
                    currentTurn = currentTurn.next()
                }

                if case .trickComplete = state.phase {
                    state.startNextTrick()
                } else if case .roundComplete = state.phase {
                    break
                }
            }

            #expect(state.phase == .roundComplete)

            let totalTricks = Seat.allCases.reduce(0) { $0 + state.currentRound!.tricksWon[$1]! }
            #expect(totalTricks == 13, "All 13 tricks should be accounted for")

            state.endRound()
        }

        #expect(state.isGameOver)
        #expect(state.roundStates.count == 5)

        for seat in Seat.allCases {
            let score = state.scoreTenths[seat]!
            #expect(score > -650 && score < 650, "Score \(score) tenths for \(seat) seems out of range")
        }
    }

    @Test func multipleGamesWithDifferentSeeds() {
        for seed: UInt64 in [1, 42, 100, 999, 12345] {
            var rng = SeededRNG(seed: seed)
            var state = GameState()

            for _ in 0..<5 {
                state.startRound(using: &rng)

                let firstBidder = state.dealer.next()
                var bidder = firstBidder
                for _ in 0..<4 {
                    let hand = state.currentRound!.hands[bidder]!
                    state.placeBid(seat: bidder, bid: simpleBotBid(hand: hand))
                    bidder = bidder.next()
                }

                playFullRound(&state)
                state.endRound()
            }

            #expect(state.isGameOver, "Game with seed \(seed) should complete")
        }
    }

    @Test func dealerRotatesEachRound() {
        var rng = SeededRNG(seed: 42)
        var state = GameState()

        var dealers: [Seat] = []
        for _ in 0..<4 {
            dealers.append(state.dealer)
            state.startRound(using: &rng)
            let firstBidder = state.dealer.next()
            var bidder = firstBidder
            for _ in 0..<4 {
                let hand = state.currentRound!.hands[bidder]!
                state.placeBid(seat: bidder, bid: simpleBotBid(hand: hand))
                bidder = bidder.next()
            }
            playFullRound(&state)
            state.endRound()
        }

        #expect(dealers[0] == .bottom)
        #expect(dealers[1] == .right)
        #expect(dealers[2] == .top)
        #expect(dealers[3] == .left)
    }
}

// MARK: - Test Helpers

func simpleBotBid(hand: [Card]) -> Int {
    var bid = 0
    for card in hand {
        if card.suit == .spades && card.rank >= .queen { bid += 1 }
        else if card.rank == .ace { bid += 1 }
    }
    return max(1, min(bid, 13))
}

func playFullRound(_ state: inout GameState) {
    for _ in 0..<13 {
        guard case .playing(_, var currentTurn) = state.phase else { return }
        for _ in 0..<4 {
            let hand = state.currentRound!.hands[currentTurn]!
            let legal = LegalMoves.legalCards(
                for: hand, in: state.currentRound?.currentTrick, rules: state.rules
            )
            state.playCard(seat: currentTurn, card: legal[0])
            currentTurn = currentTurn.next()
        }
        if case .trickComplete = state.phase {
            state.startNextTrick()
        }
    }
}

func playToTrickComplete(seed: UInt64) -> GameState {
    var rng = SeededRNG(seed: seed)
    var state = GameState()
    state.startRound(using: &rng)

    let firstBidder = state.dealer.next()
    var bidder = firstBidder
    for _ in 0..<4 {
        state.placeBid(seat: bidder, bid: 3)
        bidder = bidder.next()
    }

    guard case .playing(_, var currentTurn) = state.phase else { return state }
    for _ in 0..<4 {
        let hand = state.currentRound!.hands[currentTurn]!
        let legal = LegalMoves.legalCards(
            for: hand, in: state.currentRound?.currentTrick, rules: state.rules
        )
        state.playCard(seat: currentTurn, card: legal[0])
        currentTurn = currentTurn.next()
    }
    return state
}

func testHands() -> [Seat: [Card]] {
    var hands: [Seat: [Card]] = [:]
    for (index, seat) in Seat.allCases.enumerated() {
        let start = index * 13
        hands[seat] = Array(Deck.fullDeck[start..<(start + 13)]).sorted()
    }
    return hands
}

func stateWithCompletedRound(
    priorRoundCount: Int = 0,
    bids: [Seat: Int] = [.bottom: 3, .right: 2, .top: 2, .left: 1],
    tricksWon: [Seat: Int] = [.bottom: 3, .right: 2, .top: 2, .left: 6]
) -> GameState {
    let hands = testHands()
    let completedTrick = Trick(firstPlay: TrickPlay(seat: .bottom, card: Card(suit: .clubs, rank: .two)))
    var round = RoundState(roundNumber: priorRoundCount + 1, dealer: .bottom, hands: hands)
    round.bids = bids
    round.tricksWon = tricksWon
    round.completedTricks = Array(repeating: completedTrick, count: 13)

    var state = GameState()
    state.roundStates = (0..<priorRoundCount).map {
        RoundState(roundNumber: $0 + 1, dealer: .bottom, hands: hands)
    }
    state.currentRound = round
    state.phase = .roundComplete
    return state
}

@MainActor
final class RecordingStatsRepository: StatsRepository, @unchecked Sendable {
    private(set) var recordedGameCount = 0

    func recordGameResult(_ result: GameResult) async throws {
        recordedGameCount += 1
    }

    func fetchStats() async throws -> PlayerStats { PlayerStats() }

    func fetchRecentGames(limit: Int) async throws -> [GameSummary] { [] }

    func resetStats() async throws {}
}

/// A scratch `UserDefaults` suite, wiped before use so it never inherits a prior run's
/// writes (the simulator persists suite plists across runs). Caller supplies the name so
/// concurrent tests never share one suite.
func scratchDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let suiteName = "GameViewModelTests.\(name)"
    UserDefaults().removePersistentDomain(forName: suiteName)
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.set(true, forKey: "settings.hasSeenRoundSummary")
    return defaults
}
