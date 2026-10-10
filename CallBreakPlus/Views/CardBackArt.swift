import SwiftUI

extension CardBack {
    /// The back's ground, a diagonal gradient from top leading to bottom trailing.
    /// The bots' compact fans on their seat plates show this alone.
    var colors: [Color] {
        switch self {
        case .blue:
            [Color(red: 0.12, green: 0.52, blue: 0.95), Color(red: 0.02, green: 0.22, blue: 0.56)]
        case .red:
            [Color(red: 0.90, green: 0.22, blue: 0.16), Color(red: 0.46, green: 0.06, blue: 0.07)]
        case .dhaka:
            [Color(red: 0.64, green: 0.34, blue: 0.10), Color(red: 0.43, green: 0.15, blue: 0.10), Color(red: 0.19, green: 0.10, blue: 0.08)]
        case .mandala:
            [Color(red: 0.43, green: 0.24, blue: 0.65), Color(red: 0.19, green: 0.09, blue: 0.34)]
        case .paisley:
            [Color(red: 0.04, green: 0.49, blue: 0.48), Color(red: 0.02, green: 0.22, blue: 0.28)]
        case .lokta:
            [Color(red: 0.88, green: 0.75, blue: 0.52), Color(red: 0.72, green: 0.55, blue: 0.33)]
        case .rangoli:
            [Color(red: 0.43, green: 0.08, blue: 0.32), Color(red: 0.20, green: 0.03, blue: 0.20)]
        case .goldLeaf:
            [Color(red: 0.08, green: 0.22, blue: 0.15), Color(red: 0.02, green: 0.07, blue: 0.05)]
        }
    }
}

/// The pattern drawn over a back's ground, inside the card's white border.
struct CardBackPattern: View {
    let back: CardBack

    var body: some View {
        GeometryReader { geo in
            switch back {
            case .blue:
                blue(in: geo.size)
            case .red:
                red(in: geo.size)
            case .dhaka:
                dhaka(in: geo.size)
            case .mandala:
                mandala(in: geo.size)
            case .paisley:
                paisley(in: geo.size)
            case .lokta:
                lokta(in: geo.size)
            case .rangoli:
                rangoli(in: geo.size)
            case .goldLeaf:
                goldLeaf(in: geo.size)
            }
        }
        .accessibilityHidden(true)
    }

