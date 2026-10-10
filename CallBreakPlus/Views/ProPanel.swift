import SwiftUI

extension EnvironmentValues {
    /// Opens the Pro panel over the current paper panel. Set by `PanelScreen`; nil elsewhere.
    @Entry var openProPanel: OpenProPanelAction? = nil
}

struct OpenProPanelAction: Equatable {
    let open: () -> Void

    func callAsFunction() { open() }

    /// Each panel hosts one Pro panel, so any two actions do the same thing; equal
    /// actions keep a parent's redraw from invalidating every reader.
    static func == (lhs: Self, rhs: Self) -> Bool { true }
}

/// The Pro panel: the three pillars with mini previews, the price, and Restore Purchases.
/// Opened only from where Pro features live, never during a hand.
struct ProPanel: View {
    let onClose: () -> Void
    @Environment(ProStore.self) private var proStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("One upgrade, yours to keep")
                        .font(TableType.kicker)
                        .textCase(.uppercase)
                        .kerning(1)
                        .foregroundStyle(TablePalette.faded)
                    Text("Call Break+ Pro")
                        .font(TableType.display)
                        .foregroundStyle(TablePalette.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        pillar("Tables & decks", detail: "Royal, Maroon and Midnight tables, and six new card backs.") { TablesPreview() }
                        pillar("Insights", detail: "Your score in every game, how often you make your call, and your full history.") { InsightsPreview() }
                        pillar("Rule variants", detail: "Play 3, 5 or 10 rounds, and set the Thok call anywhere from 8 to 13.") { VariantsPreview() }
                    }
                }
            }
            .padding(.top, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Rectangle()
                .fill(TablePalette.rimBrown.opacity(0.25))
                .frame(width: 1)

            purchaseColumn
                .frame(width: 236)
                .frame(maxHeight: .infinity)
                .background(TablePalette.paperShade)
        }
        .task { await proStore.loadProduct() }
    }

    private func pillar<Preview: View>(_ title: String, detail: String, @ViewBuilder preview: () -> Preview) -> some View {
        HStack(spacing: 12) {
            preview()
                .frame(width: 72, height: 50)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TableType.headline)
                    .foregroundStyle(TablePalette.ink)
                Text(detail)
                    .font(TableType.caption)
                    .foregroundStyle(TablePalette.faded)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Purchase

    private var purchaseColumn: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 44)
            offer
            Spacer(minLength: 4)
            VStack(spacing: 4) {
                Text("One-time purchase · No subscription\nNo ads, ever")
                    .multilineTextAlignment(.center)
                Label("Shared with your family", systemImage: "person.2.fill")
            }
            .font(TableType.caption)
            .foregroundStyle(TablePalette.faded)
            .fixedSize(horizontal: false, vertical: true)
            RestorePurchasesButton(alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var offer: some View {
        switch proStore.offer {
        case .loading:
            status(nil, caption: nil)
            PanelButtonPlaceholder(title: "Loading price…")
        case .unavailable:
            status("Pro isn’t available right now", caption: "Check your connection, then try again.")
            OverlayButton("Try Again") { Task { await proStore.loadProduct() } }
        case .available(let price):
            priceText(price)
            OverlayButton("Unlock Pro") { Task { await proStore.purchase() } }
        case .purchasing:
            status(nil, caption: nil)
            PanelButtonPlaceholder(title: "Purchasing…")
        case .pending:
            status("Waiting for approval", caption: "Pro unlocks as soon as the purchase is approved.")
            // A declined request sends nothing back, so the player can ask again.
            OverlayButton("Ask Again") { Task { await proStore.purchase() } }
        case .failed:
            status("The purchase didn’t go through", caption: "Check your connection, then try again.")
            OverlayButton("Retry") { Task { await proStore.purchase() } }
        case .owned:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(TablePalette.paperGreen)
                .accessibilityHidden(true)
            status("Thank you!", caption: "Tables, Insights and rule variants are yours.")
            OverlayButton("Done", action: onClose)
        }
    }

    private func priceText(_ price: String) -> some View {
        VStack(spacing: 0) {
            Text(price)
                .font(TableType.display)
                .foregroundStyle(TablePalette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("One time")
                .font(TableType.kicker)
                .textCase(.uppercase)
                .kerning(1)
                .foregroundStyle(TablePalette.faded)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func status(_ title: String?, caption: String?) -> some View {
        VStack(spacing: 4) {
            if let title {
                Text(title)
                    .font(TableType.headline)
                    .foregroundStyle(TablePalette.ink)
            }
            if let caption {
                Text(caption)
                    .font(TableType.caption)
                    .foregroundStyle(TablePalette.faded)
            }
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

/// A disabled stand-in for a panel button while the store works: a spinner and what it's doing.
private struct PanelButtonPlaceholder: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(TablePalette.faded)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(TablePalette.faded)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(TablePalette.cardRuled.opacity(0.35), in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .combine)
    }
}

/// Restore Purchases, which App Review requires for a non-consumable. Says what it found.
struct RestorePurchasesButton: View {
    let alignment: HorizontalAlignment
    @Environment(ProStore.self) private var proStore
    @State private var restoring = false
    /// Nil until a restore finishes.
    @State private var outcome: ProStore.RestoreResult?

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Button {
                Task { await restore() }
            } label: {
                HStack(spacing: 6) {
                    if restoring {
                        ProgressView()
                            .controlSize(.small)
                            .tint(TablePalette.faded)
                    }
                    Text("Restore Purchases")
                        .font(TableType.body)
                        .foregroundStyle(TablePalette.ink)
                        .underline()
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(restoring)
            if let message {
                Text(message)
                    .font(TableType.caption)
                    .foregroundStyle(TablePalette.faded)
                    .multilineTextAlignment(alignment == .center ? .center : .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: proStore.hasPro) { _, hasPro in
            if hasPro, !restoring, let message { AccessibilityNotification.Announcement(message).post() }
        }
    }

    /// Read from `hasPro` when drawn, not when `restore()` returns: Pro can arrive just
    /// after it, from a refresh that overtook restore's own.
    private var message: String? {
        guard let outcome else { return nil }
        if proStore.hasPro { return "Pro is unlocked." }
        switch outcome {
        case .synced: return "No Pro purchase was found for this Apple Account."
        case .cancelled: return nil
        case .failed: return "Couldn’t reach the App Store. Check your connection, then try again."
        }
    }

    private func restore() async {
        restoring = true
        outcome = nil
        outcome = await proStore.restore()
        restoring = false
        if let message { AccessibilityNotification.Announcement(message).post() }
    }
}

// MARK: - Pillar previews

/// A Pro table with a Pro back on it.
private struct TablesPreview: View {
    var body: some View {
        ZStack {
            ThemeSwatch(theme: .royal)
            HStack(spacing: -12) {
                ForEach([CardBack.mandala, .goldLeaf], id: \.self) { back in
                    CardView(card: Card(suit: .spades, rank: .ace), isFaceUp: false, cardBack: back)
                        .scaleEffect(0.32)
                        .frame(width: CardView.width * 0.32, height: CardView.height * 0.32)
                        .rotationEffect(.degrees(back == .mandala ? -8 : 8))
                }
            }
        }
    }
}

/// A few score bars, the Insights chart in miniature.
private struct InsightsPreview: View {
    private let bars: [(height: CGFloat, won: Bool)] = [(0.45, false), (0.7, true), (0.3, false), (0.85, true), (0.55, false), (0.95, true), (0.65, true)]

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(bars.indices, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(bars[index].won ? TablePalette.accentGreen : TablePalette.cardRuled)
                    .frame(width: 6, height: 34 * bars[index].height)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// The game-length choices, with 10 picked.
private struct VariantsPreview: View {
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                ForEach([3, 5, 10], id: \.self) { rounds in
                    Text("\(rounds)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(rounds == 10 ? .white : TablePalette.ink)
                        .frame(width: 18, height: 16)
                        .background(rounds == 10 ? TablePalette.accentGreen : TablePalette.cardRuled.opacity(0.4), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            Text("Thok 10")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(TablePalette.thokOrange)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }
}
