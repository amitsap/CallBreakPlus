struct BeginnerBot: BotStrategy {
    func chooseBid(hand: [Card], seat: Seat, existingBids: [Seat: Int]) -> Int {
        var bid = 0
        for card in hand {
            if card.suit == .spades, card.rank >= .queen { bid += 1 }
            if card.suit != .spades, card.rank >= .king { bid += 1 }
        }
        let spadeCount = hand.count { $0.suit == .spades }
        if spadeCount >= 5 { bid += 1 }
        return max(1, min(bid, 13))
    }

    func chooseCard(
        hand: [Card],
        trick: Trick?,
        seat: Seat,
        round: RoundState,
        rules: RuleSet
    ) -> Card {
        let legal = LegalMoves.legalCards(for: hand, in: trick, rules: rules)

        if trick == nil {
            return legal.filter { $0.suit != .spades }.min() ?? legal.min()!
        }

        if let winner = cheapestWinner(in: legal, trick: trick!, seat: seat) { return winner }
        return legal.min()!
    }

    private func cheapestWinner(in legal: [Card], trick: Trick, seat: Seat) -> Card? {
        legal.filter { candidate in
            var copy = trick
            copy.plays.append(TrickPlay(seat: seat, card: candidate))
            return TrickResolver.winner(of: copy) == seat
        }.min()
    }
}
