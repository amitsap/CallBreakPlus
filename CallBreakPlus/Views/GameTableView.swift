import StoreKit
import SwiftUI

struct GameTableView: View {
    @Bindable var viewModel: GameViewModel
    let onQuit: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var showingQuitConfirmation = false
    @State private var showingPauseMenu = false
    @State private var turnPulse = false
    /// A panel opened from Pause; closing it returns to Pause.
    @State private var pausedPanel: PanelKind?
    /// The Pro panel, opened from the game-over Pro card.
    @State private var showingProPanel = false
    @State private var summaryTapIsArmed = false
    @State private var selectedBid: Int?

    var body: some View {
        GeometryReader { geo in
            let layout = TableLayout(size: geo.size)
            ZStack {
                TableBackground()
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.skipDeal() }

                directionRing
                    .position(layout.trickCenter)

                centerArea(layout: layout)
                    .position(layout.trickCenter)

                topArea
                    .position(layout.topSeatCenter)

                bottomArea(layout: layout)
                    .position(x: layout.size.width / 2, y: layout.bottomAreaCenterY)

                humanTrickCardLayer
                    .position(layout.trickCenter)

                leftSeat
                    .frame(width: TableLayout.seatPlateMaxWidth, alignment: .leading)
                    .position(x: layout.leftSeatFrameCenterX, y: layout.leftSeatCenter.y)
                rightSeat
                    .frame(width: TableLayout.seatPlateMaxWidth, alignment: .trailing)
                    .position(x: layout.rightSeatFrameCenterX, y: layout.rightSeatCenter.y)

                tableChrome

                if let message = viewModel.invalidMoveMessage {
                    Text(message)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.82), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 1))
                        .position(layout.toastCenter)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                        .zIndex(10)
                        .accessibilityAddTraits(.isStaticText)
                }

                if viewModel.showingBidSelector {
                    bidSelectorOverlay(layout: layout)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }

                if viewModel.showingRoundSummary {
                    roundSummaryOverlay
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                if viewModel.showingGameOver {
                    gameOverOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .accessibilityHidden(showingProPanel)
                }

                if viewModel.showingLastTrick {
                    lastTrickOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        .zIndex(9)
                }

                if viewModel.showingStandings {
                    standingsOverlay
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

                if let panel = pausedPanel {
                    PanelScreen(kind: panel, viewModel: viewModel, gameInProgress: true, onClose: closePausedPanel)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        .zIndex(20)
                }

                if showingProPanel {
                    PaperPanel(onClose: { setShowingProPanel(false) }) {
                        ProPanel(onClose: { setShowingProPanel(false) })
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
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
        .onChange(of: viewModel.showingGameOver) { _, showing in
            guard showing, viewModel.reviewDueAtGameOver else { return }
            requestReview()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase != .active else { return }
            guard !showingPauseMenu, pausedPanel == nil,
                  !showingQuitConfirmation, !viewModel.showingRoundSummary, !viewModel.showingLastTrick,
                  !viewModel.showingStandings,
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
    }

    /// Faint arrows printed on the felt around the trick, showing that play
    /// runs anti-clockwise. Static, so Reduce Motion doesn't apply.
    private var directionRing: some View {
        let radii = TableLayout.directionRingRadii
        return ZStack {
            Ellipse()
                .stroke(.white.opacity(0.10), style: StrokeStyle(lineWidth: 1.5, dash: [2, 7]))
                .frame(width: radii.width * 2, height: radii.height * 2)

            ForEach([45.0, 135.0, 225.0, 315.0], id: \.self) { degrees in
                let t = degrees * .pi / 180
                // Anti-clockwise on screen, where y grows downward, is decreasing t.
                let heading = atan2(-radii.height * cos(t), radii.width * sin(t))
                Path { path in
                    path.move(to: CGPoint(x: 2.5, y: 0.5))
                    path.addLine(to: CGPoint(x: 9.5, y: 6))
                    path.addLine(to: CGPoint(x: 2.5, y: 11.5))
                }
                .stroke(.white.opacity(0.32), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 12, height: 12)
                .rotationEffect(.radians(heading))
                .offset(x: radii.width * cos(t), y: radii.height * sin(t))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // MARK: - Seats

    private var topArea: some View {
        seatPlate(.top)
            .frame(width: TableLayout.seatPlateMaxWidth, height: TableLayout.seatPlateHeight)
    }

    private func bottomArea(layout: TableLayout) -> some View {
        VStack(spacing: 0) {
            ZStack {
                playerHandView
                    .frame(width: layout.handWidth, height: TableLayout.bottomAreaHeight)
                    .shadow(
                        color: viewModel.legalCards.isEmpty
                            ? .clear
                            : TablePalette.gold.opacity(turnPulse ? 0.20 : 0.09),
                        radius: turnPulse ? 10 : 5,
                        y: -3
                    )
                    .offset(y: -TableLayout.handVerticalLift)

                humanHandPill
                    .offset(y: 18)
            }
        }
        .frame(width: layout.size.width, height: TableLayout.bottomAreaHeight)
        .animation(.easeInOut(duration: 0.4), value: viewModel.isHumanTurn)
        .onChange(of: viewModel.isHumanTurn) { _, isHuman in
            if isHuman {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    turnPulse = true
                }
            } else {
                turnPulse = false
            }
        }
    }

    private var leftSeat: some View {
        seatPlate(.left)
    }

    private var rightSeat: some View {
        seatPlate(.right)
    }

    private func seatPlate(_ seat: Seat) -> SeatPlateView {
        SeatPlateView(
            name: viewModel.seatName(seat), seat: seat,
            bid: viewModel.bidForSeat(seat), tricks: viewModel.tricksForSeat(seat),
            isActive: activeSeat == seat, isDealer: viewModel.currentRound?.dealer == seat,
            count: viewModel.handCountForSeat(seat), cardBack: viewModel.effectiveCardBack
        )
    }

    private var humanHandPill: some View {
        let bid = viewModel.bidForSeat(.bottom)
        let won = viewModel.tricksForSeat(.bottom)
        return HStack(spacing: 6) {
            if viewModel.currentRound?.dealer == .bottom {
                Text("D")
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundStyle(TablePalette.ink)
                    .frame(width: 16, height: 16)
                    .background(TablePalette.gold, in: Circle())
            }

            Text("You")
            if let bid {
                CallMeter(bid: bid, won: won)
                if bid <= CallMeter.maxPips {
                    Text("\(won) of \(bid)")
                        .foregroundStyle(TablePalette.gold)
                }
            }

            if let prompt = humanTurnPrompt {
                Text(bid == nil ? prompt : "· \(prompt)")
                    .foregroundStyle(TablePalette.gold)
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
        .animation(.easeInOut(duration: 0.2), value: humanTurnPrompt)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(humanHandAccessibilityLabel)
    }

    /// Shown on your nameplate as soon as it is your move.
    private var humanTurnPrompt: String? {
        if !viewModel.legalCards.isEmpty { return "Your turn" }
        if viewModel.isHumanTurn, case .bidding = viewModel.phase { return "Choose your call" }
        return nil
    }

    private var humanHandAccessibilityLabel: String {
        let dealer = viewModel.currentRound?.dealer == .bottom ? "Dealer, " : ""
        let bid = viewModel.bidForSeat(.bottom).map(String.init) ?? "not bid"
        let prompt = humanTurnPrompt.map { ", \($0.lowercased())" } ?? ""
        return "\(dealer)You, won \(viewModel.tricksForSeat(.bottom)), bid \(bid)\(prompt)"
    }

    // MARK: - Center Trick Area

    private func centerArea(layout: TableLayout) -> some View {
        ZStack {
            if viewModel.isDealing {
                CardView(
                    card: Card(suit: .spades, rank: .ace),
                    isFaceUp: false,
                    cardBack: viewModel.effectiveCardBack
                )
                .scaleEffect(0.68)
                .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Dealing")
                .accessibilityHint("Skips the deal")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { viewModel.skipDeal() }

                if let seat = viewModel.dealingCardSeat {
                    CardView(
                        card: Card(suit: .spades, rank: .ace),
                        isFaceUp: false,
                        cardBack: viewModel.effectiveCardBack
                    )
                    .scaleEffect(0.56)
                    .offset(viewModel.dealingCardInFlight ? layout.dealOffset(for: seat) : .zero)
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
                    .overlay(winningRing(visible: viewModel.winningTrickSeat == play.seat))
                    .rotationEffect(trickCardRotation(for: play.seat))
                    .scaleEffect(collecting ? 0.54 : (isWinner ? 0.98 : TableLayout.restingTrickCardScale))
                    .offset(collecting
                        ? TableLayout.collectOffset(for: viewModel.collectToSeat ?? play.seat)
                        : TableLayout.trickCardOffset(for: play.seat))
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

            if let leader = viewModel.trickLeader, leader != .bottom {
                ledTab(for: leader, scale: TableLayout.restingTrickCardScale)
                    .zIndex(2)
            }
        }
        .frame(width: 280, height: 190)
        .animation(.spring(duration: 0.2), value: viewModel.winningTrickSeat)
    }

    private var humanTrickCardLayer: some View {
        ZStack {
            if let play = viewModel.currentTrickPlays.first(where: { $0.seat == .bottom }) {
                let collecting = viewModel.trickCardsToCollect && !viewModel.reduceMotion
                CardView(card: play.card, highContrast: viewModel.highContrastCards)
                    .overlay(winningRing(visible: viewModel.winningTrickSeat == .bottom))
                    .scaleEffect(collecting ? 0.54 : TableLayout.humanTrickCardScale)
                    .offset(collecting ? TableLayout.collectOffset(for: viewModel.collectToSeat ?? .bottom) : TableLayout.trickCardOffset(for: .bottom))
                    .shadow(color: viewModel.trickWinner == .bottom ? .yellow.opacity(0.68) : .white.opacity(0.44), radius: viewModel.trickWinner == .bottom ? 11 : 7, y: 2)
                    .opacity(collecting ? 0 : (viewModel.trickWinner == nil || viewModel.trickWinner == .bottom ? 1 : 0.72))

                if viewModel.trickLeader == .bottom {
                    ledTab(for: .bottom, scale: TableLayout.humanTrickCardScale)
                }
            }
        }
        .frame(width: 280, height: 190)
        .animation(.spring(duration: 0.2), value: viewModel.winningTrickSeat)
        .allowsHitTesting(false)
    }

    /// Gold ring on the card winning the trick right now.
    private func winningRing(visible: Bool) -> some View {
        RoundedRectangle(cornerRadius: CardView.cornerRadius + 2)
            .strokeBorder(TablePalette.gold, lineWidth: 3)
            .padding(-3)
            .opacity(visible ? 1 : 0)
            .accessibilityHidden(true)
    }

    /// "Led" tab on the inner edge of the lead card, toward the trick centre,
    /// so it reads upright whichever way the card is turned.
    private func ledTab(for seat: Seat, scale: CGFloat) -> some View {
        let offset = TableLayout.trickCardOffset(for: seat)
        let inward = CardView.height * scale / 2
        let tabOffset: CGSize = switch seat {
        case .top: CGSize(width: offset.width, height: offset.height + inward)
        case .bottom: CGSize(width: offset.width, height: offset.height - inward)
        case .left: CGSize(width: offset.width + inward, height: offset.height)
        case .right: CGSize(width: offset.width - inward, height: offset.height)
        }
        let collecting = viewModel.trickCardsToCollect && !viewModel.reduceMotion
        return Text("Led")
            .font(.system(size: 9, weight: .black, design: .rounded))
            .foregroundStyle(TablePalette.ink)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(TablePalette.gold, in: Capsule())
            .offset(tabOffset)
            .opacity(collecting ? 0 : 1)
            .accessibilityHidden(true)
    }

    // MARK: - Player Hand

    private var playerHandView: some View {
        let cards = viewModel.visibleHumanHand
        let fan = HandFan(count: cards.count)
        // Non-empty exactly on your play turn, so the hand stays bright while
        // bidding and during bot turns.
        let legal = viewModel.legalCards
        // The fan and the lift are still pictures, so Reduce Motion keeps them
        // and drops only the lift's animation.
        return ZStack {
            ForEach(Array(cards.enumerated()), id: \.element) { index, card in
                let isPlayable = legal.contains(card)

                CardView(card: card, isLegal: legal.isEmpty || isPlayable, isInteractive: !legal.isEmpty, highContrast: viewModel.highContrastCards)
                    .shadow(color: isPlayable ? .white.opacity(0.3) : .clear, radius: 6)
                    .frame(width: CardView.width * HandFan.scale, height: CardView.height * HandFan.scale)
                    .scaleEffect(HandFan.scale)
                    .rotationEffect(.degrees(fan.angle(at: index)))
                    .offset(fan.offset(at: index, lifted: isPlayable))
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

    private var tableChrome: some View {
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.38), in: Capsule())
                    .frame(maxWidth: TableLayout.statusPillMaxWidth, alignment: .leading)

                Spacer()

                HStack(spacing: 7) {
                    lastTrickTopButton
                    standingsChip
                }
            }
            .padding(.horizontal, TableLayout.chromeInset)
            .padding(.top, TableLayout.chromeTop)
            Spacer()
        }
    }

    private var statusText: String {
        let round = "Round \(min(viewModel.roundNumber, viewModel.gameState.rules.roundCount))/\(viewModel.gameState.rules.roundCount)"
        guard case .playing = viewModel.phase else { return round }
        return "\(round) · Trick \(viewModel.currentTrickNumber)/13"
    }

    private var lastTrickTopButton: some View {
        let unavailable = viewModel.lastTrickPlays.isEmpty || viewModel.isDealing || viewModel.isGameOver
        return actionCircle(icon: "square.stack.fill", size: 12) {
            withAnimation(.spring(duration: 0.24)) { viewModel.openLastTrick() }
        }
        .disabled(unavailable)
        .opacity(unavailable ? 0.42 : 1)
        .accessibilityLabel("Last trick")
        .accessibilityHint("Shows the four cards from the previous trick")
    }

    /// Your rank and total; opens the Standings panel.
    private var standingsChip: some View {
        let standing = viewModel.standingRank(.bottom)
        let rank = GameViewModel.rankLabel(rank: standing.rank, tied: standing.tied)
        let total = Scoring.score(fromTenths: viewModel.standingTotalsTenths[.bottom] ?? 0)
        let points = "\(viewModel.scoreString(total)) \(total == 1 ? "pt" : "pts")"
        let unavailable = viewModel.isDealing || viewModel.isGameOver
        return Button {
            withAnimation(.spring(duration: 0.24)) { viewModel.openStandings() }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TablePalette.gold)
                (Text(rank).foregroundColor(TablePalette.gold).fontWeight(.black)
                    + Text(" · \(points)").foregroundColor(.white.opacity(0.92)))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(.black.opacity(0.42), in: Capsule())
            .overlay(Capsule().strokeBorder(TablePalette.gold.opacity(0.5), lineWidth: 1))
            .frame(maxWidth: TableLayout.standingsChipMaxWidth)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(unavailable)
        .opacity(unavailable ? 0.45 : 1)
        .accessibilityLabel("Standings: you're \(standing.tied ? "tied " : "")\(GameViewModel.rankLabel(rank: standing.rank, tied: false)) with \(points)")
        .accessibilityHint("Shows everyone's totals")
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
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: 76)
                        }
                    }
                }
            }
                .padding(.top, -18)
            }
        }
    }

    // MARK: - Standings

    private var standingsOverlay: some View {
        let rounds = Array(1...viewModel.gameState.rules.roundCount)
        return ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(duration: 0.2)) { viewModel.closeStandings() }
                }

            TableOverlayCard(insets: EdgeInsets(top: 12, leading: 18, bottom: 16, trailing: 10)) {
                VStack(spacing: 6) {
                    HStack {
                        Text("Standings")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundStyle(TablePalette.ink)
                        Spacer()
                        Button { withAnimation(.spring(duration: 0.2)) { viewModel.closeStandings() } } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(TablePalette.faded)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close standings")
                    }

                    VStack(spacing: 4) {
                        standingsColumns(
                            rank: Text(""), player: Text("Player"),
                            rounds: rounds.map { Text("R\($0)") }, now: Text("Now"), total: Text("Total")
                        )
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(TablePalette.faded)
                        .accessibilityHidden(true)

                        ForEach(viewModel.standingsOrder, id: \.self) { seat in
                            standingsRow(seat, rounds: rounds)
                        }
                    }
                    .padding(.trailing, 8)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func standingsColumns(rank: Text, player: Text, rounds: [Text], now: Text, total: Text) -> some View {
        HStack(spacing: 0) {
            rank.frame(width: 40, alignment: .leading)
            player.lineLimit(1).truncationMode(.tail).frame(width: 96, alignment: .leading)
            ForEach(rounds.indices, id: \.self) { index in
                rounds[index].lineLimit(1).minimumScaleFactor(0.8).frame(width: 36, alignment: .trailing)
            }
            now.frame(width: 50, alignment: .trailing)
            total.frame(width: 54, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
    }

    private func standingsRow(_ seat: Seat, rounds: [Int]) -> some View {
        let standing = viewModel.standingRank(seat)
        let total = Scoring.score(fromTenths: viewModel.standingTotalsTenths[seat] ?? 0)
        let roundTexts = rounds.map { round -> Text in
            guard let tenths = viewModel.roundScoreTenths(roundNumber: round, seat: seat) else {
                return Text("–").foregroundColor(TablePalette.faded)
            }
            return Text(viewModel.scoreString(Scoring.score(fromTenths: tenths)))
                .foregroundColor(tenths < 0 ? TablePalette.destructiveRed : TablePalette.ink)
        }
        return standingsColumns(
            rank: Text(GameViewModel.rankLabel(rank: standing.rank, tied: standing.tied)).foregroundColor(TablePalette.faded),
            player: Text(viewModel.seatName(seat)),
            rounds: roundTexts,
            now: Text(currentCallText(seat)).foregroundColor(TablePalette.faded),
            total: Text(viewModel.scoreString(total)).fontWeight(.black)
        )
        .font(.system(size: 14, weight: seat == .bottom ? .heavy : .semibold, design: .rounded))
        .foregroundStyle(TablePalette.ink)
        .background(seat == .bottom ? TablePalette.gold.opacity(0.24) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(standing.tied ? "Tied " : "")\(GameViewModel.rankLabel(rank: standing.rank, tied: false)), \(viewModel.seatName(seat)), \(viewModel.scoreString(total)) points, \(currentCallAccessibility(seat))")
    }

    /// Tricks won of the call this round, "–" before the seat has called.
    private func currentCallText(_ seat: Seat) -> String {
        guard let bid = viewModel.bidForSeat(seat) else { return "–" }
        return "\(viewModel.tricksForSeat(seat))/\(bid)"
    }

    private func currentCallAccessibility(_ seat: Seat) -> String {
        guard let bid = viewModel.bidForSeat(seat) else { return "has not called this round" }
        return "won \(viewModel.tricksForSeat(seat)) of \(bid) this round"
    }

    // MARK: - Offsets

    private func trickCardRotation(for seat: Seat) -> Angle {
        switch seat {
        case .left: .degrees(-90)
        case .right: .degrees(90)
        case .top, .bottom: .zero
        }
    }

    // MARK: - Overlays

    private func bidSelectorOverlay(layout: TableLayout) -> some View {
        let thokThreshold = viewModel.gameState.rules.instantWinBid
        return TableOverlayCard(
            insets: EdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18),
            paperOpacity: 0.97
        ) {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text("Your call")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(TablePalette.ink)
                    if viewModel.showBidSuggestion {
                        Text("Suggested \(viewModel.recommendedBid)")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundStyle(TablePalette.accentGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(TablePalette.accentGreen.opacity(0.14), in: Capsule())
                    }
                    Spacer(minLength: 8)
                    Text("Called so far: \(viewModel.calledSoFar) of 13")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(TablePalette.faded)
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(1...7, id: \.self) { bidChip($0, thokThreshold: thokThreshold) }
                    }
                    HStack(spacing: 6) {
                        ForEach(8...13, id: \.self) { bidChip($0, thokThreshold: thokThreshold) }
                        callButton
                    }
                }

                HStack(spacing: 8) {
                    Text(selectedBid.map { GameViewModel.callStakes(bid: $0, thokThreshold: thokThreshold) } ?? "Tap a number, then Call.")
                        .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                        .foregroundColor(TablePalette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: 8)
                    if let thokThreshold {
                        Text("Gold ring = Thok (\(thokThreshold)+)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(TablePalette.faded)
                    }
                }
            }
            .frame(height: TableLayout.bidTrayHeight - 20)
        }
        .frame(width: TableLayout.bidTrayWidth)
        .onAppear {
            selectedBid = viewModel.showBidSuggestion ? viewModel.recommendedBid : nil
        }
        .position(
            x: layout.size.width / 2,
            y: layout.bidTrayCenterY
        )
    }

    /// A tap selects; only the Call button commits.
    private func bidChip(_ bid: Int, thokThreshold: Int?) -> some View {
        let selected = selectedBid == bid
        let suggested = viewModel.showBidSuggestion && bid == viewModel.recommendedBid
        let thok = thokThreshold.map { bid >= $0 } ?? false
        let ring: Color = selected ? TablePalette.gold : (thok ? TablePalette.gold : (suggested ? TablePalette.accentGreen : .white.opacity(0.18)))
        return Button {
            withAnimation(.spring(duration: 0.18)) { selectedBid = bid }
        } label: {
            Text("\(bid)")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .frame(width: 44, height: 44)
                .background(selected ? TablePalette.accentGreen : TablePalette.bidBrown.opacity(0.88))
                .foregroundColor(.white)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(ring, lineWidth: selected || thok || suggested ? 2.5 : 1))
                .scaleEffect(selected ? 1.06 : 1)
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(bid)\(suggested ? ", suggested" : "")\(thok ? ", Thok" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var callButton: some View {
        Button {
            guard let bid = selectedBid else { return }
            viewModel.placeBid(bid)
        } label: {
            Text(selectedBid.map { "Call \($0)" } ?? "Call")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .foregroundStyle(.white)
                .background(LinearGradient(colors: [TablePalette.accentGreen, TablePalette.accentGreen.opacity(0.75)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.white.opacity(0.25), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(selectedBid == nil)
        .opacity(selectedBid == nil ? 0.45 : 1)
        .accessibilityLabel(selectedBid.map { "Call \($0)" } ?? "Call")
        .accessibilityHint(selectedBid == nil ? "Choose a number first" : "Commits your call")
    }

    private var roundSummaryOverlay: some View {
        ZStack {
            overlayScrim
                .onTapGesture {
                    guard summaryTapIsArmed else { return }
                    viewModel.acknowledgeRoundSummary()
                }

            TableOverlayCard(width: 440, insets: EdgeInsets(top: 14, leading: 18, bottom: 12, trailing: 18)) {
                VStack(spacing: 10) {
                    Text("Round \(viewModel.roundSummaryNumber) of \(viewModel.gameState.rules.roundCount) complete")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .textCase(.uppercase)
                        .kerning(1)
                        .foregroundStyle(TablePalette.faded)
                        .accessibilityAddTraits(.isHeader)

                    if let result = viewModel.roundSummaryScores.first(where: { $0.seat == .bottom }) {
                        roundResultBanner(bid: result.bid, tricks: result.tricks, score: result.score)
                    }

                    VStack(spacing: 2) {
                        summaryColumns(
                            rank: Text("#"), player: Text("Player"), call: Text("Call"), won: Text("Won"),
                            round: Text("Round"), total: Text("Total"), change: Text("")
                        )
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .textCase(.uppercase)
                        .foregroundStyle(TablePalette.faded)
                        .accessibilityHidden(true)

                        ForEach(viewModel.standingsOrder, id: \.self) { seat in
                            summaryRow(seat)
                        }
                    }

                    VStack(spacing: 4) {
                        OverlayButton("Next round") { viewModel.acknowledgeRoundSummary() }
                            .overlay(alignment: .trailing) {
                                if let deadline = viewModel.summaryAutoAdvanceDeadline {
                                    TimelineView(.animation) { context in
                                        let progress = max(0, min(1, deadline.timeIntervalSince(context.date) / viewModel.summaryAutoAdvanceInterval))
                                        Circle().trim(from: 0, to: progress).stroke(TablePalette.gold, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
                                    }
                                    .frame(width: 22, height: 22)
                                    .padding(.trailing, 12)
                                    .allowsHitTesting(false)
                                    .accessibilityHidden(true)
                                }
                            }
                            .frame(width: 220)

                        if let deadline = viewModel.summaryAutoAdvanceDeadline {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                let seconds = max(1, Int(deadline.timeIntervalSince(context.date).rounded(.up)))
                                Text("Continues in \(seconds) s · tap anywhere to go now")
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(TablePalette.faded)
                            .accessibilityHidden(true)
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

    /// Your round in words, colour and an icon, never colour alone.
    private func roundResultBanner(bid: Int, tricks: Int, score: Double) -> some View {
        let made = tricks >= bid
        let tint = made ? TablePalette.accentGreen : TablePalette.destructiveRed
        let signed = score >= 0 ? "+\(viewModel.scoreString(score))" : viewModel.scoreString(score)
        return HStack(spacing: 10) {
            Image(systemName: made ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 24, weight: .bold))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(made ? "You made your call" : "You missed your call")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                Text("Called \(bid) · won \(tricks) · \(signed) this round")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(TablePalette.ink.opacity(0.8))
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    private func summaryColumns(rank: Text, player: some View, call: Text, won: Text, round: Text, total: Text, change: some View) -> some View {
        HStack(spacing: 0) {
            rank.frame(width: 26, alignment: .leading)
            player.frame(maxWidth: .infinity, alignment: .leading)
            call.frame(width: 44)
            won.frame(width: 44)
            round.frame(width: 60, alignment: .trailing)
            total.frame(width: 58, alignment: .trailing)
            change.frame(width: 38, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
    }

    private func summaryRow(_ seat: Seat) -> some View {
        let standing = viewModel.standingRank(seat)
        let item = viewModel.roundSummaryScores.first { $0.seat == seat }
        let score = item?.score ?? 0
        let total = Scoring.score(fromTenths: viewModel.standingTotalsTenths[seat] ?? 0)
        let change = viewModel.summaryRankChange(seat)
        return summaryColumns(
            rank: Text("\(standing.rank)").foregroundColor(TablePalette.faded),
            player: HStack(spacing: 7) {
                SeatAvatar(seat: seat, size: 20)
                Text(viewModel.seatName(seat)).lineLimit(1).truncationMode(.tail)
            },
            call: Text(item.map { "\($0.bid)" } ?? "–"),
            won: Text(item.map { "\($0.tricks)" } ?? "–"),
            round: Text(score >= 0 ? "+\(viewModel.scoreString(score))" : viewModel.scoreString(score))
                .foregroundColor(score >= 0 ? TablePalette.accentGreen : TablePalette.destructiveRed),
            total: Text(viewModel.scoreString(total)).fontWeight(.black),
            change: rankChangeMark(change)
        )
        .font(.system(size: 15, weight: seat == .bottom ? .heavy : .semibold, design: .rounded))
        .foregroundStyle(TablePalette.ink)
        .frame(height: 30)
        .background(seat == .bottom ? TablePalette.gold.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 7))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summaryRowAccessibility(seat, standing: standing, item: item, total: total, change: change))
    }

    @ViewBuilder
    private func rankChangeMark(_ change: Int?) -> some View {
        if let change, change != 0 {
            HStack(spacing: 2) {
                Image(systemName: change > 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 9, weight: .black))
                Text("\(abs(change))")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(change > 0 ? TablePalette.accentGreen : TablePalette.destructiveRed)
        } else {
            Text("–").foregroundStyle(TablePalette.faded)
        }
    }

    private func summaryRowAccessibility(
        _ seat: Seat, standing: (rank: Int, tied: Bool),
        item: (seat: Seat, bid: Int, tricks: Int, score: Double)?, total: Double, change: Int?
    ) -> String {
        var parts = ["\(standing.tied ? "Tied " : "")\(GameViewModel.rankLabel(rank: standing.rank, tied: false))", viewModel.seatName(seat)]
        if let item {
            parts.append("called \(item.bid), won \(item.tricks), \(viewModel.scoreString(item.score)) this round")
        }
        parts.append("\(viewModel.scoreString(total)) total")
        if let change, change != 0 {
            parts.append(change > 0 ? "up \(change)" : "down \(-change)")
        }
        return parts.joined(separator: ", ")
    }

    private var overlayScrim: some View {
        TablePalette.scrim
            .ignoresSafeArea()
    }

    private var pauseMenuOverlay: some View {
        ZStack {
            overlayScrim

            TableOverlayCard(width: 520, insets: EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 22)) {
                HStack(alignment: .top, spacing: 20) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(pauseCaption)
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .textCase(.uppercase)
                            .kerning(1)
                            .foregroundStyle(TablePalette.faded)
                        Text("Paused")
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(TablePalette.ink)
                            .accessibilityAddTraits(.isHeader)
                        Text("The bots wait until you resume.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(TablePalette.faded)
                            .padding(.top, 2)

                        Spacer(minLength: 18)

                        VStack(spacing: 10) {
                            OverlayButton("Resume") {
                                withAnimation(.spring(duration: 0.24)) { showingPauseMenu = false }
                                viewModel.resumeGame()
                            }
                            Button {
                                showingPauseMenu = false
                                withAnimation(.spring(duration: 0.24)) { showingQuitConfirmation = true }
                            } label: {
                                Text("Quit game…")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(TablePalette.destructiveRed)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(TablePalette.destructiveRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(TablePalette.destructiveRed.opacity(0.45), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 210)
                    .frame(maxHeight: .infinity, alignment: .top)

                    Rectangle()
                        .fill(TablePalette.cardRuled.opacity(0.5))
                        .frame(width: 1)

                    VStack(spacing: 0) {
                        pauseRow {
                            Toggle("Sound", isOn: $viewModel.soundEnabled)
                                .tint(TablePalette.accentGreen)
                        }
                        pauseRowDivider
                        pauseRow {
                            HStack {
                                Text("Speed")
                                Spacer()
                                Picker("Speed", selection: $viewModel.fastPlayEnabled) {
                                    Text("Normal").tag(false)
                                    Text("Fast").tag(true)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 130)
                            }
                        }
                        pauseRowDivider
                        pauseLink("How to play") {
                            openPausedPanel(.howToPlay)
                        }
                        pauseRowDivider
                        pauseLink("Settings") {
                            openPausedPanel(.settings)
                        }
                        pauseRowDivider
                        pauseLink("Statistics") {
                            openPausedPanel(.statistics)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var pauseCaption: String {
        let round = "Round \(min(viewModel.roundNumber, viewModel.gameState.rules.roundCount)) of \(viewModel.gameState.rules.roundCount)"
        guard case .playing = viewModel.phase else { return round }
        return "\(round) · Trick \(viewModel.currentTrickNumber)"
    }

    private func pauseRow(@ViewBuilder content: () -> some View) -> some View {
        content()
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(TablePalette.ink)
            .frame(minHeight: 44)
    }

    private func pauseLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            pauseRow {
                HStack {
                    Text(title)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(TablePalette.faded)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }

    private var pauseRowDivider: some View {
        Rectangle()
            .fill(TablePalette.cardRuled.opacity(0.45))
            .frame(height: 1)
    }

    private func openPausedPanel(_ panel: PanelKind) {
        withAnimation(.spring(duration: 0.25)) {
            showingPauseMenu = false
            pausedPanel = panel
        }
    }

    /// Back to Pause, still paused: only Resume resumes.
    private func closePausedPanel() {
        withAnimation(.spring(duration: 0.25)) {
            pausedPanel = nil
            showingPauseMenu = true
        }
    }

    private func setShowingProPanel(_ showing: Bool) {
        withAnimation(.spring(duration: 0.25)) { showingProPanel = showing }
    }

    private var gameOverOverlay: some View {
        ZStack {
            overlayScrim

            TableOverlayCard(width: 500, insets: EdgeInsets(top: 20, leading: 22, bottom: 20, trailing: 16)) {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 8) {
                            if viewModel.winners.contains(.bottom) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(TablePalette.medalGold)
                                    .accessibilityHidden(true)
                            }
                            Text(gameOverTitle)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(TablePalette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .accessibilityAddTraits(.isHeader)
                        }
                        Text(gameOverSubtitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(viewModel.instantWin == nil ? TablePalette.faded : TablePalette.thokOrange)
                            .padding(.top, 2)

                        yourGameRows
                            .padding(.top, 10)

                        Spacer(minLength: 14)

                        VStack(spacing: 10) {
                            OverlayButton("Play again") { viewModel.startNewGame() }
                            secondaryButton("Menu") { onQuit() }
                        }
                    }
                    .frame(width: 220)
                    .frame(maxHeight: .infinity, alignment: .top)

                    Rectangle()
                        .fill(TablePalette.cardRuled.opacity(0.5))
                        .frame(width: 1)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Final standings")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .textCase(.uppercase)
                            .kerning(1)
                            .foregroundStyle(TablePalette.faded)
                            .padding(.leading, 8)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(viewModel.finalStandings, id: \.seat) { place in
                            finalStandingRow(place.seat, rank: place.rank, tied: place.tied, compact: viewModel.showingProCard)
                        }
                        if viewModel.showingProCard {
                            proCard
                                .padding(.top, 4)
                                .transition(.opacity)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.winners.contains(.bottom), !viewModel.reduceMotion, !systemReduceMotion {
                ConfettiView()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private var gameOverSubtitle: String {
        if let thok = viewModel.instantWin {
            return thok.seat == .bottom
                ? "Thok! You called \(thok.bid) and made it"
                : "Thok! \(viewModel.seatName(thok.seat)) called \(thok.bid) and made it"
        }
        let rounds = viewModel.gameState.roundStates.count
        return "Final after \(rounds) \(rounds == 1 ? "round" : "rounds") · \(viewModel.activeDifficulty.title)"
    }

    /// Calls made, best round and win streak: your game in three numbers.
    private var yourGameRows: some View {
        VStack(spacing: 0) {
            if let game = viewModel.yourGame {
                yourGameRow("Calls made", value: Text("\(game.callsMade) of \(game.rounds)"))
                pauseRowDivider
                yourGameRow("Best round", value: Text(game.bestRound >= 0 ? "+\(viewModel.scoreString(game.bestRound))" : viewModel.scoreString(game.bestRound)))
            }
            if let streak = viewModel.gameOverStreak {
                pauseRowDivider
                yourGameRow("Win streak", value: streakText(streak))
            }
        }
    }

    private func streakText(_ streak: GameViewModel.WinStreak) -> Text {
        if streak.isNewBest {
            return Text("\(streak.current) · new best").foregroundColor(TablePalette.accentGreen)
        }
        if streak.current == 0, streak.best > 0 {
            return Text("0 · best \(streak.best)")
        }
        return Text("\(streak.current)")
    }

    private func yourGameRow(_ title: String, value: Text) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(TablePalette.ink.opacity(0.8))
            Spacer()
            value
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(TablePalette.ink)
        }
        .frame(height: 32)
        .accessibilityElement(children: .combine)
    }

    /// The once-ever Pro card, under the final standings; there is no spare height under the buttons on the SE.
    private var proCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Enjoying Call Break+?")
                .font(TableType.headline)
                .foregroundStyle(TablePalette.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Pro adds tables, Insights and rule variants. One-time, no ads, ever.")
                .font(TableType.caption)
                .foregroundStyle(TablePalette.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                secondaryButton("Not now") { viewModel.dismissProCard() }
                OverlayButton("See Pro") {
                    viewModel.dismissProCard()
                    setShowingProPanel(true)
                }
            }
            .padding(.top, 4)
        }
        .padding(10)
        .background(TablePalette.gold.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(TablePalette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(TablePalette.ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(TablePalette.cardRuled, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func finalStandingRow(_ seat: Seat, rank: Int, tied: Bool, compact: Bool) -> some View {
        let total = viewModel.scores[seat] ?? 0
        let isYou = seat == .bottom
        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(rank <= 3 ? .white : TablePalette.faded)
                .frame(width: 30, height: 30)
                .background(medalColor(rank), in: Circle())
                .accessibilityHidden(true)
            Text(viewModel.seatName(seat))
                .font(.system(size: 17, weight: isYou ? .black : .bold, design: .rounded))
                .foregroundStyle(TablePalette.ink)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(viewModel.scoreString(total))
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundStyle(total < 0 ? TablePalette.destructiveRed : TablePalette.ink)
        }
        .padding(.horizontal, 8)
        .frame(height: compact ? 34 : 46)
        .background(isYou ? TablePalette.gold.opacity(0.3) : .clear, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tied ? "Tied " : "")\(GameViewModel.rankLabel(rank: rank, tied: false)), \(viewModel.seatName(seat)), \(viewModel.scoreString(total)) points")
    }

    private func medalColor(_ rank: Int) -> Color {
        switch rank {
        case 1: TablePalette.medalGold
        case 2: TablePalette.medalSilver
        case 3: TablePalette.medalBronze
        default: TablePalette.ink.opacity(0.12)
        }
    }

    private var gameOverTitle: String {
        let winners = viewModel.winners
        if winners.count == 1, let winner = winners.first {
            return winner == .bottom ? "You win!" : "\(viewModel.seatName(winner)) wins!"
        }
        let names = winners.map(viewModel.seatName)
        if names.count == 2 { return "\(names[0]) & \(names[1]) tie!" }
        return "\(names.dropLast().joined(separator: ", ")) & \(names.last ?? "") tie!"
    }

    private var quitConfirmationOverlay: some View {
        ZStack {
            overlayScrim
                .onTapGesture { cancelQuit() }

            TableOverlayCard(width: 260) {
                VStack(spacing: 16) {
                    OverlayHeader(icon: "flag.fill", title: "Quit Game?")

                Text("Your progress will be lost.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(TablePalette.ink.opacity(0.6))

                HStack(spacing: 12) {
                    styledButton("Cancel", color: TablePalette.woodButton) { cancelQuit() }
                    styledButton("Quit", color: TablePalette.destructiveRed) {
                        onQuit()
                    }
                }
                }
            }
        }
    }

    /// Back to Pause, still paused: only Resume resumes.
    private func cancelQuit() {
        withAnimation(.spring(duration: 0.25)) {
            showingQuitConfirmation = false
            showingPauseMenu = true
        }
    }

    private func styledButton(_ label: String, color: Color, action: @escaping () -> Void) -> some View {
        OverlayButton(label, color: color, action: action)
    }
}
