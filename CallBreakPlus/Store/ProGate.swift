/// Resolves stored preferences to the values a game actually uses, given Pro status.
/// Stored preferences keep the player's choice; without Pro the free default applies,
/// so a refund or lost Family Sharing falls back without rewriting anything, and
/// buying again restores the choice.
enum ProGate {
    static let freeRoundCount = 5
    static let freeThokThreshold = 8

    /// A nil `thokThreshold` means Thok is off, which stays free to toggle.
    static func rules(base: RuleSet, roundCount: Int, thokThreshold: Int?, hasPro: Bool) -> RuleSet {
        var rules = base
        rules.roundCount = hasPro ? roundCount : freeRoundCount
        rules.instantWinBid = thokThreshold.map { hasPro ? $0 : freeThokThreshold }
        return rules
    }

    /// A Pro back without Pro shows Blue, the free default.
    static func cardBack(selected: CardBack, hasPro: Bool) -> CardBack {
        selected.isPro && !hasPro ? .blue : selected
    }

    /// A Pro theme without Pro shows Classic, the free default.
    static func tableTheme(selected: TableThemeChoice, hasPro: Bool) -> TableThemeChoice {
        selected.isPro && !hasPro ? .classic : selected
    }
}
