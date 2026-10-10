import SwiftUI

/// The table's swappable surfaces: felt, wood and rim. Paper, ink and type
/// stay fixed in `TablePalette` and `TableType`, because legibility is not a
/// theme. Read it from the environment so a later theme can replace it at runtime.
struct TableTheme: Equatable, Sendable {
    /// Felt radial gradient, centre to edge.
    let felt: [Color]
    /// Wood diagonal gradient, top leading to bottom trailing.
    let wood: [Color]
    /// Rim stroke gradient, top to bottom.
    let rim: [Color]

    static let classic = TableTheme(
        felt: [
            Color(red: 0.10, green: 0.46, blue: 0.16),
            Color(red: 0.05, green: 0.28, blue: 0.09),
            Color(red: 0.02, green: 0.16, blue: 0.05),
        ],
        wood: [
            Color(red: 0.42, green: 0.20, blue: 0.08),
            Color(red: 0.72, green: 0.37, blue: 0.12),
            Color(red: 0.50, green: 0.23, blue: 0.08),
        ],
        rim: [
            Color(red: 0.96, green: 0.76, blue: 0.28).opacity(0.55),
            Color(red: 0.35, green: 0.22, blue: 0.08).opacity(0.7),
        ]
    )
}

extension EnvironmentValues {
    @Entry var tableTheme: TableTheme = .classic
}

/// The app's type ramp: six steps, all rounded.
enum TableType {
    /// Screen titles: Paused, a panel's heading.
    static let display = Font.system(size: 26, weight: .black, design: .rounded)
    /// Overlay and section titles.
    static let title = Font.system(size: 20, weight: .black, design: .rounded)
    /// Row titles and buttons.
    static let headline = Font.system(size: 15, weight: .bold, design: .rounded)
    /// Running text.
    static let body = Font.system(size: 13, weight: .semibold, design: .rounded)
    /// Captions under a row title.
    static let caption = Font.system(size: 11, weight: .medium, design: .rounded)
    /// Uppercase kickers over a title; set `.textCase(.uppercase)` and `.kerning(1)`.
    static let kicker = Font.system(size: 11, weight: .heavy, design: .rounded)
}

/// Wood planks with the felt oval inset, the surface under the table and the menu.
struct TableBackground: View {
    @Environment(\.tableTheme) private var theme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: theme.wood, startPoint: .topLeading, endPoint: .bottomTrailing)

                ForEach(0..<7, id: \.self) { index in
                    let plankHeight = geo.size.height / 7
                    Rectangle()
                        .fill(index.isMultiple(of: 2)
                            ? Color.white.opacity(0.045)
                            : Color.black.opacity(0.045))
                        .frame(height: plankHeight)
                        .position(x: geo.size.width / 2, y: plankHeight * (CGFloat(index) + 0.5))

                    Rectangle()
                        .fill(Color.black.opacity(0.16))
                        .frame(height: 1)
                        .position(x: geo.size.width / 2, y: plankHeight * CGFloat(index))
                }

                Ellipse()
                    .fill(RadialGradient(colors: theme.felt, center: .center, startRadius: 40, endRadius: 500))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .shadow(color: .black.opacity(0.45), radius: 18, y: 8)

                Ellipse()
                    .strokeBorder(LinearGradient(colors: theme.rim, startPoint: .top, endPoint: .bottom), lineWidth: 4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)

                Ellipse()
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 28)
            }
        }
        .accessibilityHidden(true)
    }
}

/// A table theme in miniature: wood with the felt oval and its rim inset.
struct ThemeSwatch: View {
    let theme: TableTheme

    var body: some View {
        GeometryReader { geo in
            let inset = min(geo.size.width, geo.size.height) * 0.14
            ZStack {
                RoundedRectangle(cornerRadius: inset * 1.4)
                    .fill(LinearGradient(colors: theme.wood, startPoint: .topLeading, endPoint: .bottomTrailing))
                Ellipse()
                    .fill(RadialGradient(colors: theme.felt, center: .center, startRadius: 2, endRadius: max(geo.size.width, geo.size.height) * 0.6))
                    .padding(inset)
                Ellipse()
                    .strokeBorder(LinearGradient(colors: theme.rim, startPoint: .top, endPoint: .bottom), lineWidth: max(1.5, inset * 0.25))
                    .padding(inset)
            }
        }
        .accessibilityHidden(true)
    }
}