    private func blue(in size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        return Path { path in
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

    private func red(in size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        return Path { path in
            path.move(to: CGPoint(x: w / 2, y: 8))
            path.addLine(to: CGPoint(x: w - 8, y: h / 2))
            path.addLine(to: CGPoint(x: w / 2, y: h - 8))
            path.addLine(to: CGPoint(x: 8, y: h / 2))
            path.closeSubpath()
        }
        .stroke(Color.white.opacity(0.5), lineWidth: 1)
    }

    private func dhaka(in size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let ochre = Color(red: 0.96, green: 0.70, blue: 0.30)
        return ZStack {
            Path { path in
                for row in 0..<3 {
                    let y = h * (0.25 + CGFloat(row) * 0.25)
                    path.addRect(CGRect(x: w * 0.10, y: y - h * 0.095, width: w * 0.80, height: h * 0.19))
                }
            }
            .fill(Color(red: 0.16, green: 0.08, blue: 0.07))

            Path { path in
                for row in 0..<3 {
                    for column in 0..<2 {
                        let x = w * (0.29 + CGFloat(column) * 0.42)
                        let y = h * (0.25 + CGFloat(row) * 0.25)
                        let dx = w * 0.055
                        let dy = h * 0.029
                        path.move(to: CGPoint(x: x - dx, y: y - 3 * dy))
                        let steps: [(CGFloat, CGFloat)] = [
                            (1, -3), (1, -2), (2, -2), (2, -1), (3, -1),
                            (3, 1), (2, 1), (2, 2), (1, 2), (1, 3),
                            (-1, 3), (-1, 2), (-2, 2), (-2, 1), (-3, 1),
                            (-3, -1), (-2, -1), (-2, -2), (-1, -2),
                        ]
                        for (a, b) in steps {
                            path.addLine(to: CGPoint(x: x + a * dx, y: y + b * dy))
                        }
                        path.closeSubpath()
                    }
                }
            }
            .fill(ochre)

            Path { path in
                for row in 0..<3 {
                    for column in 0..<2 {
                        let x = w * (0.29 + CGFloat(column) * 0.42)
                        let y = h * (0.25 + CGFloat(row) * 0.25)
                        path.move(to: CGPoint(x: x, y: y - h * 0.035))
                        path.addLine(to: CGPoint(x: x + w * 0.065, y: y))
                        path.addLine(to: CGPoint(x: x, y: y + h * 0.035))
                        path.addLine(to: CGPoint(x: x - w * 0.065, y: y))
                        path.closeSubpath()
                    }
                }
            }
            .fill(Color(red: 0.58, green: 0.13, blue: 0.10))

            Path { path in
                for row in 0..<4 {
                    let y = h * (0.125 + CGFloat(row) * 0.25)
                    let direction: CGFloat = row < 2 ? 1 : -1
                    path.move(to: CGPoint(x: w * 0.10, y: y - direction * h * 0.01))
                    for step in 1...8 {
                        path.addLine(to: CGPoint(x: w * (0.10 + CGFloat(step) * 0.10),
                                                y: y + direction * h * (step.isMultiple(of: 2) ? -0.01 : 0.01)))
                    }
                }
            }
            .stroke(Color(red: 1.0, green: 0.88, blue: 0.65), lineWidth: 1.5)
        }
    }

    private func mandala(in size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let center = CGPoint(x: w / 2, y: h / 2)
        let radius = w * 0.32
        return ZStack {
            Path { path in
                for petal in 0..<8 {
                    let angle = CGFloat(petal) * .pi / 4
                    let ux = cos(angle)
                    let uy = sin(angle)
                    let root = CGPoint(x: center.x + ux * radius * 0.30, y: center.y + uy * radius * 0.30)
                    let tip = CGPoint(x: center.x + ux * radius, y: center.y + uy * radius)
                    path.move(to: root)
                    path.addQuadCurve(to: tip, control: CGPoint(
                        x: center.x + ux * radius * 0.70 - uy * radius * 0.39,
                        y: center.y + uy * radius * 0.70 + ux * radius * 0.39))
                    path.addQuadCurve(to: root, control: CGPoint(
                        x: center.x + ux * radius * 0.70 + uy * radius * 0.39,
                        y: center.y + uy * radius * 0.70 - ux * radius * 0.39))
                    path.closeSubpath()
                }
            }
            .stroke(Color(red: 0.98, green: 0.89, blue: 0.76), lineWidth: 1.8)

            Path { path in
                path.addRoundedRect(in: CGRect(x: w * 0.11, y: h * 0.08, width: w * 0.78, height: h * 0.84),
                                    cornerSize: CGSize(width: w * 0.12, height: w * 0.12))
                for r in [w * 0.105, w * 0.36] {
                    path.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
                }
            }
            .stroke(Color(red: 0.96, green: 0.71, blue: 0.40), lineWidth: 1.3)

            Path { path in
                for y in [h * 0.19, h * 0.81] {
                    path.move(to: CGPoint(x: w * 0.50, y: y - h * 0.045))
                    path.addLine(to: CGPoint(x: w * 0.57, y: y))
                    path.addLine(to: CGPoint(x: w * 0.50, y: y + h * 0.045))
                    path.addLine(to: CGPoint(x: w * 0.43, y: y))
                    path.closeSubpath()
                }
            }
            .fill(Color(red: 0.98, green: 0.89, blue: 0.76))
        }
    }

    private func paisley(in size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let cream = Color(red: 0.96, green: 0.85, blue: 0.61)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: w * x, y: h * y)
        }
        return ZStack {
            Path { path in
                path.addRoundedRect(in: CGRect(x: w * 0.11, y: h * 0.08, width: w * 0.78, height: h * 0.84),
                                    cornerSize: CGSize(width: w * 0.13, height: w * 0.13))
            }
            .stroke(cream.opacity(0.85), lineWidth: 1.4)

            Path { path in
                path.move(to: point(0.61, 0.32))
                path.addCurve(to: point(0.72, 0.19), control1: point(0.76, 0.31), control2: point(0.80, 0.23))
                path.addCurve(to: point(0.47, 0.22), control1: point(0.65, 0.13), control2: point(0.53, 0.16))
                path.addCurve(to: point(0.23, 0.61), control1: point(0.33, 0.34), control2: point(0.21, 0.44))
                path.addCurve(to: point(0.49, 0.82), control1: point(0.24, 0.75), control2: point(0.35, 0.82))
                path.addCurve(to: point(0.77, 0.61), control1: point(0.66, 0.82), control2: point(0.78, 0.73))
                path.addCurve(to: point(0.60, 0.39), control1: point(0.76, 0.50), control2: point(0.62, 0.46))
                path.addQuadCurve(to: point(0.61, 0.32), control: point(0.56, 0.32))
                path.closeSubpath()
            }
            .fill(cream)

            Path { path in
                path.move(to: point(0.49, 0.35))
                path.addCurve(to: point(0.33, 0.60), control1: point(0.41, 0.44), control2: point(0.31, 0.51))
                path.addCurve(to: point(0.49, 0.73), control1: point(0.34, 0.69), control2: point(0.41, 0.73))
                path.addCurve(to: point(0.66, 0.61), control1: point(0.59, 0.73), control2: point(0.67, 0.68))
                path.addCurve(to: point(0.49, 0.35), control1: point(0.65, 0.52), control2: point(0.50, 0.49))
                path.closeSubpath()
            }
            .stroke(Color(red: 0.08, green: 0.32, blue: 0.34),
                    style: StrokeStyle(lineWidth: w * 0.025, lineCap: .round, lineJoin: .round))
        }
    }

