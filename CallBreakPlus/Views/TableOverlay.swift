import SwiftUI

enum TablePalette {
    static let paper = Color(red: 0.99, green: 0.93, blue: 0.76)
    /// A panel's sidebar, a shade under the paper.
    static let paperShade = Color(red: 0.95, green: 0.87, blue: 0.67)
    static let ink = Color(red: 0.25, green: 0.10, blue: 0.04)
    static let faded = Color(red: 0.55, green: 0.35, blue: 0.18)
    static let accentGreen = Color(red: 0.10, green: 0.56, blue: 0.20)
    /// Green and gold for text on paper, at least 4.5:1 against it.
    static let paperGreen = Color(red: 0.05, green: 0.42, blue: 0.14)
    static let paperGold = Color(red: 0.55, green: 0.36, blue: 0.0)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.24)
    /// A call that is made, on the felt.
    static let madeGreen = Color(red: 0.24, green: 0.86, blue: 0.52)
    static let scrim = Color.black.opacity(0.42)
    static let woodButton = Color(red: 0.50, green: 0.30, blue: 0.12)
    static let destructiveRed = Color(red: 0.80, green: 0.18, blue: 0.14)
    static let rimBrown = Color(red: 0.48, green: 0.20, blue: 0.09)
    static let cardRuled = Color(red: 0.82, green: 0.62, blue: 0.36)
    static let bidBrown = Color(red: 0.34, green: 0.14, blue: 0.07)
    static let medalGold = Color(red: 0.86, green: 0.62, blue: 0.08)
    static let medalSilver = Color(red: 0.62, green: 0.66, blue: 0.72)
    static let medalBronze = Color(red: 0.72, green: 0.42, blue: 0.20)
    static let thokOrange = Color(red: 0.82, green: 0.38, blue: 0.12)
}

struct TableOverlayCard<Content: View>: View {
    let width: CGFloat?
    let insets: EdgeInsets
    let paperOpacity: Double
    @ViewBuilder let content: Content

    init(
        width: CGFloat? = nil,
        insets: EdgeInsets = EdgeInsets(top: 22, leading: 22, bottom: 22, trailing: 22),
        paperOpacity: Double = 1,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.insets = insets
        self.paperOpacity = paperOpacity
        self.content = content()
    }

    var body: some View {
        content
            .padding(insets)
            .frame(width: width)
            .background(TablePalette.paper.opacity(paperOpacity), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(TablePalette.rimBrown.opacity(0.5), lineWidth: 1.5))
            .shadow(color: .black.opacity(0.30), radius: 16, y: 6)
    }
}

struct OverlayHeader: View {
    let icon: String?
    let title: String

    init(icon: String? = nil, title: String) {
        self.icon = icon
        self.title = title
    }

    var body: some View {
        VStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.title2.weight(.black))
                    .foregroundStyle(TablePalette.faded)
            }
            Text(title)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(TablePalette.ink)
        }
    }
}

struct OverlayButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    init(_ title: String, color: Color = TablePalette.accentGreen, action: @escaping () -> Void) {
        self.title = title
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(.white)
                .background(LinearGradient(colors: [color, color.opacity(0.70)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
