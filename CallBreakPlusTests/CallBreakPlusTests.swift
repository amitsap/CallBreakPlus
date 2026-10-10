import Testing
@testable import CallBreakPlus

// MARK: - Helpers

func card(_ rank: Rank, _ suit: Suit) -> Card {
    Card(suit: suit, rank: rank)
}

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }
}

// MARK: - Model Tests

@Suite("Card & Deck")
struct CardDeckTests {
    @Test func fullDeckHas52Cards() {
        #expect(Deck.fullDeck.count == 52)
    }

    @Test func fullDeckHasUniqueCards() {
        let set = Set(Deck.fullDeck)
        #expect(set.count == 52)
    }

    @Test func dealGivesFourHandsOf13() {
        var rng = SeededRNG(seed: 42)
        let hands = Deck.deal(using: &rng)
        #expect(hands.count == 4)
        for hand in hands {
            #expect(hand.count == 13)
        }
    }

    @Test func dealDistributesAllCards() {
        var rng = SeededRNG(seed: 42)
        let hands = Deck.deal(using: &rng)
        let allCards = Set(hands.flatMap { $0 })
        #expect(allCards.count == 52)
    }

    @Test func handsAreSorted() {
        var rng = SeededRNG(seed: 42)
        let hands = Deck.deal(using: &rng)
        for hand in hands {
            #expect(hand == hand.sorted())
        }
    }

    @Test func cardComparison() {
        #expect(card(.two, .clubs) < card(.three, .clubs))
        #expect(card(.ace, .diamonds) < card(.two, .clubs))
        #expect(card(.ace, .hearts) < card(.two, .spades))
    }

    @Test func rankOrder() {
        #expect(Rank.two < Rank.three)
        #expect(Rank.ten < Rank.jack)
        #expect(Rank.jack < Rank.queen)
        #expect(Rank.queen < Rank.king)
        #expect(Rank.king < Rank.ace)
    }

    @Test func seatRotation() {
        #expect(Seat.bottom.next() == .right)
        #expect(Seat.right.next() == .top)
        #expect(Seat.top.next() == .left)
        #expect(Seat.left.next() == .bottom)
    }

    @Test func determinismWithSameSeed() {
        var rng1 = SeededRNG(seed: 99)
        var rng2 = SeededRNG(seed: 99)
        let hands1 = Deck.deal(using: &rng1)
        let hands2 = Deck.deal(using: &rng2)
        for i in 0..<4 {
            #expect(hands1[i] == hands2[i])
        }
    }
}

// MARK: - Legal Move Tests

@Suite("Legal Moves — Standard Rules")
struct LegalMoveTests {
    let rules = RuleSet.standard

    @Test func leadingCanPlayAnything() {
        let hand = [card(.ace, .spades), card(.king, .hearts), card(.two, .clubs)]
        let legal = LegalMoves.legalCards(for: hand, in: nil, rules: rules)
        #expect(legal.count == 3)
    }

