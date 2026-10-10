/// A table theme the player can choose. The raw value is what `settings.tableTheme`
/// stores; Classic is 0 and free, the rest are Pro. Never renumber a case.
enum TableThemeChoice: Int, CaseIterable, Identifiable, Sendable {
    case classic = 0
    case royal = 1
    case maroon = 2
    case midnight = 3

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .classic: "Classic"
        case .royal: "Royal"
        case .maroon: "Maroon"
        case .midnight: "Midnight"
        }
    }

    var isPro: Bool { self != .classic }

    /// The stored value, or Classic for one this build doesn't know.
    init(stored: Int) {
        self = TableThemeChoice(rawValue: stored) ?? .classic
    }
}
