import Foundation

enum Suit: Int, CaseIterable, Comparable, Hashable, Sendable {
    case diamonds = 0
    case clubs = 1
    case hearts = 2
    case spades = 3

    static func < (lhs: Suit, rhs: Suit) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var symbol: String {
        switch self {
        case .clubs: "♣"
        case .diamonds: "♦"
        case .hearts: "♥"
        case .spades: "♠"
        }
    }

    var name: String {
        switch self {
        case .clubs: "Clubs"
        case .diamonds: "Diamonds"
        case .hearts: "Hearts"
        case .spades: "Spades"
        }
    }
}

enum Rank: Int, CaseIterable, Comparable, Hashable, Sendable {
    case two = 2
    case three = 3
    case four = 4
    case five = 5
    case six = 6
    case seven = 7
    case eight = 8
    case nine = 9
    case ten = 10
    case jack = 11
    case queen = 12
    case king = 13
    case ace = 14

    static func < (lhs: Rank, rhs: Rank) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var symbol: String {
        switch self {
        case .two: "2"
        case .three: "3"
        case .four: "4"
        case .five: "5"
        case .six: "6"
        case .seven: "7"
        case .eight: "8"
        case .nine: "9"
        case .ten: "10"
        case .jack: "J"
        case .queen: "Q"
        case .king: "K"
        case .ace: "A"
        }
    }
}

struct Card: Hashable, Comparable, Sendable {
    let suit: Suit
    let rank: Rank

    static func < (lhs: Card, rhs: Card) -> Bool {
        if lhs.suit != rhs.suit {
            return lhs.suit < rhs.suit
        }
        return lhs.rank < rhs.rank
    }

    var description: String {
        "\(rank.symbol)\(suit.symbol)"
    }
}

enum Seat: Int, CaseIterable, Hashable, Sendable {
    case bottom = 0
    case right = 1
    case top = 2
    case left = 3

    func next() -> Seat {
        Seat(rawValue: (rawValue + 1) % 4)!
    }

    var name: String {
        switch self {
        case .bottom: "You"
        case .right: "Ekka"
        case .top: "Raja"
        case .left: "Rani"
        }
    }
}

struct TrickPlay: Hashable, Sendable {
    let seat: Seat
    let card: Card
}

struct Trick: Sendable {
    let ledSuit: Suit
    var plays: [TrickPlay]

    var isComplete: Bool { plays.count == 4 }

    var highestOfLedSuit: Card? {
        plays.filter { $0.card.suit == ledSuit }.max(by: { $0.card.rank < $1.card.rank })?.card
    }

    var highestSpade: Card? {
        plays.filter { $0.card.suit == .spades }.max(by: { $0.card.rank < $1.card.rank })?.card
    }

    init(firstPlay: TrickPlay) {
        self.ledSuit = firstPlay.card.suit
        self.plays = [firstPlay]
    }

    init(ledSuit: Suit, plays: [TrickPlay]) {
        self.ledSuit = ledSuit
        self.plays = plays
    }
}

struct Deck {
    static let fullDeck: [Card] = {
        Suit.allCases.flatMap { suit in
            Rank.allCases.map { rank in
                Card(suit: suit, rank: rank)
            }
        }
    }()

    static func shuffled<R: RandomNumberGenerator>(using rng: inout R) -> [Card] {
        fullDeck.shuffled(using: &rng)
    }

    static func deal<R: RandomNumberGenerator>(using rng: inout R) -> [[Card]] {
        let cards = shuffled(using: &rng)
        return (0..<4).map { i in
            Array(cards[(i * 13)..<((i + 1) * 13)]).sorted()
        }
    }
}
