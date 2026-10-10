import CoreGraphics
import Testing
@testable import CallBreakPlus

/// Clearances at the safe-area sizes of the reference phones. The 17 Pro size
/// was measured in the simulator (insets 62 / 62 / 20); the Pro Max assumes
/// the same insets on its 956 × 440 screen.
@Suite("Table Layout")
struct TableLayoutTests {
    static let se = CGSize(width: 667, height: 375)
    static let pro = CGSize(width: 750, height: 382)
    static let sizes: [CGSize] = [
        se,
        pro,
        CGSize(width: 832, height: 420),  // iPhone 17 Pro Max
    ]

    /// The invalid-move toast at its widest.
    let toastSize = CGSize(width: 460, height: 31)

    private func cardSize(scale: CGFloat, rotated: Bool) -> CGSize {
        let width = CardView.width * scale
        let height = CardView.height * scale
        return rotated ? CGSize(width: height, height: width) : CGSize(width: width, height: height)
    }

    private func rect(center: CGPoint, size: CGSize) -> CGRect {
        CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    }

    private func trickCardRect(_ layout: TableLayout, seat: Seat) -> CGRect {
        let offset = TableLayout.trickCardOffset(for: seat)
        let center = CGPoint(x: layout.trickCenter.x + offset.width, y: layout.trickCenter.y + offset.height)
        let rotated = seat == .left || seat == .right
        let scale = seat == .bottom ? TableLayout.humanTrickCardScale : TableLayout.restingTrickCardScale
        return rect(center: center, size: cardSize(scale: scale, rotated: rotated))
    }

    /// A side plate at its widest, aligned to its outer edge.
    private func widestSidePlate(_ layout: TableLayout, seat: Seat) -> CGRect {
        let width = TableLayout.seatPlateMaxWidth
        let x = seat == .left ? TableLayout.sideSeatInset : layout.size.width - TableLayout.sideSeatInset - width
        return CGRect(x: x, y: layout.leftSeatCenter.y - TableLayout.seatPlateHeight / 2, width: width, height: TableLayout.seatPlateHeight)
    }

    private func widestTopPlate(_ layout: TableLayout) -> CGRect {
        rect(center: layout.topSeatCenter, size: CGSize(width: TableLayout.seatPlateMaxWidth, height: TableLayout.seatPlateHeight))
    }

    @Test func phase1AnchorsOnThe17Pro() {
        let layout = TableLayout(size: Self.pro)
        // Glass coordinates in the spec, less the 62 pt leading inset.
        #expect(layout.chromeCenterY == 30)
        #expect(layout.topSeatCenter == CGPoint(x: 437 - 62, y: 58))
        #expect(layout.leftSeatCenter.x == CGFloat(135 - 62))
        #expect(layout.rightSeatCenter.x == CGFloat(739 - 62))
        #expect(layout.trickCenter.x == CGFloat(437 - 62))
        #expect(abs(layout.trickCenter.y - 184) <= 4)
    }

    @Test func seAnchorsWhereHeightIsTightest() {
        let layout = TableLayout(size: Self.se)
        #expect(layout.topSeatBottom == 81)
        #expect(layout.handTop == 274)
        #expect(trickCardRect(layout, seat: .top).minY - layout.topSeatBottom >= 3)
        #expect(layout.handTop - trickCardRect(layout, seat: .bottom).maxY >= 1)
    }

    @Test(arguments: sizes)
    func sideSeatsAreSymmetricAndInsideTheFrame(size: CGSize) {
        let layout = TableLayout(size: size)
        #expect(layout.leftSeatCenter.x == size.width - layout.rightSeatCenter.x)
        #expect(layout.leftSeatCenter.y == layout.rightSeatCenter.y)
        #expect(layout.leftSeatFrameCenterX == size.width - layout.rightSeatFrameCenterX)
        #expect(widestSidePlate(layout, seat: .left).minX >= 8)
        #expect(widestSidePlate(layout, seat: .right).maxX <= size.width - 8)
    }

    @Test(arguments: sizes)
    func sideTrickCardsClearTheWidestSidePlates(size: CGSize) {
        let layout = TableLayout(size: size)
        #expect(!trickCardRect(layout, seat: .left).intersects(widestSidePlate(layout, seat: .left)))
        #expect(!trickCardRect(layout, seat: .right).intersects(widestSidePlate(layout, seat: .right)))
    }

    @Test(arguments: sizes)
    func toastClearsTheSideTrickCardsAndTheHand(size: CGSize) {
        let layout = TableLayout(size: size)
        let toast = rect(center: layout.toastCenter, size: toastSize)
        #expect(trickCardRect(layout, seat: .left).maxY + 12 <= toast.minY)
        #expect(trickCardRect(layout, seat: .right).maxY + 12 <= toast.minY)
        #expect(toast.maxY <= layout.handTop)
    }

    @Test(arguments: sizes)
    func bidTraySitsBetweenTopSeatAndHand(size: CGSize) {
        let layout = TableLayout(size: size)
        let halfTray = TableLayout.bidTrayHeight / 2
        #expect(layout.bidTrayCenterY - halfTray >= layout.topSeatBottom + 8)
        #expect(layout.bidTrayCenterY + halfTray <= layout.handTop - 12)
    }

