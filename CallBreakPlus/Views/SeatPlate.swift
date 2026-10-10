import SwiftUI

/// A seat's progress on its call: one pip per called trick, gold as tricks
/// land, all green with a tick once the call is made, overtricks as `+n`.
/// Calls above `maxPips` show as numerals.
struct CallMeter: View {
    let bid: Int?
    let won: Int

    static let maxPips = 8

    var body: some View {
        HStack(spacing: 3) {
            if let bid {
                let made = won >= bid
                if bid <= Self.maxPips {
                    HStack(spacing: 2) {
                        ForEach(0..<bid, id: \.self) { index in
                            pip(filled: index < won, made: made)
                        }
                    }
                } else {
                    Text("\(won)/\(bid)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(made ? TablePalette.madeGreen : TablePalette.gold)
                }
                if made {
                    Image(systemName: "checkmark")
                        .font(.system(size: 6.5, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 11, height: 11)
                        .background(TablePalette.accentGreen, in: Circle())
                    if won > bid {
                        Text("+\(won - bid)")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(TablePalette.madeGreen)
                    }
                }
            } else {
                Text("–")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.46))
            }
        }
        .frame(height: 11)
        .animation(.spring(duration: 0.2), value: won)
        .animation(.spring(duration: 0.2), value: bid)
        .accessibilityHidden(true)
    }

    private func pip(filled: Bool, made: Bool) -> some View {
        let fill: Color = made ? TablePalette.madeGreen : (filled ? TablePalette.gold : .clear)
        return Circle()
            .fill(fill)
            .overlay(Circle().strokeBorder(made || filled ? fill : .white.opacity(0.55), lineWidth: 1.3))
            .frame(width: 7, height: 7)
    }
}

/// A bot's seat at the felt edge: avatar, name and call meter on a dark
/// plate, with a small fan of card backs peeking out above it.
struct SeatPlateView: View {
    let name: String
    let seat: Seat
    let bid: Int?
    let tricks: Int
    let isActive: Bool
    let isDealer: Bool
    let count: Int
    let cardBack: CardBack

    var body: some View {
        HStack(spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                SeatAvatar(seat: seat, size: 32)

                if isDealer {
                    Text("D")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(TablePalette.ink)
                        .frame(width: 14, height: 14)
                        .background(TablePalette.gold, in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.65), lineWidth: 1))
                        .offset(x: 3, y: 3)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                CallMeter(bid: bid, won: tricks)
            }
        }
        .padding(.leading, 7)
        .padding(.trailing, 12)
        .frame(height: TableLayout.seatPlateHeight)
        .background(alignment: .topLeading) {
            compactFan
                .frame(width: 40, height: 32)
                .offset(x: 3, y: -20)
        }
        .background(Color.black.opacity(isActive ? 0.56 : 0.46), in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                isActive ? TablePalette.gold : .white.opacity(0.14),
                lineWidth: isActive ? 1.5 : 1
            )
        )
        .fixedSize()
        .frame(maxWidth: TableLayout.seatPlateMaxWidth)
        .shadow(color: isActive ? TablePalette.gold.opacity(0.38) : .clear, radius: isActive ? 8 : 0)
        .scaleEffect(isActive ? 1.03 : 1)
        .animation(.easeInOut(duration: 0.22), value: isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(isDealer ? "dealer, " : "")\(bid.map { "bid \($0)" } ?? "has not bid"), won \(tricks), \(count) cards")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var compactFan: some View {
        let visibleCount = min(count, 3)
        let midpoint = Double(max(visibleCount - 1, 0)) / 2
        return ZStack {
            ForEach(0..<visibleCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: cardBack.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 20, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .strokeBorder(.white.opacity(0.52), lineWidth: 1)
                            .padding(3)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.72), lineWidth: 1))
                    .rotationEffect(.degrees((Double(index) - midpoint) * 11), anchor: .bottom)
                    .offset(x: (CGFloat(index) - CGFloat(midpoint)) * 5)
            }
        }
        .animation(.spring(duration: 0.2), value: count)
        .accessibilityHidden(true)
    }
}

/// A seat's icon in its colour, as on its nameplate.
struct SeatAvatar: View {
    let seat: Seat
    let size: CGFloat

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.4, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(accentColor.opacity(0.92), in: Circle())
            .accessibilityHidden(true)
    }

    private var icon: String {
        switch seat {
        case .bottom: "person.fill"
        case .right: "bolt.fill"
        case .top: "crown.fill"
        case .left: "star.fill"
        }
    }

    private var accentColor: Color {
        switch seat {
        case .bottom: Color(red: 0.10, green: 0.56, blue: 0.94)
        case .top: Color(red: 0.62, green: 0.34, blue: 0.95)
        case .left: Color(red: 0.95, green: 0.48, blue: 0.18)
        case .right: Color(red: 0.13, green: 0.72, blue: 0.36)
        }
    }
}