    @Test func mustFollowSuit() {
        let hand = [card(.ace, .hearts), card(.king, .hearts), card(.two, .clubs)]
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.five, .hearts)))
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal.count == 2)
        #expect(legal.allSatisfy { $0.suit == .hearts })
    }

    @Test func mustGoHigherWhenAble() {
        let hand = [card(.three, .hearts), card(.king, .hearts), card(.ace, .hearts)]
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal == [card(.king, .hearts), card(.ace, .hearts)])
    }

    @Test func canPlayAnyOfSuitWhenCantGoHigher() {
        let hand = [card(.three, .hearts), card(.five, .hearts), card(.two, .clubs)]
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal == [card(.three, .hearts), card(.five, .hearts)])
    }

    @Test func mustTrumpWhenVoidInLedSuit() {
        let hand = [card(.ace, .spades), card(.five, .spades), card(.king, .diamonds)]
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal.allSatisfy { $0.suit == .spades })
    }

    @Test func mustOvertrumpWhenAble() {
        let hand = [card(.five, .spades), card(.king, .spades), card(.two, .diamonds)]
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .right, card: card(.ten, .hearts)),
            TrickPlay(seat: .top, card: card(.jack, .spades)),
        ])
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal == [card(.king, .spades)])
    }

    @Test func strictVariantRequiresSpadeWhenCantOvertrump() {
        let strictRules = RuleSet(
            mustGoHigher: true,
            mustTrump: true,
            canDiscardWhenCantOvertrump: false
        )
        let hand = [card(.three, .spades), card(.five, .spades), card(.two, .diamonds)]
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .right, card: card(.ten, .hearts)),
            TrickPlay(seat: .top, card: card(.king, .spades)),
        ])
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: strictRules)
        #expect(legal == [card(.three, .spades), card(.five, .spades)])
    }

    @Test func playAnythingWhenVoidInBothLedAndSpades() {
        let hand = [card(.ace, .diamonds), card(.king, .clubs)]
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal.count == 2)
    }

    @Test func mustGoHigherChecksCurrentTrickHighest() {
        let hand = [card(.seven, .hearts), card(.jack, .hearts), card(.two, .clubs)]
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .right, card: card(.five, .hearts)),
            TrickPlay(seat: .top, card: card(.nine, .hearts)),
        ])
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal == [card(.jack, .hearts)])
    }

    @Test func anyLedSuitCardIsLegalAfterTrickIsTrumped() {
        let hand = [
            card(.six, .clubs), card(.seven, .clubs),
            card(.nine, .clubs), card(.king, .clubs),
            card(.four, .hearts), card(.six, .spades),
        ]
        let trick = Trick(ledSuit: .clubs, plays: [
            TrickPlay(seat: .top, card: card(.eight, .clubs)),
            TrickPlay(seat: .left, card: card(.two, .spades)),
        ])

        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)

        #expect(legal == [
            card(.six, .clubs), card(.seven, .clubs),
            card(.nine, .clubs), card(.king, .clubs),
        ])
    }

    @Test func emptyHandReturnsEmpty() {
        let legal = LegalMoves.legalCards(for: [], in: nil, rules: rules)
        #expect(legal.isEmpty)
    }
}

@Suite("Legal Moves — Free Discard")
struct LegalMoveFreeDiscardTests {
    let rules = RuleSet(mustGoHigher: true, mustTrump: true, canDiscardWhenCantOvertrump: true)

    @Test func canDiscardWhenCantBeatExistingSpade() {
        let hand = [card(.three, .spades), card(.five, .spades), card(.two, .diamonds)]
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .right, card: card(.ten, .hearts)),
            TrickPlay(seat: .top, card: card(.king, .spades)),
        ])
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal.count == 3)
    }

    @Test func stillMustOvertrumpWhenAble() {
        let hand = [card(.five, .spades), card(.ace, .spades), card(.two, .diamonds)]
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .right, card: card(.ten, .hearts)),
            TrickPlay(seat: .top, card: card(.jack, .spades)),
        ])
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal == [card(.ace, .spades)])
    }

    @Test func mustPlaySpadeWhenNoSpadesInTrick() {
        let hand = [card(.three, .spades), card(.five, .spades), card(.two, .diamonds)]
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal.allSatisfy { $0.suit == .spades })
    }
}

@Suite("Re-deal & Instant Win")
struct HouseRulesTests {
    @Test func standardHouseRulesAreEnabled() {
        let rules = RuleSet.standard
        #expect(rules.canDiscardWhenCantOvertrump)
        #expect(rules.redealOnWeakHand)
        #expect(rules.instantWinBid == 8)
    }

    @Test func needsRedealWhenNoSpades() {
        let hands: [[Card]] = [
            (0..<13).map { _ in card(.ace, .hearts) },
            (0..<13).map { _ in card(.king, .spades) },
            (0..<13).map { _ in card(.queen, .spades) },
            (0..<13).map { _ in card(.jack, .spades) },
        ]
        #expect(RuleSet.needsRedeal(hands: hands) == true)
    }

    @Test func needsRedealWhenNoFaceCards() {
        let hands: [[Card]] = [
            [card(.two, .spades), card(.three, .spades), card(.four, .hearts),
             card(.five, .hearts), card(.six, .diamonds), card(.seven, .diamonds),
             card(.eight, .clubs), card(.nine, .clubs), card(.ten, .clubs),
             card(.two, .hearts), card(.three, .diamonds), card(.four, .clubs), card(.five, .clubs)],
            (0..<13).map { _ in card(.ace, .spades) },
            (0..<13).map { _ in card(.king, .spades) },
            (0..<13).map { _ in card(.queen, .spades) },
        ]
        #expect(RuleSet.needsRedeal(hands: hands) == true)
    }

