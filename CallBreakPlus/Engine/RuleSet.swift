struct RuleSet: Sendable {
    var mustGoHigher: Bool = true
    var mustTrump: Bool = true
    var canDiscardWhenCantOvertrump: Bool = true
    var redealOnWeakHand: Bool = true
    var instantWinBid: Int? = 8
    var roundCount: Int = 5

    static let standard = RuleSet()

    static func needsRedeal(hands: [[Card]]) -> Bool {
        for hand in hands {
            let hasSpade = hand.contains { $0.suit == .spades }
            let hasFaceCard = hand.contains { $0.rank >= .jack }
            if !hasSpade || !hasFaceCard { return true }
        }
        return false
    }
}
