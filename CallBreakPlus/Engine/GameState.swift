enum GamePhase: Equatable, Sendable {
    case dealing
    case bidding(nextBidder: Seat)
    case playing(leader: Seat, currentTurn: Seat)
    case trickComplete(winner: Seat)
    case roundComplete
    case gameOver
}

enum RoundOutcome: Equatable, Sendable {
    case invalid
    case nextRound
    case gameOver
    case instantWin(seat: Seat, bid: Int)
}

struct RoundState: Sendable {
    let roundNumber: Int
    let dealer: Seat
    var hands: [Seat: [Card]]
    var bids: [Seat: Int]
    var tricksWon: [Seat: Int]
    var currentTrick: Trick?
    var completedTricks: [Trick]

    init(roundNumber: Int, dealer: Seat, hands: [Seat: [Card]]) {
        self.roundNumber = roundNumber
        self.dealer = dealer
        self.hands = hands
        self.bids = [:]
        self.tricksWon = Seat.allCases.reduce(into: [:]) { $0[$1] = 0 }
        self.currentTrick = nil
        self.completedTricks = []
    }

    var firstBidder: Seat { dealer.next() }

    var allBidsPlaced: Bool { bids.count == 4 }

    var allTricksPlayed: Bool { completedTricks.count == 13 }
}

struct GameState: Sendable {
    let rules: RuleSet
    var roundStates: [RoundState]
    var currentRound: RoundState?
    var phase: GamePhase
    /// Cumulative scores in tenths, avoiding floating-point tie errors.
    var scoreTenths: [Seat: Int]

    init(rules: RuleSet = .standard) {
        self.rules = rules
        self.roundStates = []
        self.currentRound = nil
        self.phase = .dealing
        self.scoreTenths = Seat.allCases.reduce(into: [:]) { $0[$1] = 0 }
    }

    var currentRoundNumber: Int { roundStates.count + 1 }

    var isGameOver: Bool { phase == .gameOver }

    var dealer: Seat {
        let dealerIndex = roundStates.count % 4
        return Seat(rawValue: dealerIndex)!
    }

    var instantWinner: Seat?

    mutating func startRound<R: RandomNumberGenerator>(using rng: inout R) {
        guard phase == .dealing, currentRound == nil else { return }
        let dealer = self.dealer
        var dealtHands = Deck.deal(using: &rng)

        if rules.redealOnWeakHand {
            var attempts = 0
            while RuleSet.needsRedeal(hands: dealtHands) && attempts < 20 {
                dealtHands = Deck.deal(using: &rng)
                attempts += 1
            }
        }

        var hands: [Seat: [Card]] = [:]
        for (i, seat) in Seat.allCases.enumerated() {
            hands[seat] = dealtHands[i]
        }
        currentRound = RoundState(roundNumber: currentRoundNumber, dealer: dealer, hands: hands)
        phase = .bidding(nextBidder: dealer.next())
    }

    mutating func placeBid(seat: Seat, bid: Int) {
        guard case .bidding(let nextBidder) = phase, seat == nextBidder else { return }
        guard bid >= 1 && bid <= 13 else { return }

        currentRound?.bids[seat] = bid

        if currentRound?.allBidsPlaced == true {
            let leader = currentRound!.firstBidder
            phase = .playing(leader: leader, currentTurn: leader)
        } else {
            phase = .bidding(nextBidder: seat.next())
        }
    }

    mutating func playCard(seat: Seat, card: Card) {
        guard case .playing(_, let currentTurn) = phase, seat == currentTurn else { return }
        guard var round = currentRound else { return }

        guard let hand = round.hands[seat], hand.contains(card) else { return }

        let legal = LegalMoves.legalCards(for: hand, in: round.currentTrick, rules: rules)
        guard legal.contains(card) else { return }

        round.hands[seat]?.removeAll { $0 == card }

        let play = TrickPlay(seat: seat, card: card)

        if round.currentTrick == nil {
            round.currentTrick = Trick(firstPlay: play)
        } else {
            round.currentTrick?.plays.append(play)
        }

        if round.currentTrick?.isComplete == true {
            let winner = TrickResolver.winner(of: round.currentTrick!)
            round.tricksWon[winner, default: 0] += 1
            round.completedTricks.append(round.currentTrick!)
            round.currentTrick = nil
            currentRound = round

            if round.allTricksPlayed {
                phase = .roundComplete
            } else {
                phase = .trickComplete(winner: winner)
            }
        } else {
            currentRound = round
            phase = .playing(leader: round.currentTrick!.plays[0].seat, currentTurn: seat.next())
        }
    }

    mutating func startNextTrick() {
        guard case .trickComplete(let winner) = phase else { return }
        phase = .playing(leader: winner, currentTurn: winner)
    }

    func roundOutcome() -> RoundOutcome {
        guard case .roundComplete = phase, let round = currentRound else { return .invalid }
        return decideOutcome(for: round)
    }

    @discardableResult
    mutating func endRound() -> RoundOutcome {
        guard case .roundComplete = phase, let round = currentRound else { return .invalid }
        let outcome = decideOutcome(for: round)
        guard outcome != .invalid else { return .invalid }

        for seat in Seat.allCases {
            guard let bid = round.bids[seat], let tricks = round.tricksWon[seat] else { return .invalid }
            scoreTenths[seat, default: 0] += Scoring.roundScoreTenths(bid: bid, tricksWon: tricks)
        }

        roundStates.append(round)
        currentRound = nil

        switch outcome {
        case .instantWin(let seat, _):
            instantWinner = seat
            phase = .gameOver
        case .gameOver:
            phase = .gameOver
        case .nextRound:
            phase = .dealing
        case .invalid:
            return .invalid
        }

        return outcome
    }

    private func decideOutcome(for round: RoundState) -> RoundOutcome {
        guard Seat.allCases.allSatisfy({ round.bids[$0] != nil && round.tricksWon[$0] != nil }) else {
            return .invalid
        }

        if let threshold = rules.instantWinBid {
            for seat in Seat.allCases {
                guard let bid = round.bids[seat], let tricks = round.tricksWon[seat] else { continue }
                if bid >= threshold && tricks >= bid {
                    return .instantWin(seat: seat, bid: bid)
                }
            }
        }

        return roundStates.count + 1 >= rules.roundCount ? .gameOver : .nextRound
    }
}
