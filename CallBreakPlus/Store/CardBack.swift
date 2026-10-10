/// A card back the player can choose. The raw value is what `settings.cardBack`
/// stores: Blue and Red keep 0 and 1 from before Pro, so stored choices survive,
/// and Pro backs take 2 and up. Never renumber a case.
enum CardBack: Int, CaseIterable, Identifiable, Sendable {
    case blue = 0
    case red = 1
    case dhaka = 2
    case mandala = 3
    case paisley = 4
    case lokta = 5
    case rangoli = 6
    case goldLeaf = 7

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .blue: "Blue"
        case .red: "Red"
        case .dhaka: "Dhaka"
        case .mandala: "Mandala"
        case .paisley: "Paisley"
        case .lokta: "Lokta"
        case .rangoli: "Rangoli"
        case .goldLeaf: "Gold Leaf"
        }
    }

    var isPro: Bool {
        switch self {
        case .blue, .red: false
        case .dhaka, .mandala, .paisley, .lokta, .rangoli, .goldLeaf: true
        }
    }

    /// The stored value, or Blue for one this build doesn't know.
    init(stored: Int) {
        self = CardBack(rawValue: stored) ?? .blue
    }
}
