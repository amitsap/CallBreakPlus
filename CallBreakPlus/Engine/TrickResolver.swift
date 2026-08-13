enum TrickResolver {
    static func winner(of trick: Trick) -> Seat {
        let spadePlays = trick.plays.filter { $0.card.suit == .spades }
        if !spadePlays.isEmpty {
            return spadePlays.max(by: { $0.card.rank < $1.card.rank })!.seat
        }
        let ledSuitPlays = trick.plays.filter { $0.card.suit == trick.ledSuit }
        return ledSuitPlays.max(by: { $0.card.rank < $1.card.rank })!.seat
    }
}