    @Test func noRedealWhenAllHandsHaveSpadeAndFace() {
        let hand = [card(.ace, .spades), card(.king, .hearts), card(.two, .clubs),
                    card(.three, .clubs), card(.four, .clubs), card(.five, .clubs),
                    card(.six, .clubs), card(.seven, .clubs), card(.eight, .clubs),
                    card(.nine, .clubs), card(.ten, .clubs), card(.two, .diamonds), card(.three, .diamonds)]
        let hands = [hand, hand, hand, hand]
        #expect(RuleSet.needsRedeal(hands: hands) == false)
    }

    @Test func instantWinTriggersGameOver() {
        var rules = RuleSet.standard
        rules.instantWinBid = 8
        var state = GameState(rules: rules)
        var round = RoundState(roundNumber: 1, dealer: .bottom, hands: testHands())
        round.bids = [.bottom: 8, .right: 2, .top: 2, .left: 1]
        round.tricksWon = [.bottom: 8, .right: 2, .top: 2, .left: 1]
        state.currentRound = round
        state.phase = .roundComplete
        state.endRound()
        #expect(state.isGameOver)
        #expect(state.instantWinner == .bottom)
    }
}

@Suite("Legal Moves — Rules Off")
struct LegalMoveRulesOffTests {
    let rules = RuleSet(mustGoHigher: false, mustTrump: false)

    @Test func noMustGoHigherAllowsAnySuitCard() {
        let hand = [card(.three, .hearts), card(.king, .hearts), card(.ace, .hearts)]
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal.count == 3)
        #expect(legal.allSatisfy { $0.suit == .hearts })
    }

    @Test func noMustTrumpAllowsAnyCardWhenVoid() {
        let hand = [card(.ace, .spades), card(.king, .diamonds), card(.two, .clubs)]
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        #expect(legal.count == 3)
    }
}

@Suite("Legal Moves — Restrictions")
struct LegalMoveRestrictionTests {
    let rules = RuleSet.standard

    /// The cards a restriction allows, derived independently of `legalCards`.
    private func permitted(by restriction: PlayRestriction, in hand: [Card]) -> [Card] {
        switch restriction {
        case .none: hand
        case .followSuit(let suit): hand.filter { $0.suit == suit }
        case .beat(let target): hand.filter { $0.suit == target.suit && $0.rank > target.rank }
        case .trump: hand.filter { $0.suit == .spades }
        case .overtrump(let target): hand.filter { $0.suit == .spades && $0.rank > target.rank }
        }
    }

    /// Asserts the restriction, that `legalCards` agrees with it, and the message.
    private func check(
        _ hand: [Card], _ trick: Trick?, rules: RuleSet? = nil,
        is expected: PlayRestriction, says message: String?
    ) {
        let rules = rules ?? self.rules
        let restriction = LegalMoves.restriction(for: hand, in: trick, rules: rules)
        #expect(restriction == expected)
        #expect(LegalMoves.legalCards(for: hand, in: trick, rules: rules) == permitted(by: restriction, in: hand))
        #expect(GameViewModel.unavailableCardMessage(hand: hand, trick: trick, rules: rules) == message)
    }

    @Test func leadingIsUnrestricted() {
        check([card(.ace, .spades), card(.two, .clubs)], nil, is: .none, says: nil)
    }

    @Test func voidInLedSuitAndSpadesIsUnrestricted() {
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        check([card(.ace, .diamonds), card(.king, .clubs)], trick, is: .none, says: nil)
    }

