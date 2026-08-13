struct IntermediateBot: BotStrategy {
    func chooseBid(hand: [Card], seat: Seat, existingBids: [Seat: Int]) -> Int {
        var bid = 0
        let spades = hand.filter { $0.suit == .spades }

        for card in spades {
            if card.rank >= .jack { bid += 1 }
        }
        if spades.count >= 4 { bid += 1 }

        for suit in [Suit.hearts, .diamonds, .clubs] {
            let suitCards = hand.filter { $0.suit == suit }
            if suitCards.contains(where: { $0.rank == .ace }) { bid += 1 }
            if suitCards.count <= 1 && !spades.isEmpty { bid += 1 }
        }

        let tableBid = existingBids.values.reduce(0, +)
        if tableBid >= 10 { bid -= 1 }
        return max(1, min(bid, 8))
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
        let bidMet = tricksWon >= bid
        let brokenSuits = Set(round.completedTricks.flatMap { completed in
            completed.plays.dropFirst().compactMap { $0.card.suit == completed.ledSuit ? nil : completed.ledSuit }
        })

        if trick == nil {
            if bidMet {
                return legal.filter { $0.suit != .spades }.min() ?? legal.min()!
            }
            if let winner = findHighLead(legal: legal, brokenSuits: brokenSuits) {
                return winner
            }
            let safeNonSpades = legal.filter { $0.suit != .spades && !brokenSuits.contains($0.suit) }
            return safeNonSpades.min() ?? legal.filter { $0.suit != .spades }.min() ?? legal.min()!
        }

        let trick = trick!

        if bidMet {
            return legal.min()!
        }

        if let cheapWin = cheapestWinner(legal: legal, trick: trick) {
            return cheapWin
        }

        return legal.min()!
    }

    private func findHighLead(legal: [Card], brokenSuits: Set<Suit>) -> Card? {
        for suit in [Suit.hearts, .diamonds, .clubs] {
            guard !brokenSuits.contains(suit) else { continue }
            let suitCards = legal.filter { $0.suit == suit }
            if let ace = suitCards.first(where: { $0.rank == .ace }) {
                return ace
            }
        }
        return nil
    }

    private func cheapestWinner(legal: [Card], trick: Trick) -> Card? {
        let spadePlayed = trick.plays.contains { $0.card.suit == .spades }
        let highestSpade = trick.highestSpade

        var winners: [Card] = []
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

        return winners.min()
    }
}
