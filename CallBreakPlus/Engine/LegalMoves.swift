enum LegalMoves {
    static func legalCards(for hand: [Card], in trick: Trick?, rules: RuleSet) -> [Card] {
        guard !hand.isEmpty else { return [] }

        guard let trick else {
            return hand
        }

        let ledSuit = trick.ledSuit
        let cardsOfLedSuit = hand.filter { $0.suit == ledSuit }

        if !cardsOfLedSuit.isEmpty {
            // A led-suit card cannot overtake a trump. The player must still
            // follow suit, but may conserve higher cards once the trick is trumped.
            if rules.mustGoHigher, trick.highestSpade == nil,
               let highest = trick.highestOfLedSuit {
                let higherCards = cardsOfLedSuit.filter { $0.rank > highest.rank }
                if !higherCards.isEmpty {
                    return higherCards
                }
            }
            return cardsOfLedSuit
        }

        let spades = hand.filter { $0.suit == .spades }

        if rules.mustTrump && !spades.isEmpty {
            if let highestSpade = trick.highestSpade {
                let higherSpades = spades.filter { $0.rank > highestSpade.rank }
                if !higherSpades.isEmpty {
                    return higherSpades
                }
                if rules.canDiscardWhenCantOvertrump {
                    return hand
                }
            }
            return spades
        }

        return hand
    }
}