    private func lokta(in size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let ink = Color(red: 0.38, green: 0.20, blue: 0.10)
        return ZStack {
            Path { path in
                let fibers: [(CGFloat, CGFloat)] = [
                    (0.24, 0.23), (0.48, 0.19), (0.68, 0.28), (0.36, 0.36),
                    (0.60, 0.43), (0.23, 0.49), (0.44, 0.57), (0.69, 0.60),
                ]
                for (x, y) in fibers {
                    for turn in 0..<2 {
                        let a = turn == 0 ? x : 1 - x
                        let b = turn == 0 ? y : 1 - y
                        let direction: CGFloat = turn == 0 ? 1 : -1
                        path.move(to: CGPoint(x: w * a, y: h * b))
                        path.addQuadCurve(to: CGPoint(x: w * (a + direction * 0.035), y: h * (b + direction * 0.065)),
                                          control: CGPoint(x: w * (a - direction * 0.018), y: h * (b + direction * 0.03)))
                    }
                }
            }
            .stroke(ink.opacity(0.19), style: StrokeStyle(lineWidth: 1, lineCap: .round))

            Path { path in
                path.addRect(CGRect(x: w * 0.13, y: h * 0.10, width: w * 0.74, height: h * 0.80))
                path.move(to: CGPoint(x: w * 0.13, y: h * 0.21))
                path.addLine(to: CGPoint(x: w * 0.87, y: h * 0.21))
                path.move(to: CGPoint(x: w * 0.13, y: h * 0.79))
                path.addLine(to: CGPoint(x: w * 0.87, y: h * 0.79))
            }
            .stroke(ink.opacity(0.85), lineWidth: 1.4)

            Path { path in
                for y in [h * 0.155, h * 0.845] {
                    for column in 0..<5 {
                        let x = w * (0.22 + CGFloat(column) * 0.14)
                        path.move(to: CGPoint(x: x, y: y - h * 0.035))
                        path.addLine(to: CGPoint(x: x + w * 0.045, y: y))
                        path.addLine(to: CGPoint(x: x, y: y + h * 0.035))
                        path.addLine(to: CGPoint(x: x - w * 0.045, y: y))
                        path.closeSubpath()
                    }
                }
            }
            .fill(ink)
        }
    }

