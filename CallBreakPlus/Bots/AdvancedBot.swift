struct AdvancedBot: BotStrategy {
    func chooseBid(hand: [Card], seat: Seat, existingBids: [Seat: Int]) -> Int {
        var bid: Double = 0
        let spades = hand.filter { $0.suit == .spades }.sorted { $0.rank > $1.rank }
        let spadeCount = spades.count

        for (i, card) in spades.enumerated() {
            if card.rank >= .jack { bid += 1.0 }
            else if card.rank >= .nine && i < 3 { bid += 0.5 }
        }

        if spadeCount >= 5 { bid += 1.0 }
        else if spadeCount >= 4 { bid += 0.5 }

        for suit in [Suit.hearts, .diamonds, .clubs] {
            let suitCards = hand.filter { $0.suit == suit }.sorted { $0.rank > $1.rank }
            if suitCards.isEmpty {
                if spadeCount > 0 { bid += 1.0 }
            } else if suitCards.count == 1 {
                if suitCards[0].rank == .ace { bid += 1.0 }
                else if spadeCount > 0 { bid += 0.5 }
            } else {
                if suitCards[0].rank == .ace { bid += 0.8 }
                if suitCards.count >= 2 && suitCards[0].rank == .ace && suitCards[1].rank == .king {
                    bid += 0.7
                }
            }
        }

        let called = existingBids.values.reduce(0, +)
        if called >= 10 { bid -= 0.5 }
        if existingBids.count == 3, called <= 5 { bid += 0.5 }
        return max(1, min(Int(bid.rounded()), 13))
    }

    func chooseCard(
        hand: [Card],
        trick: Trick?,
        seat: Seat,
        round: RoundState,
        rules: RuleSet
    ) -> Card {
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)
        let bid = round.bids[seat] ?? 1
        let tricksWon = round.tricksWon[seat] ?? 0
        let tricksNeeded = bid - tricksWon
        let tricksRemaining = 13 - round.completedTricks.count

        let playedCards = Set(round.completedTricks.flatMap { $0.plays.map(\.card) }
            + (round.currentTrick?.plays.map(\.card) ?? []))

        if trick == nil {
            return chooseLead(
                legal: legal, hand: hand, tricksNeeded: tricksNeeded,
                tricksRemaining: tricksRemaining, playedCards: playedCards
            )
        }

        let trick = trick!

        if tricksNeeded <= 0 {
            return dumpCard(legal: legal)
        }

        // Public calls inform defense: stop an opponent who is one trick from making their bid.
        if let currentWinner = currentWinningSeat(in: trick), currentWinner != seat,
           let opponentBid = round.bids[currentWinner],
           round.tricksWon[currentWinner, default: 0] == opponentBid - 1,
           let blocker = smartestWinner(legal: legal, trick: trick, tricksNeeded: tricksNeeded,
                                        tricksRemaining: tricksRemaining, playedCards: playedCards) {
            return blocker
        }

        if let win = smartestWinner(
            legal: legal, trick: trick, tricksNeeded: tricksNeeded,
            tricksRemaining: tricksRemaining, playedCards: playedCards
        ) {
            return win
        }

        return dumpCard(legal: legal)
    }

    private func chooseLead(
        legal: [Card], hand: [Card], tricksNeeded: Int,
        tricksRemaining: Int, playedCards: Set<Card>
    ) -> Card {
        if tricksNeeded <= 0 {
            return legal.filter { $0.suit != .spades }.min() ?? legal.min()!
        }

        for card in legal.sorted(by: >) where card.suit != .spades {
            let higherOutstanding = Deck.fullDeck.contains {
                $0.suit == card.suit && $0.rank > card.rank
                    && !playedCards.contains($0) && !hand.contains($0)
            }
            if !higherOutstanding { return card }
        }

        for suit in [Suit.hearts, .diamonds, .clubs] {
            let suitCards = legal.filter { $0.suit == suit }
            if let king = suitCards.first(where: { $0.rank == .king }) {
                let aceOut = !playedCards.contains(Card(suit: suit, rank: .ace))
                    && !hand.contains(Card(suit: suit, rank: .ace))
                if !aceOut { return king }
            }
        }

        if tricksNeeded >= tricksRemaining,
           let masterSpade = legal.filter({ $0.suit == .spades }).max() {
            return masterSpade
        }
        return legal.filter { $0.suit != .spades }.min() ?? legal.min()!
    }

    private func smartestWinner(
        legal: [Card], trick: Trick, tricksNeeded: Int,
        tricksRemaining: Int, playedCards: Set<Card>
    ) -> Card? {
        var winners: [Card] = []
        let spadePlayed = trick.plays.contains { $0.card.suit == .spades }
        let highestSpade = trick.highestSpade

        for card in legal {
            if card.suit == trick.ledSuit && !spadePlayed {
                if let highest = trick.highestOfLedSuit, card.rank > highest.rank {
                    winners.append(card)
                }
            } else if card.suit == .spades {
                if let hs = highestSpade {
                    if card.rank > hs.rank { winners.append(card) }
                } else {
                    winners.append(card)
                }
            }
        }

        if winners.isEmpty { return nil }

        if trick.plays.count == 3 || tricksNeeded >= tricksRemaining {
            return winners.min()
        }

        // Preserve a master card when a cheaper public-card-aware winner exists.
        return winners.sorted().first { card in
            Deck.fullDeck.contains { $0.suit == card.suit && $0.rank > card.rank && !playedCards.contains($0) }
        } ?? winners.min()
    }

    private func dumpCard(legal: [Card]) -> Card {
        let nonSpades = legal.filter { $0.suit != .spades }
        if !nonSpades.isEmpty { return nonSpades.min()! }
        return legal.min()!
    }

    private func currentWinningSeat(in trick: Trick) -> Seat? {
        guard !trick.plays.isEmpty else { return nil }
        return TrickResolver.winner(of: trick)
    }
}
