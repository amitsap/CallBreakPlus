import CoreGraphics

/// Every table anchor, in the coordinates of `GameTableView`'s `GeometryReader`.
/// That reader's frame already is the safe area, so no anchor adds an inset.
struct TableLayout {
    let size: CGSize

    static let bottomAreaHeight: CGFloat = 97
    static let bidTrayHeight: CGFloat = 166
    static let bidTrayWidth: CGFloat = 420
    static let handVerticalLift: CGFloat = 18
    static let chromeInset: CGFloat = 8
    static let chromeTop: CGFloat = 8
    static let chromeRowHeight: CGFloat = 44
    static let statusPillMaxWidth: CGFloat = 180
    static let standingsChipMaxWidth: CGFloat = 150
    static let seatPlateHeight: CGFloat = 46
    /// A plate with an eight-pip call meter, the widest a plate gets.
    static let seatPlateMaxWidth: CGFloat = 160
    /// A plate with a three-pip call meter; side seats are centred for this width.
    static let typicalSeatPlateWidth: CGFloat = 94
    /// From the safe edge to a side plate's outer edge. Wider plates grow toward the trick.
    static let sideSeatInset: CGFloat = 26
    static let restingTrickCardScale: CGFloat = 0.92
    static let humanTrickCardScale: CGFloat = 0.98
    /// The printed direction ring around the trick.
    static let directionRingRadii = CGSize(width: 176, height: 106)

    var topSeatCenter: CGPoint { CGPoint(x: size.width / 2, y: 58) }
    var topSeatBottom: CGFloat { topSeatCenter.y + Self.seatPlateHeight / 2 }

    var bottomAreaCenterY: CGFloat { size.height + 14 - Self.bottomAreaHeight / 2 }
    var handWidth: CGFloat { min(size.width - 104, 710) }
    var handTop: CGFloat { bottomAreaCenterY - Self.bottomAreaHeight / 2 - Self.handVerticalLift }

    /// Center of the trick area, where played cards gather: midway between the
    /// top seat and the hand, so the top and your trick cards clear both equally.
    var trickCenter: CGPoint { CGPoint(x: size.width / 2, y: (topSeatBottom + handTop) / 2) }

    var leftSeatCenter: CGPoint {
        CGPoint(x: Self.sideSeatInset + Self.typicalSeatPlateWidth / 2, y: trickCenter.y)
    }
    var rightSeatCenter: CGPoint {
        CGPoint(x: size.width - Self.sideSeatInset - Self.typicalSeatPlateWidth / 2, y: trickCenter.y)
    }
    /// Where a side plate's frame, `seatPlateMaxWidth` wide, is centred; the
    /// plate is aligned to the frame's outer edge inside it.
    var leftSeatFrameCenterX: CGFloat { Self.sideSeatInset + Self.seatPlateMaxWidth / 2 }
    var rightSeatFrameCenterX: CGFloat { size.width - Self.sideSeatInset - Self.seatPlateMaxWidth / 2 }

    var toastCenter: CGPoint { CGPoint(x: size.width / 2, y: size.height - 128) }

    var chromeCenterY: CGFloat { Self.chromeTop + Self.chromeRowHeight / 2 }

    /// Centered between the top seat and the hand, with 8 pt and 12 pt margins.
    var bidTrayCenterY: CGFloat {
        let trayHalfHeight = Self.bidTrayHeight / 2
        let minimumCenter = topSeatBottom + 8 + trayHalfHeight
        let maximumCenter = handTop - 12 - trayHalfHeight
        return (minimumCenter + maximumCenter) / 2
    }

    /// Offset from `trickCenter` of each seat's played card.
    static func trickCardOffset(for seat: Seat) -> CGSize {
        switch seat {
        case .bottom: CGSize(width: 0, height: 50)
        case .top: CGSize(width: 0, height: -50)
        case .left: CGSize(width: -84, height: 0)
        case .right: CGSize(width: 84, height: 0)
        }
    }

    /// Offset from `trickCenter` that a won trick slides toward.
    static func collectOffset(for seat: Seat) -> CGSize {
        switch seat {
        case .bottom: CGSize(width: 0, height: 150)
        case .top: CGSize(width: 0, height: -125)
        case .left: CGSize(width: -260, height: 0)
        case .right: CGSize(width: 260, height: 0)
        }
    }

    /// Offset from `trickCenter` at which a dealt card lands on its seat.
    func dealOffset(for seat: Seat) -> CGSize {
        let target: CGPoint = switch seat {
        case .bottom: CGPoint(x: size.width / 2, y: bottomAreaCenterY - Self.handVerticalLift)
        case .right: rightSeatCenter
        case .top: topSeatCenter
        case .left: leftSeatCenter
        }
        return CGSize(width: target.x - trickCenter.x, height: target.y - trickCenter.y)
    }
}

/// Your hand held as a real fan: every card turns about one pivot below the
/// hand by the same step, so each shows the same strip and the overlaps match
/// from end to end. Offsets are from the hand's centre; angles are clockwise.
struct HandFan {
    static let scale: CGFloat = 0.9
    /// Between neighbouring card centres, at the middle of the fan.
    static let cardSpacing: CGFloat = 44
    static let degreesPerCard: Double = 2
    /// How far a playable card slides out of the fan, along its own axis.
    static let playableLift: CGFloat = 10
    /// From the pivot to every card's centre.
    static let radius: CGFloat = cardSpacing / sin(degreesPerCard * .pi / 180)

    let count: Int

    /// Positions from the middle of the hand: negative to the left.
    private func position(of index: Int) -> Double {
        Double(index) - Double(count - 1) / 2
    }

    func angle(at index: Int) -> Double {
        position(of: index) * Self.degreesPerCard
    }

    func offset(at index: Int, lifted: Bool) -> CGSize {
        let radians = angle(at: index) * .pi / 180
        let lift = lifted ? Self.playableLift : 0
        // A card's own "up" is (sin θ, −cos θ) once it has turned by θ.
        return CGSize(
            width: (Self.radius + lift) * sin(radians),
            height: Self.radius * (1 - cos(radians)) - lift * cos(radians)
        )
    }
}
