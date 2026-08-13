enum BotDifficulty: String, CaseIterable, Sendable {
    case beginner
    case intermediate
    case advanced
}

protocol BotStrategy: Sendable {
    func chooseBid(hand: [Card], seat: Seat, existingBids: [Seat: Int]) -> Int
    func chooseCard(
        hand: [Card],
        trick: Trick?,
        seat: Seat,
        round: RoundState,
        rules: RuleSet
    ) -> Card
}

enum BotFactory {
    static func make(difficulty: BotDifficulty) -> any BotStrategy {
        switch difficulty {
        case .beginner: BeginnerBot()
        case .intermediate: IntermediateBot()
        case .advanced: AdvancedBot()
        }
    }
}
