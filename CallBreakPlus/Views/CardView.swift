import SwiftUI

struct CardView: View {
    let card: Card
    let isFaceUp: Bool
    let isLegal: Bool
    let cardBackStyle: Int
    let highContrast: Bool

    init(card: Card, isFaceUp: Bool = true, isLegal: Bool = true, cardBackStyle: Int = 0, highContrast: Bool = false) {
        self.card = card
        self.isFaceUp = isFaceUp
        self.isLegal = isLegal
        self.cardBackStyle = cardBackStyle
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

    var body: some View {
        if isFaceUp {
            faceView
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(isLegal ? .isButton : [])
                .accessibilityHint(isLegal ? "Tap to play this card" : "Not playable in the current trick")
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
        .opacity(isLegal ? 1.0 : (highContrast ? 0.45 : 0.72))
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
                .fill(
                    LinearGradient(
                        colors: cardBackStyle == 0
                            ? [Color(red: 0.12, green: 0.52, blue: 0.95), Color(red: 0.02, green: 0.22, blue: 0.56)]
                            : [Color(red: 0.90, green: 0.22, blue: 0.16), Color(red: 0.46, green: 0.06, blue: 0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(3)
                .overlay {
                    if cardBackStyle == 0 {
                        blueBackPattern
                    } else {
                        redBackPattern
                    }
                }
        }
        .frame(width: Self.width, height: Self.height)
    }

    private var blueBackPattern: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                let inset: CGFloat = 8
                path.addRect(CGRect(x: inset, y: inset, width: w - 2 * inset, height: h - 2 * inset))
                path.move(to: CGPoint(x: w / 2, y: inset + 4))
                path.addLine(to: CGPoint(x: w - inset - 4, y: h / 2))
                path.addLine(to: CGPoint(x: w / 2, y: h - inset - 4))
                path.addLine(to: CGPoint(x: inset + 4, y: h / 2))
                path.closeSubpath()
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
        }
    }

    private var redBackPattern: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Path { path in
                path.move(to: CGPoint(x: w / 2, y: 8))
                path.addLine(to: CGPoint(x: w - 8, y: h / 2))
                path.addLine(to: CGPoint(x: w / 2, y: h - 8))
                path.addLine(to: CGPoint(x: 8, y: h / 2))
                path.closeSubpath()
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)
        }
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
        CardView(card: Card(suit: .spades, rank: .ace), isFaceUp: false, cardBackStyle: 0)
        CardView(card: Card(suit: .spades, rank: .ace), isFaceUp: false, cardBackStyle: 1)
    }
    .padding()
    .background(Color.green.opacity(0.3))
}
