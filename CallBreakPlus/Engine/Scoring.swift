enum Scoring {
    /// Exact score representation used by the engine. One point is ten tenths.
    static func roundScoreTenths(bid: Int, tricksWon: Int) -> Int {
        tricksWon >= bid ? (bid * 10) + (tricksWon - bid) : -(bid * 10)
    }

    static func roundScore(bid: Int, tricksWon: Int) -> Double {
        score(fromTenths: roundScoreTenths(bid: bid, tricksWon: tricksWon))
    }

    static func score(fromTenths tenths: Int) -> Double { Double(tenths) / 10 }
}