    @Test func freeDiscardWhenCantOvertrumpIsUnrestricted() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .right, card: card(.ten, .hearts)),
            TrickPlay(seat: .top, card: card(.king, .spades)),
        ])
        check([card(.three, .spades), card(.two, .diamonds)], trick, is: .none, says: nil)
    }

    @Test func followSuitOnceTrickIsTrumped() {
        let trick = Trick(ledSuit: .clubs, plays: [
            TrickPlay(seat: .top, card: card(.eight, .clubs)),
            TrickPlay(seat: .left, card: card(.two, .spades)),
        ])
        check(
            [card(.six, .clubs), card(.king, .clubs), card(.four, .hearts), card(.six, .spades)], trick,
            is: .followSuit(.clubs),
            says: "Follow Clubs. The trick is trumped, so any club is allowed."
        )
    }

    @Test func followSuitWhenNothingBeatsTheHighest() {
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        check(
            [card(.three, .hearts), card(.five, .hearts), card(.two, .clubs)], trick,
            is: .followSuit(.hearts),
            says: "Follow Hearts. None of yours beats the 10♥, so any heart is allowed."
        )
    }

    @Test func followSuitWithoutMustGoHigher() {
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        check(
            [card(.three, .hearts), card(.king, .hearts), card(.two, .clubs)], trick,
            rules: RuleSet(mustGoHigher: false),
            is: .followSuit(.hearts),
            says: "Follow Hearts."
        )
    }

    @Test func beatWithTheOnlyHigherCard() {
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.king, .hearts)))
        check(
            [card(.three, .hearts), card(.ace, .hearts), card(.two, .clubs)], trick,
            is: .beat(card(.king, .hearts)),
            says: "Beat the K♥: play your A♥."
        )
    }

    @Test func beatWithAnyOfSeveralHigherCards() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .right, card: card(.five, .hearts)),
            TrickPlay(seat: .top, card: card(.ten, .hearts)),
        ])
        check(
            [card(.three, .hearts), card(.king, .hearts), card(.ace, .hearts)], trick,
            is: .beat(card(.ten, .hearts)),
            says: "Beat the 10♥ with a higher heart."
        )
    }

    @Test func trumpWhenOutOfLedSuit() {
        let trick = Trick(firstPlay: TrickPlay(seat: .right, card: card(.ten, .hearts)))
        check(
            [card(.ace, .spades), card(.five, .spades), card(.king, .diamonds)], trick,
            is: .trump,
            says: "You’re out of hearts, so you must play a Spade."
        )
    }

    @Test func strictVariantTrumpsWhenCantOvertrump() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .right, card: card(.ten, .hearts)),
            TrickPlay(seat: .top, card: card(.king, .spades)),
        ])
        check(
            [card(.three, .spades), card(.five, .spades), card(.two, .diamonds)], trick,
            rules: RuleSet(canDiscardWhenCantOvertrump: false),
            is: .trump,
            says: "You’re out of hearts, so you must play a Spade."
        )
    }

    @Test func overtrumpWithTheOnlyHigherSpade() {
        // The audit's T2 case: tapping the 5♠ here used to say "You must play a Spade".
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .right, card: card(.ten, .hearts)),
            TrickPlay(seat: .top, card: card(.jack, .spades)),
        ])
        check(
            [card(.five, .spades), card(.king, .spades), card(.two, .diamonds)], trick,
            is: .overtrump(card(.jack, .spades)),
            says: "Beat the J♠: play your K♠."
        )
    }

    @Test func overtrumpWithAnyOfSeveralHigherSpades() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .right, card: card(.ten, .hearts)),
            TrickPlay(seat: .top, card: card(.queen, .spades)),
        ])
        check(
            [card(.five, .spades), card(.king, .spades), card(.ace, .spades), card(.two, .diamonds)], trick,
            is: .overtrump(card(.queen, .spades)),
            says: "Beat the Q♠ with a higher Spade."
        )
    }
}

// MARK: - Trick Resolution Tests