    @Test(arguments: sizes)
    func trickCardsClearTheTopSeatAndTheHand(size: CGSize) {
        let layout = TableLayout(size: size)
        #expect(trickCardRect(layout, seat: .top).minY >= layout.topSeatBottom)
        #expect(trickCardRect(layout, seat: .bottom).maxY <= layout.handTop)
    }

    @Test(arguments: sizes)
    func chromeClearsTheWidestTopPlate(size: CGSize) {
        let layout = TableLayout(size: size)
        let plate = widestTopPlate(layout)
        // Pause button, 10 pt, status pill.
        let leadingEnd = TableLayout.chromeInset + TableLayout.chromeRowHeight + 10 + TableLayout.statusPillMaxWidth
        // Last Trick button, 7 pt, standings chip.
        let trailingStart = size.width - TableLayout.chromeInset - TableLayout.standingsChipMaxWidth - 7 - TableLayout.chromeRowHeight
        #expect(leadingEnd + 8 <= plate.minX)
        #expect(plate.maxX + 8 <= trailingStart)
    }

    @Test(arguments: sizes)
    func directionRingStaysOnTheFelt(size: CGSize) {
        let layout = TableLayout(size: size)
        let radii = TableLayout.directionRingRadii
        #expect(layout.trickCenter.x - radii.width >= widestSidePlate(layout, seat: .left).minX)
        #expect(trickCardRect(layout, seat: .left).minX >= layout.trickCenter.x - radii.width)
    }

    @Test(arguments: sizes)
    func dealtCardsLandOnTheirSeats(size: CGSize) {
        let layout = TableLayout(size: size)
        for (seat, target) in [(Seat.left, layout.leftSeatCenter), (.right, layout.rightSeatCenter), (.top, layout.topSeatCenter)] {
            let offset = layout.dealOffset(for: seat)
            #expect(layout.trickCenter.x + offset.width == target.x)
            #expect(layout.trickCenter.y + offset.height == target.y)
        }
    }

    /// A resting hand card's corner, turned with the card: `x` and `y` are −1
    /// or 1 for left or right and top or bottom.
    private func handCardCorner(_ layout: TableLayout, fan: HandFan, index: Int, x: CGFloat, y: CGFloat) -> CGPoint {
        let offset = fan.offset(at: index, lifted: false)
        let center = CGPoint(
            x: layout.size.width / 2 + offset.width,
            y: layout.bottomAreaCenterY - TableLayout.handVerticalLift + offset.height
        )
        let card = cardSize(scale: HandFan.scale, rotated: false)
        let dx = x * card.width / 2, dy = y * card.height / 2
        let radians = fan.angle(at: index) * .pi / 180
        return CGPoint(
            x: center.x + dx * cos(radians) - dy * sin(radians),
            y: center.y + dx * sin(radians) + dy * cos(radians)
        )
    }

    @Test func handFanIsSymmetricWithAnUprightMiddle() {
        let fan = HandFan(count: 13)
        #expect(fan.angle(at: 6) == 0)
        #expect(fan.offset(at: 6, lifted: false) == .zero)
        #expect(fan.angle(at: 0) == -fan.angle(at: 12))
        let left = fan.offset(at: 0, lifted: false), right = fan.offset(at: 12, lifted: false)
        #expect(abs(left.width + right.width) < 0.001)
        #expect(abs(left.height - right.height) < 0.001)
        // The ends sit lower, on the arc their tilt implies.
        #expect(left.height > 20)
    }

    @Test(arguments: [2, 5, 13])
    func neighbouringHandCardsAreEvenlySpaced(count: Int) {
        let fan = HandFan(count: count)
        let centers = (0..<count).map { fan.offset(at: $0, lifted: false) }
        for (a, b) in zip(centers, centers.dropFirst()) {
            #expect(abs(hypot(b.width - a.width, b.height - a.height) - HandFan.cardSpacing) < 0.1)
        }
    }

    @Test func aPlayableCardSlidesOutwardAlongItsOwnAxis() {
        let fan = HandFan(count: 13)
        for index in [0, 12] {
            let resting = fan.offset(at: index, lifted: false), lifted = fan.offset(at: index, lifted: true)
            let dx = lifted.width - resting.width, dy = lifted.height - resting.height
            #expect(abs(hypot(dx, dy) - HandFan.playableLift) < 0.001)
            #expect(dy < 0)
            // Outward: the left end slides left, the right end right.
            #expect(index == 0 ? dx < 0 : dx > 0)
        }
    }

    @Test(arguments: sizes)
    func aFullHandStaysOnScreenWithEveryIndexVisible(size: CGSize) {
        let layout = TableLayout(size: size)
        let fan = HandFan(count: 13)
        #expect(handCardCorner(layout, fan: fan, index: 0, x: -1, y: -1).x >= TableLayout.chromeInset)
        #expect(handCardCorner(layout, fan: fan, index: 12, x: 1, y: -1).x <= size.width - TableLayout.chromeInset)
        for index in 0..<13 {
            // The top-left index runs about 30 pt down the card.
            #expect(handCardCorner(layout, fan: fan, index: index, x: -1, y: -1).y + 30 <= size.height)
        }
    }
}