    private func rangoli(in size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        return ZStack {
            Path { path in
                for row in 0..<3 {
                    for column in 0..<2 {
                        let x = w * (0.34 + CGFloat(column) * 0.32)
                        let y = h * (0.28 + CGFloat(row) * 0.22)
                        path.move(to: CGPoint(x: x, y: y - h * 0.11))
                        path.addQuadCurve(to: CGPoint(x: x + w * 0.16, y: y), control: CGPoint(x: x + w * 0.035, y: y - h * 0.025))
                        path.addQuadCurve(to: CGPoint(x: x, y: y + h * 0.11), control: CGPoint(x: x + w * 0.035, y: y + h * 0.025))
                        path.addQuadCurve(to: CGPoint(x: x - w * 0.16, y: y), control: CGPoint(x: x - w * 0.035, y: y + h * 0.025))
                        path.addQuadCurve(to: CGPoint(x: x, y: y - h * 0.11), control: CGPoint(x: x - w * 0.035, y: y - h * 0.025))
                        path.closeSubpath()
                    }
                }
            }
            .stroke(Color(red: 0.35, green: 0.89, blue: 0.82), style: StrokeStyle(lineWidth: 1.8, lineJoin: .round))

            Path { path in
                path.move(to: CGPoint(x: w * 0.50, y: h * 0.10))
                path.addQuadCurve(to: CGPoint(x: w * 0.89, y: h * 0.50), control: CGPoint(x: w * 0.88, y: h * 0.20))
                path.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.90), control: CGPoint(x: w * 0.88, y: h * 0.80))
                path.addQuadCurve(to: CGPoint(x: w * 0.11, y: h * 0.50), control: CGPoint(x: w * 0.12, y: h * 0.80))
                path.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.10), control: CGPoint(x: w * 0.12, y: h * 0.20))
                path.closeSubpath()
            }
            .stroke(Color(red: 1.0, green: 0.55, blue: 0.40), lineWidth: 1.5)

            Path { path in
                let diameter = w * 0.052
                for row in 0..<3 {
                    for column in 0..<2 {
                        let x = w * (0.34 + CGFloat(column) * 0.32)
                        let y = h * (0.28 + CGFloat(row) * 0.22)
                        path.addEllipse(in: CGRect(x: x - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter))
                    }
                }
                for y in [h * 0.12, h * 0.88] {
                    path.addEllipse(in: CGRect(x: w * 0.50 - diameter / 2, y: y - diameter / 2, width: diameter, height: diameter))
                }
            }
            .fill(Color(red: 1.0, green: 0.86, blue: 0.42))
        }
    }

    private func goldLeaf(in size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let gold = LinearGradient(colors: [
            Color(red: 0.69, green: 0.43, blue: 0.12),
            Color(red: 1.0, green: 0.88, blue: 0.49),
            Color(red: 0.79, green: 0.56, blue: 0.19),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
        return ZStack {
            Path { path in
                path.addRoundedRect(in: CGRect(x: w * 0.11, y: h * 0.08, width: w * 0.78, height: h * 0.84),
                                    cornerSize: CGSize(width: w * 0.04, height: w * 0.04))
                for right in [false, true] {
                    for bottom in [false, true] {
                        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                            CGPoint(x: w * (right ? 1 - x : x), y: h * (bottom ? 1 - y : y))
                        }
                        path.move(to: point(0.18, 0.32))
                        path.addQuadCurve(to: point(0.43, 0.14), control: point(0.18, 0.15))
                    }
                }
            }
            .stroke(gold, style: StrokeStyle(lineWidth: 1.2, lineCap: .round))

            Path { path in
                for right in [false, true] {
                    for bottom in [false, true] {
                        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                            CGPoint(x: w * (right ? 1 - x : x), y: h * (bottom ? 1 - y : y))
                        }
                        path.move(to: point(0.21, 0.25))
                        path.addQuadCurve(to: point(0.18, 0.14), control: point(0.13, 0.20))
                        path.addQuadCurve(to: point(0.21, 0.25), control: point(0.29, 0.18))
                        path.closeSubpath()
                        path.move(to: point(0.24, 0.20))
                        path.addQuadCurve(to: point(0.42, 0.21), control: point(0.34, 0.16))
                        path.addQuadCurve(to: point(0.24, 0.20), control: point(0.32, 0.27))
                        path.closeSubpath()
                    }
                }
            }
            .fill(gold)

            Path { path in
                path.move(to: CGPoint(x: w * 0.50, y: h * 0.38))
                path.addLine(to: CGPoint(x: w * 0.61, y: h * 0.50))
                path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.62))
                path.addLine(to: CGPoint(x: w * 0.39, y: h * 0.50))
                path.closeSubpath()
            }
            .stroke(gold, lineWidth: 1.5)
        }
    }
}
