import SwiftUI

struct GameTableView: View {
    private let bottomAreaHeight: CGFloat = 97
    private let bidTrayHeight: CGFloat = 137
    private let handVerticalLift: CGFloat = 18
    @Bindable var viewModel: GameViewModel
    let onQuit: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingQuitConfirmation = false
    @State private var showingPauseMenu = false
    @State private var scorecardExpanded = false
    @State private var turnPulse = false
    @State private var turnHintVisible = false
    @State private var turnHintTask: Task<Void, Never>?
    @State private var pausedForSettings = false
    @State private var showingPausedStats = false
    @State private var summaryTapIsArmed = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                tableBackground
                    .ignoresSafeArea()

                centerArea(geo: geo)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + 10)

                topArea(geo: geo)
                    .position(x: geo.size.width / 2, y: geo.safeAreaInsets.top + 80)

                bottomArea(geo: geo)
                    .position(x: geo.size.width / 2, y: bottomAreaCenterY(for: geo))

                humanTrickCardLayer
                    .position(x: geo.size.width / 2, y: geo.size.height / 2 + 10)

                leftSeat(geo: geo)
                rightSeat(geo: geo)

                tableChrome(geo: geo)
                scorecardDrawer(geo: geo)

                if let message = viewModel.invalidMoveMessage {
                    Text(message)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.82), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        .position(x: geo.size.width / 2, y: geo.size.height - geo.safeAreaInsets.bottom - 128)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .zIndex(10)
                        .accessibilityAddTraits(.isStaticText)
                }

                if viewModel.showingBidSelector {
                    bidSelectorOverlay(geo: geo)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                if viewModel.showingRoundSummary {
                    roundSummaryOverlay
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if viewModel.showingGameOver {
                    gameOverOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }

                if viewModel.showingLastTrick {
                    lastTrickOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(9)
                }

                if showingQuitConfirmation {
                    quitConfirmationOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                if showingPauseMenu {
                    pauseMenuOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .zIndex(20)
                }
            }
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .alert("Statistics Error", isPresented: Binding(
            get: { viewModel.statsErrorMessage != nil },
            set: { if !$0 { viewModel.statsErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.statsErrorMessage = nil }
        } message: {
            Text(viewModel.statsErrorMessage ?? "")
        }
        .onChange(of: viewModel.showingSettings) { _, showing in
            guard !showing, pausedForSettings else { return }
            pausedForSettings = false
            viewModel.resumeGame()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            guard !showingPauseMenu, !pausedForSettings, !showingPausedStats,
                  !showingQuitConfirmation, !viewModel.showingRoundSummary, !viewModel.showingLastTrick,
                  !viewModel.isGameOver, !viewModel.showingGameOver
            else { return }
            viewModel.pauseGame()
            withAnimation(.spring(duration: 0.25)) { showingPauseMenu = true }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard viewModel.showingRoundSummary else { return }
            if newPhase == .active { viewModel.resumeSummaryCountdown() }
            else { viewModel.suspendSummaryCountdown() }
        }
        .sheet(isPresented: $showingPausedStats, onDismiss: {
            viewModel.resumeGame()
        }) {
            StatisticsView(statsRepository: viewModel.statsRepository, statsUnavailable: viewModel.statsUnavailable)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Background

    private var tableBackground: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.42, green: 0.20, blue: 0.08),
                        Color(red: 0.72, green: 0.37, blue: 0.12),
                        Color(red: 0.50, green: 0.23, blue: 0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

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
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.10, green: 0.46, blue: 0.16),
                                Color(red: 0.05, green: 0.28, blue: 0.09),
                                Color(red: 0.02, green: 0.16, blue: 0.05),
                            ],
                            center: .center,
                            startRadius: 40,
                            endRadius: 500
                        )
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .shadow(color: .black.opacity(0.45), radius: 18, y: 8)

                Ellipse()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.76, blue: 0.28).opacity(0.55),
                                Color(red: 0.35, green: 0.22, blue: 0.08).opacity(0.7),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 4
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)

                Ellipse()
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 28)
            }
        }
    }

    // MARK: - Seats

    private func topArea(geo: GeometryProxy) -> some View {
        SeatClusterView(name: viewModel.seatName(.top), seat: .top, bid: viewModel.bidForSeat(.top), tricks: viewModel.tricksForSeat(.top), isActive: activeSeat == .top, isDealer: viewModel.currentRound?.dealer == .top, count: viewModel.handCountForSeat(.top), cardBackStyle: viewModel.cardBackStyle, horizontal: true)
            .frame(width: 190, height: 52)
    }

    private func bottomArea(geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            ZStack {
                playerHandView
                    .frame(width: min(geo.size.width - geo.safeAreaInsets.leading - geo.safeAreaInsets.trailing - 104, 710), height: bottomAreaHeight)
                    .shadow(
                        color: viewModel.legalCards.isEmpty
                            ? .clear
                            : TablePalette.gold.opacity(turnPulse ? 0.20 : 0.09),
                        radius: turnPulse ? 10 : 5,
                        y: -3
                    )
                    .offset(y: -handVerticalLift)

                humanHandPill
                    .offset(y: 18)
            }
        }
        .frame(width: geo.size.width, height: bottomAreaHeight)
        .animation(.easeInOut(duration: 0.4), value: viewModel.isHumanTurn)
        .onChange(of: viewModel.isHumanTurn) { _, isHuman in
            turnHintTask?.cancel()
            turnHintVisible = false
            if isHuman {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    turnPulse = true
                }
                turnHintTask = Task {
                    try? await Task.sleep(for: .seconds(2.2))
                    guard !Task.isCancelled, viewModel.isHumanTurn,
                          !viewModel.legalCards.isEmpty else { return }
                    withAnimation(.easeIn(duration: 0.2)) { turnHintVisible = true }
                }
            } else {
                turnPulse = false
            }
        }
    }

    private func bottomAreaCenterY(for geo: GeometryProxy) -> CGFloat {
        geo.size.height + 14 - bottomAreaHeight / 2
    }

    private func leftSeat(geo: GeometryProxy) -> some View {
        SeatClusterView(name: viewModel.seatName(.left), seat: .left, bid: viewModel.bidForSeat(.left), tricks: viewModel.tricksForSeat(.left), isActive: activeSeat == .left, isDealer: viewModel.currentRound?.dealer == .left, count: viewModel.handCountForSeat(.left), cardBackStyle: viewModel.cardBackStyle, horizontal: false)
        .position(x: geo.safeAreaInsets.leading + 98, y: geo.size.height / 2)
    }

    private func rightSeat(geo: GeometryProxy) -> some View {
        SeatClusterView(name: viewModel.seatName(.right), seat: .right, bid: viewModel.bidForSeat(.right), tricks: viewModel.tricksForSeat(.right), isActive: activeSeat == .right, isDealer: viewModel.currentRound?.dealer == .right, count: viewModel.handCountForSeat(.right), cardBackStyle: viewModel.cardBackStyle, horizontal: false)
        .position(x: geo.size.width - geo.safeAreaInsets.trailing - 98, y: geo.size.height / 2)
    }

    private var humanHandPill: some View {
        HStack(spacing: 5) {
            if viewModel.currentRound?.dealer == .bottom {
                Text("D")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(TablePalette.ink)
                    .frame(width: 16, height: 16)
                    .background(TablePalette.gold, in: Circle())
            }

            Text("You")
            Text("\(viewModel.tricksForSeat(.bottom))/\(viewModel.bidForSeat(.bottom).map(String.init) ?? "–")")
                .foregroundStyle(TablePalette.gold)

            if turnHintVisible, !viewModel.legalCards.isEmpty {
                Text("·  Play a card")
                    .foregroundStyle(.white.opacity(0.78))
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.92))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.black.opacity(viewModel.isHumanTurn ? 0.52 : 0.38), in: Capsule())
        .overlay(
            Capsule().strokeBorder(
                viewModel.isHumanTurn ? TablePalette.gold.opacity(0.85) : .white.opacity(0.12),
                lineWidth: 1
            )
        )
        .animation(.easeInOut(duration: 0.2), value: turnHintVisible)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(humanHandAccessibilityLabel)
    }

    private var humanHandAccessibilityLabel: String {
        let dealer = viewModel.currentRound?.dealer == .bottom ? "Dealer, " : ""
        let bid = viewModel.bidForSeat(.bottom).map(String.init) ?? "not bid"
        let prompt = turnHintVisible && !viewModel.legalCards.isEmpty ? ", play a card" : ""
        return "\(dealer)You, won \(viewModel.tricksForSeat(.bottom)), bid \(bid)\(prompt)"
    }

    // MARK: - Center Trick Area

    private func centerArea(geo: GeometryProxy) -> some View {
        ZStack {
            if viewModel.isDealing {
                CardView(
                    card: Card(suit: .spades, rank: .ace),
                    isFaceUp: false,
                    cardBackStyle: viewModel.cardBackStyle
                )
                .scaleEffect(0.68)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)

                if let seat = viewModel.dealingCardSeat {
                    CardView(
                        card: Card(suit: .spades, rank: .ace),
                        isFaceUp: false,
                        cardBackStyle: viewModel.cardBackStyle
                    )
                    .scaleEffect(0.56)
                    .offset(viewModel.dealingCardInFlight ? dealOffset(for: seat, geo: geo) : .zero)
                    .opacity(viewModel.dealingCardInFlight ? 0.92 : 1)
                    .zIndex(5)
                    .accessibilityHidden(true)
                }
            }

            ForEach(Array(viewModel.currentTrickPlays.enumerated()), id: \.offset) { _, play in
                if play.seat != .bottom {
                let isWinner = viewModel.trickWinner == play.seat
                let collecting = viewModel.trickCardsToCollect && !viewModel.reduceMotion
                CardView(card: play.card, highContrast: viewModel.highContrastCards)
                    .rotationEffect(trickCardRotation(for: play.seat))
                    .offset(collecting
                        ? collectOffset(for: viewModel.collectToSeat ?? play.seat)
                        : trickCardOffset(for: play.seat))
                    .scaleEffect(collecting ? 0.54 : (isWinner ? 0.98 : 0.92))
                    .shadow(
                        color: isWinner
                            ? .yellow.opacity(0.68)
                            : .black.opacity(0.16),
                        radius: isWinner ? 11 : 3,
                        y: 2
                    )
                    .opacity(collecting ? 0 : (viewModel.trickWinner == nil || isWinner ? 1 : 0.72))
                    .zIndex(1)
                }
            }
        }
        .frame(width: 280, height: 190)
    }

    private var humanTrickCardLayer: some View {
        Group {
            if let play = viewModel.currentTrickPlays.first(where: { $0.seat == .bottom }) {
                let collecting = viewModel.trickCardsToCollect && !viewModel.reduceMotion
                CardView(card: play.card, highContrast: viewModel.highContrastCards)
                    .offset(collecting ? collectOffset(for: viewModel.collectToSeat ?? .bottom) : trickCardOffset(for: .bottom))
                    .scaleEffect(collecting ? 0.54 : 0.98)
                    .shadow(color: viewModel.trickWinner == .bottom ? .yellow.opacity(0.68) : .white.opacity(0.44), radius: viewModel.trickWinner == .bottom ? 11 : 7, y: 2)
                    .opacity(collecting ? 0 : (viewModel.trickWinner == nil || viewModel.trickWinner == .bottom ? 1 : 0.72))
                    .allowsHitTesting(false)
            }
        }
        .frame(width: 280, height: 190)
    }

    // MARK: - Player Hand

    private var playerHandView: some View {
        let handScale: CGFloat = 0.9
        let cards = viewModel.visibleHumanHand
        let midpoint = CGFloat(max(cards.count - 1, 0)) / 2
        return HStack(spacing: 44 - CardView.width * handScale) {
            ForEach(Array(cards.enumerated()), id: \.element) { index, card in
                let isLegal = viewModel.legalCards.contains(card)
                let isPlayable = isLegal && viewModel.isHumanTurn
                let normalized = cards.count > 1 ? (CGFloat(index) - midpoint) / midpoint : 0
                let angle = Double(normalized) * min(13, Double(cards.count))
                let arcRise: CGFloat = viewModel.reduceMotion ? 0 : -4 * (1 - normalized * normalized)

                CardView(card: card, isLegal: isLegal || !viewModel.isHumanTurn, highContrast: viewModel.highContrastCards)
                    .shadow(color: isPlayable ? .white.opacity(0.3) : .clear, radius: 6)
                    .frame(width: CardView.width * handScale, height: CardView.height * handScale)
                    .scaleEffect(handScale)
                    .rotationEffect(viewModel.reduceMotion ? .zero : .degrees(angle))
                    .offset(y: arcRise + (isPlayable && !viewModel.reduceMotion ? -10 : 0))
                    .animation(viewModel.reduceMotion ? nil : .spring(duration: 0.3), value: isPlayable)
                    .onTapGesture {
                        if isPlayable { viewModel.playCard(card) }
                        else { viewModel.explainWhyCardIsUnavailable(card) }
                    }
                    .zIndex(Double(index))
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .scale(scale: 0.5).combined(with: .opacity)
                    ))
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.visibleHumanHand)
    }

    // MARK: - Info & Indicators

    private var activeSeat: Seat? {
        switch viewModel.phase {
        case .bidding(let seat): seat
        case .playing(_, let seat): seat
        case .trickComplete(let winner): winner
        default: nil
        }
    }

    private func tableChrome(geo: GeometryProxy) -> some View {
        VStack {
            HStack(spacing: 10) {
                actionCircle(icon: "pause.fill", size: 11) {
                    viewModel.pauseGame()
                    withAnimation(.spring(duration: 0.25)) { showingPauseMenu = true }
                }
                .disabled(viewModel.isDealing || viewModel.isGameOver)
                .opacity(viewModel.isDealing || viewModel.isGameOver ? 0.45 : 1)
                .accessibilityLabel("Pause game")

                Text(statusText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.88))
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.38), in: Capsule())

                Spacer()

                HStack(spacing: 7) {
                    lastTrickTopButton

                    actionCircle(icon: scorecardExpanded ? "xmark" : "list.number", size: 11) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            scorecardExpanded.toggle()
                        }
                    }
                    .accessibilityLabel(scorecardExpanded ? "Close scorecard" : "Open scorecard")
                }
            }
            .padding(.horizontal, max(geo.safeAreaInsets.leading, geo.safeAreaInsets.trailing) + 12)
            .padding(.top, geo.safeAreaInsets.top + 8)
            Spacer()
        }
    }

    private var statusText: String {
        let round = "Round \(min(viewModel.roundNumber, viewModel.gameState.rules.roundCount))/\(viewModel.gameState.rules.roundCount)"
        guard case .playing = viewModel.phase else { return round }
        return "\(round)  •  Trick \(viewModel.currentTrickNumber)/13"
    }

    private var lastTrickTopButton: some View {
        Button {
            withAnimation(.spring(duration: 0.24)) { viewModel.openLastTrick() }
        } label: {
            Label("Last Trick", systemImage: "square.stack.fill")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.84))
                .padding(.horizontal, 9)
                .frame(height: 32)
                .background(.black.opacity(0.34), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.10), lineWidth: 1))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(viewModel.lastTrickPlays.isEmpty || viewModel.isDealing || viewModel.isGameOver)
        .opacity(viewModel.lastTrickPlays.isEmpty || viewModel.isDealing || viewModel.isGameOver ? 0.42 : 1)
        .accessibilityHint("Shows the four cards from the previous trick")
    }

    private func scorecardDrawer(geo: GeometryProxy) -> some View {
        let ledgerWidth: CGFloat = 220
        let drawerHeight: CGFloat = 190
        let visibleX = geo.size.width - geo.safeAreaInsets.trailing - ledgerWidth / 2 - 12
        let hiddenX = geo.size.width + ledgerWidth / 2 + 72

        return scorecardLedger
        .frame(width: ledgerWidth, height: drawerHeight)
        .shadow(color: .black.opacity(0.3), radius: 12, x: -5, y: 4)
        .position(
            x: scorecardExpanded ? visibleX : hiddenX,
            y: geo.size.height / 2
        )
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: scorecardExpanded)
        .zIndex(8)
    }

    private var scorecardLedger: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Scorecard")
                    .font(.caption)
                    .fontWeight(.black)
                    .foregroundColor(Color(red: 0.25, green: 0.10, blue: 0.04))
                Spacer()
                Text("5 rounds")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.18))

                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                        scorecardExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.18))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .padding(-9)
                }
                .buttonStyle(.plain)
            }

            scorecardHeader

            ForEach(1...viewModel.gameState.rules.roundCount, id: \.self) { roundNumber in
                HStack(spacing: 4) {
                    Text("R\(roundNumber)")
                        .fontWeight(roundNumber == viewModel.roundNumber ? .black : .semibold)
                        .frame(width: 22, alignment: .leading)

                    ForEach(scorecardSeats, id: \.self) { seat in
                        Text(scorecardRoundScore(roundNumber, seat: seat))
                            .fontWeight(seat == .bottom ? .black : .semibold)
                            .foregroundColor(roundNumber == viewModel.roundNumber ? Color(red: 0.25, green: 0.10, blue: 0.04) : Color(red: 0.18, green: 0.08, blue: 0.04))
                            .frame(width: 33, alignment: .trailing)
                    }
                }
                .font(.system(size: 11, weight: .medium, design: .rounded))
            }

            Divider()
                .overlay(Color(red: 0.45, green: 0.20, blue: 0.08).opacity(0.35))

            HStack(spacing: 4) {
                Text("T")
                    .fontWeight(.black)
                    .frame(width: 22, alignment: .leading)

                ForEach(scorecardSeats, id: \.self) { seat in
                    Text(viewModel.scoreString(scorecardTotal(for: seat)))
                        .fontWeight(.black)
                        .foregroundColor(seat == .bottom ? Color(red: 0.05, green: 0.34, blue: 0.80) : Color(red: 0.18, green: 0.08, blue: 0.04))
                        .frame(width: 33, alignment: .trailing)
                }
            }
            .font(.system(size: 11, weight: .black, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 7)
        .foregroundColor(Color(red: 0.25, green: 0.10, blue: 0.04))
        .background(Color(red: 0.99, green: 0.92, blue: 0.72))
    }

    private var scorecardSeats: [Seat] {
        [.bottom, .right, .top, .left]
    }

    private var scorecardHeader: some View {
        HStack(spacing: 4) {
            Text("Rd")
                .frame(width: 22, alignment: .leading)
            ForEach(scorecardSeats, id: \.self) { seat in
                Text(scorecardShortName(for: seat))
                    .frame(width: 33, alignment: .trailing)
            }
        }
        .font(.system(size: 10, weight: .black, design: .rounded))
        .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.18))
    }

    private func scorecardShortName(for seat: Seat) -> String {
        let name = viewModel.seatName(seat)
        return name.count > 5 ? String(name.prefix(4)) : name
    }

    private func scorecardRoundScore(_ roundNumber: Int, seat: Seat) -> String {
        if let round = viewModel.gameState.roundStates.first(where: { $0.roundNumber == roundNumber }),
           let bid = round.bids[seat],
           let tricks = round.tricksWon[seat] {
            return viewModel.scoreString(Scoring.roundScore(bid: bid, tricksWon: tricks))
        }

        if viewModel.showingRoundSummary,
           let item = viewModel.roundSummaryScores.first(where: { $0.seat == seat }),
           roundNumber == viewModel.roundNumber {
            return viewModel.scoreString(item.score)
        }

        return "-"
    }

    private func scorecardTotal(for seat: Seat) -> Double {
        var total = viewModel.scores[seat] ?? 0
        if viewModel.showingRoundSummary,
           let item = viewModel.roundSummaryScores.first(where: { $0.seat == seat }) {
            total += item.score
        }
        return total
    }

    private func actionCircle(icon: String, size: CGFloat, weight: Font.Weight = .bold, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: weight))
                .foregroundColor(.white.opacity(0.86))
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.34), in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Last Trick

    private var lastTrickOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(duration: 0.2)) {
                        viewModel.closeLastTrick()
                    }
                }

            TableOverlayCard(width: 300) {
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Button { withAnimation(.spring(duration: 0.2)) { viewModel.closeLastTrick() } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(TablePalette.faded)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                if let winner = viewModel.lastTrickWinner {
                    Text("\(viewModel.seatName(winner)) won")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(TablePalette.ink)
                }

                HStack(spacing: 6) {
                    ForEach(viewModel.lastTrickPlays, id: \.seat) { play in
                        VStack(spacing: 3) {
                            CardView(card: play.card, highContrast: viewModel.highContrastCards)
                                .scaleEffect(0.7)
                                .frame(width: CardView.width * 0.7, height: CardView.height * 0.7)
                                .shadow(
                                    color: play.seat == viewModel.lastTrickWinner ? .yellow.opacity(0.5) : .clear,
                                    radius: 4
                                )

                            Text(viewModel.seatName(play.seat))
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundColor(TablePalette.ink.opacity(0.7))
                        }
                    }
                }
            }
                .padding(.top, -18)
            }
        }
    }

    // MARK: - Offsets

    private func trickCardOffset(for seat: Seat) -> CGSize {
        switch seat {
        case .bottom: CGSize(width: 0, height: 48)
        case .top: CGSize(width: 0, height: -48)
        case .left: CGSize(width: -72, height: 0)
        case .right: CGSize(width: 72, height: 0)
        }
    }

    private func trickCardRotation(for seat: Seat) -> Angle {
        switch seat {
        case .left: .degrees(-90)
        case .right: .degrees(90)
        case .top, .bottom: .zero
        }
    }

    private func collectOffset(for seat: Seat) -> CGSize {
        switch seat {
        case .bottom: CGSize(width: 0, height: 150)
        case .top: CGSize(width: 0, height: -150)
        case .left: CGSize(width: -220, height: 0)
        case .right: CGSize(width: 220, height: 0)
        }
    }

    private func dealOffset(for seat: Seat, geo: GeometryProxy) -> CGSize {
        switch seat {
        case .bottom:
            CGSize(width: 0, height: max(118, geo.size.height * 0.30))
        case .right:
            CGSize(width: max(210, geo.size.width * 0.32), height: 0)
        case .top:
            CGSize(width: 0, height: -max(112, geo.size.height * 0.30))
        case .left:
            CGSize(width: -max(210, geo.size.width * 0.32), height: 0)
        }
    }

    // MARK: - Overlays

    private func bidSelectorOverlay(geo: GeometryProxy) -> some View {
        return TableOverlayCard(
            insets: EdgeInsets(top: 11, leading: 17, bottom: 11, trailing: 17),
            paperOpacity: 0.97
        ) {
            VStack(spacing: 8) {
            HStack(spacing: 10) {
                Text("Other calls")
                    .foregroundColor(TablePalette.ink.opacity(0.55))
                ForEach(Seat.allCases.filter { $0 != .bottom }, id: \.self) { seat in
                    if let bid = viewModel.bidForSeat(seat) {
                        Text("\(viewModel.seatName(seat)) \(bid)")
                            .foregroundColor(TablePalette.ink.opacity(0.78))
                    }
                }
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Your call")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                    Text("Expected tricks")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(TablePalette.ink.opacity(0.55))
                }
                .foregroundColor(TablePalette.ink)
                .frame(width: 96, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self, content: bidButton)
                    }
                    HStack(spacing: 6) {
                        ForEach(8...13, id: \.self, content: bidButton)
                    }
                }
            }
            }
        }
        .position(
            x: geo.size.width / 2,
            y: bidTrayCenterY(for: geo)
        )
    }

    private func bidTrayCenterY(for geo: GeometryProxy) -> CGFloat {
        let statusPillBottom = geo.safeAreaInsets.top + 8 + 34
        let handTop = bottomAreaCenterY(for: geo) - bottomAreaHeight / 2 - handVerticalLift
        let trayHalfHeight = bidTrayHeight / 2
        let minimumCenter = statusPillBottom + 8 + trayHalfHeight
        let maximumCenter = handTop - 12 - trayHalfHeight
        return (minimumCenter + maximumCenter) / 2
    }

    private func bidButton(_ bid: Int) -> some View {
        let recommended = viewModel.showBidSuggestion && bid == viewModel.recommendedBid
        return Button {
            viewModel.placeBid(bid)
        } label: {
            Text("\(bid)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .frame(width: 44, height: 44)
                .background(
                    recommended
                        ? TablePalette.accentGreen
                        : TablePalette.bidBrown.opacity(0.88)
                )
                .foregroundColor(.white)
                .clipShape(Circle())
                .overlay(
                    Circle().strokeBorder(
                        recommended ? TablePalette.gold : .white.opacity(0.18),
                        lineWidth: recommended ? 2 : 1
                    )
                )
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
        .accessibilityLabel(recommended ? "Bid \(bid), suggested" : "Bid \(bid)")
    }

    private var roundSummaryOverlay: some View {
        ZStack {
            overlayScrim
                .onTapGesture {
                    guard summaryTapIsArmed else { return }
                    viewModel.acknowledgeRoundSummary()
                }

            TableOverlayCard(width: 310) {
                VStack(spacing: 12) {
                    OverlayHeader(icon: "checkmark.seal.fill", title: "Round \(viewModel.roundSummaryNumber) Complete")

                if let result = viewModel.roundSummaryScores.first(where: { $0.seat == .bottom }) {
                    Text(result.tricks >= result.bid
                         ? "You met your bid: +\(viewModel.scoreString(result.score)) points"
                         : "You missed your bid: \(viewModel.scoreString(result.score)) points")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(result.tricks >= result.bid ? .green : .red)
                }

                    Grid(horizontalSpacing: 12, verticalSpacing: 6) {
                        GridRow {
                            Text("Player").frame(minWidth: 90, alignment: .leading)
                            Text("Bid").frame(minWidth: 28)
                            Text("Won").frame(minWidth: 30)
                            Text("Score").frame(minWidth: 44, alignment: .trailing)
                        }
                        .font(.caption.weight(.semibold)).foregroundStyle(TablePalette.faded)
                        ForEach(viewModel.roundSummaryScores, id: \.seat) { item in
                            GridRow {
                                Text(viewModel.seatName(item.seat)).lineLimit(1).truncationMode(.tail)
                                Text("\(item.bid)")
                                Text("\(item.tricks)")
                                Text(viewModel.scoreString(item.score)).foregroundStyle(item.score >= 0 ? TablePalette.accentGreen : TablePalette.destructiveRed)
                            }
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(TablePalette.ink)
                        }
                    }
                    .padding(12)
                    .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))

                    ZStack {
                        OverlayButton("Next Round") { viewModel.acknowledgeRoundSummary() }
                        if let deadline = viewModel.summaryAutoAdvanceDeadline {
                            TimelineView(.animation) { context in
                                let progress = max(0, min(1, deadline.timeIntervalSince(context.date) / viewModel.summaryAutoAdvanceInterval))
                                Circle().trim(from: 0, to: progress).stroke(TablePalette.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90)).padding(3).allowsHitTesting(false)
                            }
                        }
                    }
                }
            }
            .task {
                summaryTapIsArmed = false
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                summaryTapIsArmed = true
            }
        }
    }

    private var overlayScrim: some View {
        TablePalette.scrim
            .ignoresSafeArea()
    }

    private var pauseMenuOverlay: some View {
        ZStack {
            overlayScrim

            TableOverlayCard(width: 280) {
                VStack(spacing: 14) {
                    OverlayHeader(icon: "pause.fill", title: "Game Paused")

                styledButton("Resume", color: TablePalette.accentGreen) {
                    withAnimation(.spring(duration: 0.24)) { showingPauseMenu = false }
                    viewModel.resumeGame()
                }

                HStack(spacing: 10) {
                    OverlayUtilityButton(
                        viewModel.soundEnabled ? "Sound On" : "Sound Off",
                        icon: viewModel.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
                    ) {
                        viewModel.soundEnabled.toggle()
                    }

                    OverlayUtilityButton("Settings", icon: "gearshape.fill") {
                        pausedForSettings = true
                        showingPauseMenu = false
                        viewModel.showingSettings = true
                    }

                    OverlayUtilityButton("Stats", icon: "trophy.fill") {
                        showingPauseMenu = false
                        showingPausedStats = true
                    }

                    OverlayUtilityButton(
                        viewModel.fastPlayEnabled ? "Fast" : "Normal",
                        icon: viewModel.fastPlayEnabled ? "hare.fill" : "tortoise.fill"
                    ) {
                        viewModel.fastPlayEnabled.toggle()
                    }
                }

                Button(role: .destructive) {
                    showingPauseMenu = false
                    withAnimation(.spring(duration: 0.24)) { showingQuitConfirmation = true }
                } label: {
                    Label("Quit Game", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                }
            }
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            overlayScrim

            TableOverlayCard(width: 280) {
                VStack(spacing: 16) {
                if !viewModel.winners.isEmpty {
                    VStack(spacing: 4) {
                        HStack(spacing: 8) {
                            if viewModel.winners.contains(.bottom) {
                                Image(systemName: "crown.fill")
                                    .font(.title2)
                                    .foregroundColor(Color(red: 0.92, green: 0.72, blue: 0.10))
                            }
                            Text(gameOverTitle)
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(TablePalette.ink)
                        }
                        if let thok = viewModel.instantWin {
                            Text(thok.seat == .bottom
                                ? "Thok! You bid \(thok.bid) and made it!"
                                : "Thok! \(viewModel.seatName(thok.seat)) bid \(thok.bid) and made it!")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(red: 0.82, green: 0.38, blue: 0.12))
                        }
                    }
                }

                VStack(spacing: 0) {
                    HStack {
                        Text("Player")
                            .frame(width: 70, alignment: .leading)
                        Spacer()
                        Text("Score")
                            .frame(width: 50, alignment: .trailing)
                    }
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(TablePalette.ink.opacity(0.5))
                    .textCase(.uppercase)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)

                    ForEach(
                        Array(gameOverRanking.enumerated()),
                        id: \.element
                    ) { index, seat in
                        VStack(spacing: 0) {
                            if index > 0 {
                                Rectangle().fill(TablePalette.cardRuled.opacity(0.35)).frame(height: 1).padding(.leading, 14)
                            }
                            HStack {
                                HStack(spacing: 6) {
                                    if viewModel.winners.contains(seat) {
                                        Text("🏆")
                                            .font(.caption)
                                    }
                                    Text(viewModel.seatName(seat))
                                        .font(.system(size: 14, weight: viewModel.winners.contains(seat) ? .black : .semibold, design: .rounded))
                                }
                                Spacer()
                                Text(viewModel.scoreString(viewModel.scores[seat] ?? 0))
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(viewModel.winners.contains(seat) ? TablePalette.accentGreen : TablePalette.ink)
                            }
                            .foregroundColor(TablePalette.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                    }
                }
                .background(TablePalette.paper.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                HStack(spacing: 12) {
                    styledButton("Menu", color: TablePalette.woodButton) {
                        onQuit()
                    }
                    styledButton("Play Again", color: TablePalette.accentGreen) {
                        viewModel.startNewGame()
                    }
                }
                }
            }

            if viewModel.winners.contains(.bottom) {
                ConfettiView()
            }
        }
    }

    private var gameOverRanking: [Seat] {
        Seat.allCases.sorted {
            let lhs = viewModel.gameState.scoreTenths[$0] ?? 0
            let rhs = viewModel.gameState.scoreTenths[$1] ?? 0
            return lhs == rhs ? $0.rawValue < $1.rawValue : lhs > rhs
        }
    }

    private var gameOverTitle: String {
        let winners = viewModel.winners
        if winners.count == 1, let winner = winners.first {
            return winner == .bottom ? "You Win!" : "\(viewModel.seatName(winner)) Wins!"
        }
        let names = winners.map(viewModel.seatName)
        if names.count == 2 { return "\(names[0]) & \(names[1]) Tie!" }
        return "\(names.dropLast().joined(separator: ", ")) & \(names.last ?? "") Tie!"
    }

    private var quitConfirmationOverlay: some View {
        ZStack {
            overlayScrim
                .onTapGesture {
                    withAnimation(.spring(duration: 0.25)) {
                        showingQuitConfirmation = false
                    }
                    viewModel.resumeGame()
                }

            TableOverlayCard(width: 260) {
                VStack(spacing: 16) {
                    OverlayHeader(icon: "flag.fill", title: "Quit Game?")

                Text("Your progress will be lost.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(TablePalette.ink.opacity(0.6))

                HStack(spacing: 12) {
                    styledButton("Cancel", color: TablePalette.woodButton) {
                        withAnimation(.spring(duration: 0.25)) {
                            showingQuitConfirmation = false
                        }
                        viewModel.resumeGame()
                    }
                    styledButton("Quit", color: TablePalette.destructiveRed) {
                        onQuit()
                    }
                }
                }
            }
        }
    }

    private func styledButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        OverlayButton(label, color: color, action: action)
    }
}

struct SeatClusterView: View {
    let name: String
    let seat: Seat
    let bid: Int?
    let tricks: Int
    let isActive: Bool
    let isDealer: Bool
    let count: Int
    let cardBackStyle: Int
    let horizontal: Bool

    var body: some View {
        ZStack(alignment: horizontal ? .topTrailing : .bottom) {
            compactFan
                .offset(fanOffset)
            HStack(spacing: 7) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: seatIcon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 25, height: 25)
                    .background(accentColor.opacity(0.86), in: Circle())

                if isDealer {
                    Text("D")
                        .font(.system(size: 7, weight: .black, design: .rounded))
                        .foregroundColor(Color(red: 0.24, green: 0.12, blue: 0.03))
                        .frame(width: 13, height: 13)
                        .background(Color(red: 0.96, green: 0.76, blue: 0.28), in: Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.65), lineWidth: 1))
                        .offset(x: 3, y: 3)
                        .accessibilityLabel("Dealer")
                }
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 7) {
                    Text("Bid \(bid.map(String.init) ?? "–")")
                        .foregroundColor(bid == nil ? .white.opacity(0.46) : TablePalette.gold)
                    Text("Won \(tricks)")
                        .foregroundColor(.white.opacity(0.76))
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            }
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .background(Color.black.opacity(isActive ? 0.56 : 0.42), in: Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isActive ? TablePalette.gold : .white.opacity(0.12),
                    lineWidth: isActive ? 1.5 : 1
                )
            )
            countBadge
                .offset(countBadgeOffset)
        }
        .shadow(color: isActive ? TablePalette.gold.opacity(0.38) : .clear, radius: isActive ? 8 : 0)
        .scaleEffect(isActive ? 1.03 : 1)
        .animation(.spring(duration: 0.2), value: bid)
        .animation(.spring(duration: 0.2), value: tricks)
        .animation(.easeInOut(duration: 0.22), value: isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name), \(isDealer ? "dealer, " : "")\(bid.map { "bid \($0)" } ?? "has not bid"), won \(tricks), \(count) cards")
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var seatIcon: String {
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

    private var compactFan: some View {
        let visibleCount = min(count, 4)
        let midpoint = CGFloat(max(visibleCount - 1, 0)) / 2
        return ZStack {
            ForEach(0..<visibleCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: cardBackColors,
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
                    .rotationEffect(.degrees(sideRotation + (Double(index) - Double(visibleCount - 1) / 2) * 6))
                    .offset(
                        x: horizontal ? (CGFloat(index) - midpoint) * 8 : 0,
                        y: horizontal ? 0 : (CGFloat(index) - midpoint) * 8
                    )
                    .zIndex(Double(index))
            }
        }
        .animation(.spring(duration: 0.2), value: count)
        .accessibilityHidden(true)
    }

    private var sideRotation: Double {
        switch seat {
        case .left: 90
        case .right: -90
        default: 0
        }
    }

    private var fanOffset: CGSize {
        switch seat {
        case .top: CGSize(width: 32, height: -17)
        case .left: CGSize(width: 67, height: 0)
        case .right: CGSize(width: -67, height: 0)
        case .bottom: .zero
        }
    }

    private var countBadgeOffset: CGSize {
        switch seat {
        case .top: CGSize(width: 48, height: -13)
        case .left: CGSize(width: 69, height: -23)
        case .right: CGSize(width: -69, height: -23)
        case .bottom: .zero
        }
    }

    private var cardBackColors: [Color] {
        cardBackStyle == 0
            ? [Color(red: 0.08, green: 0.45, blue: 0.92), Color(red: 0.02, green: 0.22, blue: 0.58)]
            : [Color(red: 0.88, green: 0.22, blue: 0.16), Color(red: 0.48, green: 0.06, blue: 0.08)]
    }

    private var countBadge: some View {
        Text("\(count)")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(.black.opacity(0.78), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 1))
            .accessibilityHidden(true)
    }
}
