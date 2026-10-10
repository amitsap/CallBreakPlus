import SwiftUI

/// The screens that open as paper panels over the felt, from the menu or from Pause.
enum PanelKind: String, Identifiable {
    case settings, statistics, howToPlay
    var id: String { rawValue }
}

/// A paper panel over the table: the overlays' scrim and paper, a close
/// control, and most of the safe area. Tapping the scrim closes it.
struct PaperPanel<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder let content: Content

    init(onClose: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.onClose = onClose
        self.content = content()
    }

    static func size(in available: CGSize) -> CGSize {
        CGSize(width: min(available.width - 40, 720), height: min(available.height - 24, 360))
    }

    var body: some View {
        GeometryReader { geo in
            let size = Self.size(in: geo.size)
            ZStack {
                TablePalette.scrim
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                    .accessibilityHidden(true)

                content
                    .frame(width: size.width, height: size.height)
                    .background(TablePalette.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(TablePalette.rimBrown.opacity(0.5), lineWidth: 1.5))
                    .overlay(alignment: .topTrailing) {
                        PanelCloseButton(action: onClose)
                            .padding(6)
                    }
                    .shadow(color: .black.opacity(0.30), radius: 16, y: 6)
                    .accessibilityElement(children: .contain)
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape, onClose)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}

struct PanelCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(TablePalette.ink)
                .frame(width: 30, height: 30)
                .background(TablePalette.ink.opacity(0.10), in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }
}

/// A panel with a section sidebar on the leading side and the selected
/// section's detail beside it. Each side scrolls on its own if a phone is short.
struct PanelSidebarLayout<Detail: View>: View {
    let title: String
    let sections: [String]
    @Binding var selection: Int
    @ViewBuilder let detail: Detail

    init(title: String, sections: [String], selection: Binding<Int>, @ViewBuilder detail: () -> Detail) {
        self.title = title
        self.sections = sections
        self._selection = selection
        self.detail = detail()
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(TableType.title)
                    .foregroundStyle(TablePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.leading, 8)
                    .accessibilityAddTraits(.isHeader)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(sections.indices, id: \.self) { index in
                            sidebarRow(index)
                        }
                    }
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 10)
            .frame(width: 168)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(TablePalette.paperShade)

            Rectangle()
                .fill(TablePalette.rimBrown.opacity(0.25))
                .frame(width: 1)

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func sidebarRow(_ index: Int) -> some View {
        let selected = index == selection
        return Button {
            selection = index
        } label: {
            Text(sections[index])
                .font(TableType.body)
                .foregroundStyle(selected ? TablePalette.ink : TablePalette.faded)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9)
                        .fill(selected ? TablePalette.cardRuled.opacity(0.45) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The panel for one `PanelKind`, as opened from the menu or from Pause.
struct PanelScreen: View {
    let kind: PanelKind
    @Bindable var viewModel: GameViewModel
    let gameInProgress: Bool
    /// Starts a new game from the panel; nil when a game is already in progress.
    var onDealGame: (() -> Void)? = nil
    let onClose: () -> Void
    /// The Pro panel, stacked over this one when a locked Pro item is tapped.
    @State private var showingPro = false

    var body: some View {
        ZStack {
            PaperPanel(onClose: onClose) {
                switch kind {
                case .settings:
                    SettingsView(viewModel: viewModel, gameInProgress: gameInProgress)
                case .statistics:
                    StatisticsView(viewModel: viewModel, onDealGame: onDealGame)
                case .howToPlay:
                    HowToPlayView()
                }
            }
            .environment(\.openProPanel, OpenProPanelAction { setShowingPro(true) })
            .accessibilityHidden(showingPro)

            if showingPro {
                PaperPanel(onClose: { setShowingPro(false) }) {
                    ProPanel(onClose: { setShowingPro(false) })
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(1)
            }
        }
    }

    private func setShowingPro(_ showing: Bool) {
        withAnimation(.spring(duration: 0.25)) { showingPro = showing }
    }
}
