import SwiftUI

struct CardView: View {
    let card: Card
    let isFaceUp: Bool
    let isLegal: Bool
    let isInteractive: Bool
    let cardBack: CardBack
    let highContrast: Bool

    init(card: Card, isFaceUp: Bool = true, isLegal: Bool = true, isInteractive: Bool = false, cardBack: CardBack = .blue, highContrast: Bool = false) {
        self.card = card
        self.isFaceUp = isFaceUp
        self.isLegal = isLegal
        self.isInteractive = isInteractive
        self.cardBack = cardBack
        self.highContrast = highContrast
    }

    static let width: CGFloat = 66
    static let height: CGFloat = 92
    static let cornerRadius: CGFloat = 6

    private var suitColor: Color {
        switch card.suit {
        case .hearts, .diamonds: .red
        case .clubs, .spades: .black
        }
    }

    private var accessibilityLabel: String {
        "\(card.rank.symbol) of \(card.suit.name)"
    }

    private var accessibilityHint: String {
        guard isInteractive else { return "" }
        return isLegal ? "Tap to play this card" : "Not playable in the current trick"
    }

    var body: some View {
        if isFaceUp {
            faceView
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(isInteractive && isLegal ? .isButton : [])
                .accessibilityHint(accessibilityHint)
        } else {
            backView
                .accessibilityLabel("Card back")
                .accessibilityHidden(true)
        }
    }

    private var faceView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.99, blue: 0.94), Color(red: 0.94, green: 0.91, blue: 0.83)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .strokeBorder(highContrast ? Color.black : Color(red: 0.48, green: 0.34, blue: 0.18).opacity(0.35), lineWidth: highContrast ? 2 : 1)
            RoundedRectangle(cornerRadius: Self.cornerRadius - 2)
                .strokeBorder(suitColor.opacity(0.18), lineWidth: 1)
                .padding(3)

            centerArtwork
                .padding(.horizontal, 10)
                .padding(.vertical, 13)

            VStack {
                HStack {
                    cornerMark(rotated: false)
                    Spacer()
                }
                Spacer()
                HStack {
                    Spacer()
                    cornerMark(rotated: true)
                }
            }
            .padding(4)
        }
        .frame(width: Self.width, height: Self.height)
        // A shade rather than transparency: the same on every felt and both
        // suit colours, and no neighbouring card shows through.
        .overlay {
            if !isLegal {
                RoundedRectangle(cornerRadius: Self.cornerRadius)
                    .fill(.black.opacity(highContrast ? 0.55 : 0.35))
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
    }

    private func cornerMark(rotated: Bool) -> some View {
        VStack(spacing: -2) {
            Text(card.rank.symbol)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .minimumScaleFactor(0.7)
            Text(card.suit.symbol)
                .font(.system(size: 11, weight: .semibold))
        }
        .frame(width: 16)
        .foregroundColor(suitColor)
        .rotationEffect(.degrees(rotated ? 180 : 0))
    }

    @ViewBuilder
    private var centerArtwork: some View {
        VStack(spacing: 4) {
            Text(card.suit.symbol)
                .font(.system(size: card.rank == .ace ? 30 : 24, weight: .semibold))
                .shadow(color: suitColor.opacity(0.18), radius: 1, y: 1)
            Text(card.rank.symbol)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.75)
        }
        .foregroundColor(suitColor)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var backView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .fill(Color.white)
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)

            RoundedRectangle(cornerRadius: Self.cornerRadius - 2)
                .fill(LinearGradient(colors: cardBack.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .padding(3)
                .overlay { CardBackPattern(back: cardBack) }
        }
        .frame(width: Self.width, height: Self.height)
    }
}

#Preview("Card Face") {
    HStack(spacing: 10) {
        CardView(card: Card(suit: .spades, rank: .ace))
        CardView(card: Card(suit: .hearts, rank: .king))
        CardView(card: Card(suit: .diamonds, rank: .queen))
        CardView(card: Card(suit: .clubs, rank: .jack))
    }
    .padding()
    .background(Color.green.opacity(0.3))
}

#Preview("Card Back") {
    HStack(spacing: 10) {
        ForEach(CardBack.allCases) { back in
            CardView(card: Card(suit: .spades, rank: .ace), isFaceUp: false, cardBack: back)
        }
    }
    .padding()
    .background(Color.green.opacity(0.3))
}
