/// Why a hand's playable cards are what they are: the rule that narrows the
/// hand on this turn. Mirrors `LegalMoves.legalCards` branch for branch.
enum PlayRestriction: Equatable, Sendable {
    case none              // any card
    case followSuit(Suit)  // any card of the led suit
    case beat(Card)        // a led-suit card above this one
    case trump             // any spade
    case overtrump(Card)   // a spade above this one
}

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

    static func restriction(for hand: [Card], in trick: Trick?, rules: RuleSet) -> PlayRestriction {
        guard !hand.isEmpty, let trick else { return .none }

        let ledSuit = trick.ledSuit
        let cardsOfLedSuit = hand.filter { $0.suit == ledSuit }

        if !cardsOfLedSuit.isEmpty {
            if rules.mustGoHigher, trick.highestSpade == nil,
               let highest = trick.highestOfLedSuit,
               cardsOfLedSuit.contains(where: { $0.rank > highest.rank }) {
                return .beat(highest)
            }
            return .followSuit(ledSuit)
        }

        let spades = hand.filter { $0.suit == .spades }

        if rules.mustTrump && !spades.isEmpty {
            if let highestSpade = trick.highestSpade {
                if spades.contains(where: { $0.rank > highestSpade.rank }) {
                    return .overtrump(highestSpade)
                }
                if rules.canDiscardWhenCantOvertrump {
                    return .none
                }
            }
            return .trump
        }

        return .none
    }
}
