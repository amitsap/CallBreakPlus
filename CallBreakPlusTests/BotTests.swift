import Testing
@testable import CallBreakPlus

@Suite("Bot Strategy Tests")
struct BotStrategyTests {
    @Test func beginnerBidsAtLeastOne() {
        let bot = BeginnerBot()
        let weakHand = [
            card(.two, .clubs), card(.three, .clubs), card(.four, .clubs),
            card(.two, .diamonds), card(.three, .diamonds), card(.four, .diamonds),
            card(.two, .hearts), card(.three, .hearts), card(.four, .hearts),
            card(.five, .hearts), card(.six, .hearts), card(.seven, .hearts),
            card(.eight, .hearts),
        ]
        let bid = bot.chooseBid(hand: weakHand, seat: .right, existingBids: [:])
        #expect(bid >= 1)
    }

    @Test func advancedBidsHigherWithStrongHand() {
        let bot = AdvancedBot()
        let strongHand = [
            card(.ace, .spades), card(.king, .spades), card(.queen, .spades),
            card(.jack, .spades), card(.ten, .spades),
            card(.ace, .hearts), card(.ace, .diamonds), card(.ace, .clubs),
            card(.king, .hearts), card(.king, .diamonds),
            card(.two, .clubs), card(.three, .clubs), card(.four, .clubs),
        ]
        let bid = bot.chooseBid(hand: strongHand, seat: .right, existingBids: [:])
        #expect(bid >= 5)
    }

    @Test func allBotsChooseLegalCards() {
        let rules = RuleSet.standard
        for difficulty in BotDifficulty.allCases {
            let bot = BotFactory.make(difficulty: difficulty)
            var rng = SeededRNG(seed: 42)
            let hands = Deck.deal(using: &rng)

            let hand = hands[1]
            let round = RoundState(
                roundNumber: 1, dealer: .bottom,
                hands: [.bottom: hands[0], .right: hands[1], .top: hands[2], .left: hands[3]]
            )

            let chosenLead = bot.chooseCard(
                hand: hand, trick: nil, seat: .right, round: round, rules: rules
            )
            #expect(hand.contains(chosenLead), "\(difficulty) bot chose card not in hand")

            let trick = Trick(firstPlay: TrickPlay(seat: .bottom, card: hands[0][0]))
            let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
            let chosenFollow = bot.chooseCard(
                hand: hand, trick: trick, seat: .right, round: round, rules: rules
            )
            #expect(legal.contains(chosenFollow), "\(difficulty) bot chose illegal card when following")
        }
    }
}

@Suite("Bot Simulation")
struct BotSimulationTests {
    @Test func fullGameAllBeginner() {
        runBotGame(difficulties: [.beginner, .beginner, .beginner, .beginner], seeds: 10)
    }

    @Test func fullGameAllIntermediate() {
        runBotGame(difficulties: [.intermediate, .intermediate, .intermediate, .intermediate], seeds: 10)
    }

    @Test func fullGameAllAdvanced() {
        runBotGame(difficulties: [.advanced, .advanced, .advanced, .advanced], seeds: 10)
    }

    @Test func fullGameMixedDifficulty() {
        runBotGame(difficulties: [.beginner, .intermediate, .advanced, .intermediate], seeds: 10)
    }

    private func runBotGame(difficulties: [BotDifficulty], seeds: Int) {
        let bots: [Seat: any BotStrategy] = [
            .bottom: BotFactory.make(difficulty: difficulties[0]),
            .right: BotFactory.make(difficulty: difficulties[1]),
            .top: BotFactory.make(difficulty: difficulties[2]),
            .left: BotFactory.make(difficulty: difficulties[3]),
        ]

        for seedVal: UInt64 in 0..<UInt64(seeds) {
            var rng = SeededRNG(seed: seedVal + 100)
            var state = GameState()

            for _ in 0..<5 {
                state.startRound(using: &rng)

                let firstBidder = state.dealer.next()
                var bidder = firstBidder
                for _ in 0..<4 {
                    let hand = state.currentRound!.hands[bidder]!
                    let bot = bots[bidder]!
                    let bid = bot.chooseBid(hand: hand, seat: bidder, existingBids: state.currentRound!.bids)
                    #expect(bid >= 1 && bid <= 13, "Invalid bid \(bid) from \(bidder)")
                    state.placeBid(seat: bidder, bid: bid)
                    bidder = bidder.next()
                }

                for trickNum in 0..<13 {
                    guard case .playing(_, var currentTurn) = state.phase else {
                        Issue.record("Expected playing phase at trick \(trickNum)")
                        return
                    }

                    for _ in 0..<4 {
                        let hand = state.currentRound!.hands[currentTurn]!
                        let legal = LegalMoves.legalCards(
                            for: hand, in: state.currentRound?.currentTrick, rules: state.rules
                        )
                        #expect(!legal.isEmpty, "No legal moves for \(currentTurn) at trick \(trickNum)")

                        let bot = bots[currentTurn]!
                        let chosen = bot.chooseCard(
                            hand: hand, trick: state.currentRound?.currentTrick,
                            seat: currentTurn, round: state.currentRound!, rules: state.rules
                        )
                        #expect(legal.contains(chosen),
                            "Bot \(currentTurn) chose illegal card \(chosen.description) at trick \(trickNum)")

                        state.playCard(seat: currentTurn, card: chosen)
                        currentTurn = currentTurn.next()
                    }

                    if case .trickComplete = state.phase {
                        state.startNextTrick()
                    }
                }

                #expect(state.phase == .roundComplete)
                let totalTricks = Seat.allCases.reduce(0) { $0 + state.currentRound!.tricksWon[$1]! }
                #expect(totalTricks == 13)

                state.endRound()
            }

            #expect(state.isGameOver)
        }
    }
}
