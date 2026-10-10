import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: GameViewModel
    /// Opened from Pause: difficulty and house rules wait for the next game, and a banner says so.
    let gameInProgress: Bool
    @State private var section = Section.game
    /// The name as typed, trimmed to the cap here: a TextField doesn't show a value its model trims.
    @State private var nameDraft = ""
    /// A Pro theme or back tapped without Pro: shown in the preview, never saved.
    @State private var previewTheme: TableThemeChoice?
    @State private var previewBack: CardBack?
    @Environment(\.openURL) private var openURL
    @Environment(\.openProPanel) private var openProPanel
    @Environment(ProStore.self) private var proStore

    enum Section: Int, CaseIterable {
        case game, houseRules, tablesAndDecks, assists, soundAndHaptics, accessibility, about

        var title: String {
            switch self {
            case .game: "Game"
            case .houseRules: "House rules"
            case .tablesAndDecks: "Tables & decks"
            case .assists: "Assists"
            case .soundAndHaptics: "Sound & haptics"
            case .accessibility: "Accessibility"
            case .about: "About"
            }
        }
    }

    var body: some View {
        PanelSidebarLayout(
            title: "Settings",
            sections: Section.allCases.map(\.title),
            selection: Binding(get: { section.rawValue }, set: { section = Section(rawValue: $0) ?? .game })
        ) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    if gameInProgress, section == .game || section == .houseRules {
                        nextGameBanner
                            .padding(.trailing, 36)
                            .padding(.bottom, 10)
                    }
                    Text(section.title)
                        .font(TableType.title)
                        .foregroundStyle(TablePalette.ink)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.bottom, 4)
                    detail
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
            .id(section)
        }
        .onChange(of: section) { clearPreview() }
        .onChange(of: proStore.hasPro) { _, hasPro in
            // Buying Pro while previewing keeps what was being previewed.
            guard hasPro else { return }
            if let previewTheme { viewModel.tableTheme = previewTheme }
            if let previewBack { viewModel.cardBack = previewBack }
            clearPreview()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .game: gameSection
        case .houseRules: houseRulesSection
        case .tablesAndDecks: tablesAndDecksSection
        case .assists: assistsSection
        case .soundAndHaptics: soundSection
        case .accessibility: accessibilitySection
        case .about: aboutSection
        }
    }

    private var nextGameBanner: some View {
        Label("Game in progress: difficulty and house rules change from your next game.", systemImage: "info.circle.fill")
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(TablePalette.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TablePalette.gold.opacity(0.28), in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(TablePalette.gold.opacity(0.7), lineWidth: 1))
    }

    // MARK: - Sections

    private var gameSection: some View {
        VStack(spacing: 0) {
            row("Difficulty", caption: "How well the bots play, from your next game") {
                Picker("Difficulty", selection: $viewModel.botDifficulty) {
                    ForEach(BotDifficulty.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }
            rule
            row("Play speed", caption: "Fast shortens every pause by about a third") {
                Picker("Play speed", selection: $viewModel.fastPlayEnabled) {
                    Text("Normal").tag(false)
                    Text("Fast").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            rule
            row("Your name", caption: "Up to \(GameViewModel.maxPlayerNameLength) letters, shown on the table") {
                nameField
            }
        }
    }

    private var houseRulesSection: some View {
        VStack(spacing: 0) {
            Text("From your next game")
                .font(TableType.kicker)
                .textCase(.uppercase)
                .kerning(1)
                .foregroundStyle(TablePalette.faded)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 2)
            variantRow("Game length", caption: "Rounds in a game. Score charts count 5-round games only.", freeValue: "\(ProGate.freeRoundCount) rounds") { hasPro in
                Picker("Game length", selection: variantSelection(\.roundCount, free: ProGate.freeRoundCount, hasPro: hasPro)) {
                    ForEach(GameViewModel.roundCountChoices, id: \.self) { Text("\($0)").accessibilityLabel("\($0) rounds").tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            rule
            toggleRow("Thok", caption: "Call \(viewModel.effectiveThokThreshold) or more and make it, and you win the game on the spot.", isOn: $viewModel.instantWinEnabled)
            if viewModel.instantWinEnabled {
                rule
                variantRow("Thok call", caption: "The smallest call that wins on the spot.", freeValue: "\(ProGate.freeThokThreshold)") { hasPro in
                    Picker("Thok call", selection: variantSelection(\.thokThreshold, free: ProGate.freeThokThreshold, hasPro: hasPro)) {
                        ForEach(GameViewModel.thokThresholdChoices, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                }
            }
            rule
            toggleRow("Free Discard", caption: "When you can’t beat a Spade already played, you may discard another suit instead of a lower Spade.", isOn: $viewModel.canDiscardWhenCantOvertrump)
            rule
            toggleRow("Fair Deal", caption: "A hand with no Spade, or no Jack, Queen, King or Ace, is dealt again.", isOn: $viewModel.redealOnWeakHand)
        }
    }

    private var tablesAndDecksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            tablePreview
            rule
            choiceGrid("Table", caption: "The felt and wood under every game", minimumWidth: 64) {
                ForEach(TableThemeChoice.allCases) { themeChoice($0) }
            }
            rule
            choiceGrid("Card back", caption: "Used for the bots’ hands", minimumWidth: 44) {
                ForEach(CardBack.allCases) { cardBackChoice($0) }
            }
        }
    }

    /// The chosen table and back together, or the Pro ones being previewed, with the offer.
    private var tablePreview: some View {
        let theme = previewTheme ?? viewModel.effectiveTableTheme
        let back = previewBack ?? viewModel.effectiveCardBack
        let previewing = previewTheme != nil || previewBack != nil
        return HStack(spacing: 16) {
            ZStack {
                ThemeSwatch(theme: theme.theme)
                HStack(spacing: -18) {
                    ForEach(-1...1, id: \.self) { index in
                        CardView(card: Card(suit: .spades, rank: .ace), isFaceUp: false, cardBack: back)
                            .scaleEffect(0.42)
                            .frame(width: CardView.width * 0.42, height: CardView.height * 0.42)
                            .rotationEffect(.degrees(Double(index) * 9))
                            .offset(y: abs(Double(index)) * 2)
                    }
                }
            }
            .frame(width: 150, height: 92)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(previewing ? "Previewing" : "Your table")
                    .font(TableType.kicker)
                    .textCase(.uppercase)
                    .kerning(1)
                    .foregroundStyle(TablePalette.faded)
                Text("\(theme.name) table, \(back.name) back")
                    .font(TableType.headline)
                    .foregroundStyle(TablePalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if previewing {
                    Text("Part of Pro. Not saved until you unlock it.")
                        .font(TableType.caption)
                        .foregroundStyle(TablePalette.faded)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("See Pro") { openProPanel?() }
                        .font(TableType.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(TablePalette.accentGreen, in: RoundedRectangle(cornerRadius: 9))
                        .buttonStyle(.plain)
                        .padding(.top, 2)
                }
            }
            .accessibilityElement(children: .combine)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
    }

    private var assistsSection: some View {
        toggleRow("Bid Suggestion", caption: "Shows a suggested call when you bid, and selects it for you.", isOn: $viewModel.showBidSuggestion)
    }

    private var soundSection: some View {
        VStack(spacing: 0) {
            toggleRow("Sound", caption: nil, isOn: $viewModel.soundEnabled)
            rule
            toggleRow("Haptics", caption: nil, isOn: $viewModel.hapticsEnabled)
        }
    }

    private var accessibilitySection: some View {
        VStack(spacing: 0) {
            toggleRow("Reduce Motion", caption: "Fewer animations at the table.", isOn: $viewModel.reduceMotion)
            rule
            toggleRow("High-Contrast Cards", caption: "Stronger card edges, and unplayable cards dimmed further.", isOn: $viewModel.highContrastCards)
        }
    }

    private var aboutSection: some View {
        VStack(spacing: 0) {
            row("Call Break+", caption: "Version \(appVersion)") { EmptyView() }
            rule
            proRow
            rule
            RestorePurchasesButton(alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 2)
            rule
            linkRow("Send feedback", icon: "envelope.fill") { openURL(feedbackURL) }
            rule
            linkRow("Rate on the App Store", icon: "star.fill") { openURL(Self.writeReviewURL) }
        }
        .task { await proStore.loadProduct() }
    }

    private var proRow: some View {
        row("Call Break+ Pro", caption: proStore.hasPro ? "Thank you for supporting Call Break+." : "Tables, Insights and rule variants. One-time, no ads, ever.") {
            if proStore.hasPro {
                Label("Unlocked", systemImage: "checkmark.seal.fill")
                    .font(TableType.headline)
                    .foregroundStyle(TablePalette.paperGreen)
            } else {
                Button { openProPanel?() } label: {
                    Text(unlockTitle)
                        .font(TableType.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(minHeight: 44)
                        .background(TablePalette.accentGreen, in: RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Call Break+ Pro")
            }
        }
    }

    private var unlockTitle: String {
        if case .available(let price) = proStore.offer { "Unlock · \(price)" } else { "See Pro" }
    }

    // MARK: - Controls

    private var nameField: some View {
        HStack(spacing: 6) {
            TextField("You", text: $nameDraft)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(TablePalette.ink)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .accessibilityLabel("Your name")
                .onAppear { nameDraft = viewModel.playerName }
                .onChange(of: nameDraft) { _, name in
                    let capped = String(name.prefix(GameViewModel.maxPlayerNameLength))
                    if capped != name { nameDraft = capped }
                    viewModel.playerName = capped
                }
            Image(systemName: "pencil")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(TablePalette.faded)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .frame(width: 160, height: 44)
        .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(TablePalette.cardRuled, lineWidth: 1))
    }

    private func choiceGrid<Choices: View>(_ title: String, caption: String, minimumWidth: CGFloat, @ViewBuilder choices: () -> Choices) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TableType.headline)
                    .foregroundStyle(TablePalette.ink)
                Text(caption)
                    .font(TableType.caption)
                    .foregroundStyle(TablePalette.faded)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumWidth), spacing: 8, alignment: .top)], alignment: .leading, spacing: 8) {
                choices()
            }
        }
        .padding(.vertical, 10)
    }

    private func themeChoice(_ choice: TableThemeChoice) -> some View {
        choiceButton(
            name: choice.name,
            label: "\(choice.name) table",
            isPro: choice.isPro,
            selected: previewTheme == nil && viewModel.effectiveTableTheme == choice,
            previewing: previewTheme == choice
        ) {
            if choice.isPro && !proStore.hasPro {
                previewTheme = choice
            } else {
                viewModel.tableTheme = choice
                previewTheme = nil
            }
        } thumbnail: {
            ThemeSwatch(theme: choice.theme)
                .frame(width: 56, height: 38)
        }
    }

    private func cardBackChoice(_ back: CardBack) -> some View {
        choiceButton(
            name: back.name,
            label: "\(back.name) card back",
            isPro: back.isPro,
            selected: previewBack == nil && viewModel.effectiveCardBack == back,
            previewing: previewBack == back
        ) {
            if back.isPro && !proStore.hasPro {
                previewBack = back
            } else {
                viewModel.cardBack = back
                previewBack = nil
            }
        } thumbnail: {
            CardView(card: Card(suit: .spades, rank: .ace), isFaceUp: false, cardBack: back)
                .scaleEffect(0.5)
                .frame(width: CardView.width * 0.5, height: CardView.height * 0.5)
        }
    }

    /// A theme or back to pick. Without Pro a Pro one carries a badge and only previews.
    private func choiceButton<Thumbnail: View>(
        name: String,
        label: String,
        isPro: Bool,
        selected: Bool,
        previewing: Bool,
        action: @escaping () -> Void,
        @ViewBuilder thumbnail: () -> Thumbnail
    ) -> some View {
        let locked = isPro && !proStore.hasPro
        return Button(action: action) {
            VStack(spacing: 3) {
                thumbnail()
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(
                                previewing ? TablePalette.paperGold : selected ? TablePalette.accentGreen : .clear,
                                style: StrokeStyle(lineWidth: 2.5, dash: previewing ? [5, 3] : [])
                            )
                    )
                Text(name)
                    .font(TableType.caption)
                    .foregroundStyle(TablePalette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if locked {
                    ProBadge()
                        .fixedSize()
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(locked ? "\(label), Pro" : label)
        .accessibilityHint(locked ? "Shows a preview. Unlocking it needs Pro." : "")
        .accessibilityAddTraits(selected || previewing ? [.isButton, .isSelected] : .isButton)
    }

    private func clearPreview() {
        previewTheme = nil
        previewBack = nil
    }

    private func row<Control: View>(_ title: String, caption: String?, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(TableType.headline)
                    .foregroundStyle(TablePalette.ink)
                if let caption {
                    Text(caption)
                        .font(TableType.caption)
                        .foregroundStyle(TablePalette.faded)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
        .frame(minHeight: 52)
        .padding(.vertical, 4)
    }

    /// A Pro rule variant: without Pro it shows the free value, locked, with a Pro badge,
    /// and tapping the row opens the Pro panel.
    @ViewBuilder
    private func variantRow<Control: View>(_ title: String, caption: String, freeValue: String, @ViewBuilder control: (Bool) -> Control) -> some View {
        if proStore.hasPro {
            row(title, caption: caption) { control(true) }
        } else {
            Button { openProPanel?() } label: {
                row(title, caption: caption) {
                    HStack(spacing: 8) {
                        ProBadge().fixedSize()
                        control(false)
                            .disabled(true)
                            .allowsHitTesting(false)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(freeValue), Pro")
            .accessibilityHint("Opens Call Break+ Pro")
            .accessibilityAddTraits(.isButton)
        }
    }

    private func variantSelection(_ keyPath: ReferenceWritableKeyPath<GameViewModel, Int>, free: Int, hasPro: Bool) -> Binding<Int> {
        hasPro ? Binding(get: { viewModel[keyPath: keyPath] }, set: { viewModel[keyPath: keyPath] = $0 }) : .constant(free)
    }

    private func toggleRow(_ title: String, caption: String?, isOn: Binding<Bool>) -> some View {
        row(title, caption: caption) {
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .tint(TablePalette.accentGreen)
        }
        .accessibilityElement(children: .combine)
    }

    private func linkRow(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Label(title, systemImage: icon)
                    .font(TableType.headline)
                    .foregroundStyle(TablePalette.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TablePalette.faded)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var rule: some View {
        Rectangle()
            .fill(TablePalette.cardRuled.opacity(0.45))
            .frame(height: 1)
    }

    // MARK: - Links

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private var feedbackURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@greatarc.app"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Call Break+ Feedback"),
            URLQueryItem(
                name: "body",
                value: "\n\n—\nApp version: \(appVersion) (\(build))\niOS: \(UIDevice.current.systemVersion)"
            ),
        ]
        return components.url ?? URL(string: "https://greatarc.app/callbreakplus/support/")!
    }

    private static let writeReviewURL = URL(
        string: "https://apps.apple.com/app/id617853649?action=write-review"
    )!
}