@Suite("Trick Resolution")
struct TrickResolutionTests {
    @Test func highestOfLedSuitWins() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .bottom, card: card(.ten, .hearts)),
            TrickPlay(seat: .right, card: card(.king, .hearts)),
            TrickPlay(seat: .top, card: card(.five, .hearts)),
            TrickPlay(seat: .left, card: card(.jack, .hearts)),
        ])
        #expect(TrickResolver.winner(of: trick) == .right)
    }

    @Test func trumpBeatsLedSuit() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .bottom, card: card(.ace, .hearts)),
            TrickPlay(seat: .right, card: card(.two, .spades)),
            TrickPlay(seat: .top, card: card(.king, .hearts)),
            TrickPlay(seat: .left, card: card(.queen, .hearts)),
        ])
        #expect(TrickResolver.winner(of: trick) == .right)
    }

    @Test func highestTrumpWins() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .bottom, card: card(.ace, .hearts)),
            TrickPlay(seat: .right, card: card(.five, .spades)),
            TrickPlay(seat: .top, card: card(.two, .spades)),
            TrickPlay(seat: .left, card: card(.queen, .hearts)),
        ])
        #expect(TrickResolver.winner(of: trick) == .right)
    }

    @Test func nonLedNonTrumpDoesntWin() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .bottom, card: card(.three, .hearts)),
            TrickPlay(seat: .right, card: card(.ace, .diamonds)),
            TrickPlay(seat: .top, card: card(.ace, .clubs)),
            TrickPlay(seat: .left, card: card(.five, .hearts)),
        ])
        #expect(TrickResolver.winner(of: trick) == .left)
    }

    @Test func spadeLedTrick() {
        let trick = Trick(ledSuit: .spades, plays: [
            TrickPlay(seat: .bottom, card: card(.five, .spades)),
            TrickPlay(seat: .right, card: card(.ace, .spades)),
            TrickPlay(seat: .top, card: card(.king, .spades)),
            TrickPlay(seat: .left, card: card(.two, .spades)),
        ])
        #expect(TrickResolver.winner(of: trick) == .right)
    }

    // The winning ring reads partial tricks, which always hold the lead card.

    @Test func leadAloneIsWinning() {
        let trick = Trick(firstPlay: TrickPlay(seat: .top, card: card(.nine, .hearts)))
        #expect(TrickResolver.winner(of: trick) == .top)
    }

    @Test func higherFollowTakesTheLeadInTwoPlays() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .top, card: card(.nine, .hearts)),
            TrickPlay(seat: .left, card: card(.king, .hearts)),
        ])
        #expect(TrickResolver.winner(of: trick) == .left)
    }

    @Test func offSuitDiscardDoesNotTakeTheLeadInTwoPlays() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .top, card: card(.nine, .hearts)),
            TrickPlay(seat: .left, card: card(.ace, .clubs)),
        ])
        #expect(TrickResolver.winner(of: trick) == .top)
    }

    @Test func trumpTakesTheLeadInThreePlays() {
        let trick = Trick(ledSuit: .hearts, plays: [
            TrickPlay(seat: .top, card: card(.nine, .hearts)),
            TrickPlay(seat: .left, card: card(.king, .hearts)),
            TrickPlay(seat: .bottom, card: card(.two, .spades)),
        ])
        #expect(TrickResolver.winner(of: trick) == .bottom)
    }
}

// MARK: - Scoring Tests

@Suite("Scoring")
struct ScoringTests {
    @Test func exactBid() {
        #expect(Scoring.roundScore(bid: 3, tricksWon: 3) == 3.0)
    }

    @Test func overtricks() {
        #expect(Scoring.roundScore(bid: 3, tricksWon: 5) == 3.2)
        #expect(Scoring.roundScoreTenths(bid: 3, tricksWon: 5) == 32)
    }

    @Test func failedBid() {
        #expect(Scoring.roundScore(bid: 5, tricksWon: 3) == -5.0)
    }

    @Test func minimumBid() {
        #expect(Scoring.roundScore(bid: 1, tricksWon: 1) == 1.0)
    }

    @Test func minimumBidFailed() {
        #expect(Scoring.roundScore(bid: 1, tricksWon: 0) == -1.0)
    }

    @Test func maxOvertrick() {
        #expect(Scoring.roundScore(bid: 1, tricksWon: 13) == 2.2)
    }

    @Test func highBidExact() {
        #expect(Scoring.roundScore(bid: 13, tricksWon: 13) == 13.0)
    }

    @Test func highBidFailed() {
        #expect(Scoring.roundScore(bid: 13, tricksWon: 12) == -13.0)
    }

    @Test func equivalentScorePathsRemainExactlyEqual() {
        let first = Scoring.roundScoreTenths(bid: 1, tricksWon: 1)
            + Scoring.roundScoreTenths(bid: 2, tricksWon: 3)
        let second = Scoring.roundScoreTenths(bid: 3, tricksWon: 4)
        #expect(first == second)
    }
}
