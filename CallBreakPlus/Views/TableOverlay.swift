import SwiftUI

enum TablePalette {
    static let paper = Color(red: 0.99, green: 0.93, blue: 0.76)
    static let ink = Color(red: 0.25, green: 0.10, blue: 0.04)
    static let faded = Color(red: 0.55, green: 0.35, blue: 0.18)
    static let accentGreen = Color(red: 0.10, green: 0.56, blue: 0.20)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.24)
    static let scrim = Color.black.opacity(0.42)
    static let woodButton = Color(red: 0.50, green: 0.30, blue: 0.12)
    static let destructiveRed = Color(red: 0.80, green: 0.18, blue: 0.14)
    static let rimBrown = Color(red: 0.48, green: 0.20, blue: 0.09)
    static let cardRuled = Color(red: 0.82, green: 0.62, blue: 0.36)
    static let bidBrown = Color(red: 0.34, green: 0.14, blue: 0.07)
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

struct OverlayUtilityButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    init(_ title: String, icon: String, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                Text(title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
            .foregroundStyle(TablePalette.ink.opacity(0.78))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(TablePalette.ink.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
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
