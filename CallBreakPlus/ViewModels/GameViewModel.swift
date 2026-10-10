import SwiftUI

@Observable
@MainActor
final class GameViewModel {
    var gameState: GameState
    var botDifficulty: BotDifficulty = .intermediate { didSet { savePreferences() } }
    var showingBidSelector = false
    var showingRoundSummary = false
    var showingGameOver = false
    /// The once-ever Pro card on the game-over screen; see `shouldShowProCard(gamesPlayed:)`.
    var showingProCard = false
    var isProcessingBotTurn = false
    var trickWinner: Seat?
    var hapticsEnabled = true { didSet { savePreferences() } }
    var soundEnabled = true { didSet { savePreferences() } }
    var playerName = "You" {
        didSet {
            if playerName.count > Self.maxPlayerNameLength {
                playerName = String(playerName.prefix(Self.maxPlayerNameLength))
            }
            savePreferences()
        }
    }
    static let maxPlayerNameLength = 12
    var cardBack: CardBack = .blue { didSet { savePreferences() } }
    var tableTheme: TableThemeChoice = .classic { didSet { savePreferences() } }
    var canDiscardWhenCantOvertrump = true { didSet { savePreferences() } }
    var redealOnWeakHand = true { didSet { savePreferences() } }
    var instantWinEnabled = true { didSet { savePreferences() } }
    /// Game length, a Pro rule variant; a game uses `effectiveRoundCount`.
    var roundCount = ProGate.freeRoundCount { didSet { savePreferences() } }
    static let roundCountChoices = [3, 5, 10]
    /// The smallest call that wins by Thok, a Pro rule variant; a game uses `effectiveThokThreshold`.
    var thokThreshold = ProGate.freeThokThreshold { didSet { savePreferences() } }
    static let thokThresholdChoices = Array(8...13)
    var reduceMotion = false { didSet { savePreferences() } }
    var highContrastCards = false { didSet { savePreferences() } }
    var showBidSuggestion = false { didSet { savePreferences() } }
    var fastPlayEnabled = false { didSet { savePreferences() } }
    var invalidMoveMessage: String?
    var statsErrorMessage: String?

    var isDealing = false
    var dealtCardCount = 0
    var dealingCardSeat: Seat?
    var dealingCardInFlight = false
    var trickCardsToCollect = false
    var collectToSeat: Seat?
    var displayedTrickPlays: [TrickPlay] = []
    var roundSummaryScores: [(seat: Seat, bid: Int, tricks: Int, score: Double)] = []
    var roundSummaryNumber: Int = 0
    var lastTrickPlays: [TrickPlay] = []
    var lastTrickWinner: Seat?
    var showingLastTrick = false
    var showingStandings = false
    /// Your win streak after the finished game; nil until it is recorded, or if it couldn't be.
    private(set) var gameOverStreak: WinStreak?
    private(set) var summaryAutoAdvanceDeadline: Date?

    var statsRepository: (any StatsRepository)?
    let statsUnavailable: Bool
    private(set) var activeDifficulty: BotDifficulty = .intermediate
    private var bots: [Seat: any BotStrategy] = [:]
    @ObservationIgnored private var gameFlowTask: Task<Void, Never>?
    @ObservationIgnored private var pendingTrickWinner: Seat?
    @ObservationIgnored private var skipDealRequested = false
    @ObservationIgnored private var roundSummaryContinuation: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var summaryAdvanceTask: Task<Void, Never>?
    @ObservationIgnored private var summaryRemainingInterval: TimeInterval?
    @ObservationIgnored private var isLoadingPreferences = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var isAssistiveTechRunning: () -> Bool = {
        UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
    }
    @ObservationIgnored var summaryAutoAdvanceInterval: TimeInterval = 6
    /// Pro entitlement, read through `ProGate`; set by `ContentView` from `ProStore`.
    @ObservationIgnored var hasPro: () -> Bool = { false }

    /// The back the table draws: the stored choice, or Blue if it needs Pro and Pro is gone.
    var effectiveCardBack: CardBack {
        ProGate.cardBack(selected: cardBack, hasPro: hasPro())
    }

    /// The game length the next game uses: the stored choice, or 5 without Pro.
    var effectiveRoundCount: Int { nextGameRules.roundCount }

    /// The Thok threshold the next game uses: the stored choice, or 8 without Pro.
    var effectiveThokThreshold: Int {
        ProGate.rules(base: .standard, roundCount: roundCount, thokThreshold: thokThreshold, hasPro: hasPro()).instantWinBid ?? ProGate.freeThokThreshold
    }

    private var nextGameRules: RuleSet {
        var base = RuleSet.standard
        base.canDiscardWhenCantOvertrump = canDiscardWhenCantOvertrump
        base.redealOnWeakHand = redealOnWeakHand
        return ProGate.rules(
            base: base,
            roundCount: roundCount,
            thokThreshold: instantWinEnabled ? thokThreshold : nil,
            hasPro: hasPro()
        )
    }

    /// The theme the table and menu draw: the stored choice, or Classic if it needs Pro and Pro is gone.
    var effectiveTableTheme: TableThemeChoice {
        ProGate.tableTheme(selected: tableTheme, hasPro: hasPro())
    }
    /// Set when a Pro card is shown; a rating request never follows one in the same session.
    @ObservationIgnored var proCardShownThisSession = false
    /// Set when a rating request is due; a Pro card never follows one in the same session.
    @ObservationIgnored private(set) var reviewRequestedThisSession = false
    /// Whether the game-over screen should ask for a rating; decided once per game over.
    @ObservationIgnored private(set) var reviewDueAtGameOver = false

    init(statsRepository: (any StatsRepository)? = nil, statsUnavailable: Bool = false, defaults: UserDefaults = .standard) {
        self.statsRepository = statsRepository
        self.statsUnavailable = statsUnavailable
        self.defaults = defaults
        gameState = GameState()
        loadPreferences()
        setupBots()
    }

    var currentRound: RoundState? { gameState.currentRound }
    var phase: GamePhase { gameState.phase }
    var scores: [Seat: Double] { gameState.scoreTenths.mapValues(Scoring.score(fromTenths:)) }
    var roundNumber: Int { gameState.currentRoundNumber }
    var isGameOver: Bool { gameState.isGameOver }

    var visibleHumanHand: [Card] {
        if isDealing {
            let fullHand = currentRound?.hands[.bottom] ?? []
            let cardsDealtToHuman = handCountForSeat(.bottom)
            return Array(fullHand.prefix(cardsDealtToHuman))
        }
        return currentRound?.hands[.bottom] ?? []
    }

    var legalCards: [Card] {
        guard case .playing(_, .bottom) = phase, !isProcessingBotTurn else { return [] }
        return LegalMoves.legalCards(
            for: currentRound?.hands[.bottom] ?? [],
            in: currentRound?.currentTrick, rules: gameState.rules
        )
    }

    var isHumanTurn: Bool {
        if isProcessingBotTurn || isDealing { return false }
        if case .playing(_, .bottom) = phase { return true }
        if case .bidding(.bottom) = phase { return true }
        return false
    }

    var currentTrickPlays: [TrickPlay] {
        if !displayedTrickPlays.isEmpty {
            return displayedTrickPlays
        }
        return currentRound?.currentTrick?.plays ?? []
    }

    /// The seat that led the trick on the table.
    var trickLeader: Seat? { currentTrickPlays.first?.seat }

    /// The seat whose card is winning the trick on the table, updated as each
    /// card lands. A partial trick always holds its lead card, so
    /// `TrickResolver` reads it as it reads a complete one.
    var winningTrickSeat: Seat? {
        if let trickWinner { return trickWinner }
        let plays = currentTrickPlays
        guard let lead = plays.first else { return nil }
        return TrickResolver.winner(of: Trick(ledSuit: lead.card.suit, plays: plays))
    }

    var currentTrickNumber: Int {
        min((currentRound?.completedTricks.count ?? 0) + 1, 13)
    }

    var recommendedBid: Int {
        guard let hand = currentRound?.hands[.bottom] else { return 1 }
        return BotFactory.make(difficulty: .intermediate).chooseBid(
            hand: hand, seat: .bottom, existingBids: currentRound?.bids ?? [:]
        )
    }

    /// The other seats' calls so far this round.
    var calledSoFar: Int {
        (currentRound?.bids ?? [:]).filter { $0.key != .bottom }.values.reduce(0, +)
    }

    /// What a call wins or costs: "Make 4 or more: +4 · Miss: −4", or the
    /// Thok win for a call at or above `thokThreshold`.
    nonisolated static func callStakes(bid: Int, thokThreshold: Int?) -> String {
        if let thokThreshold, bid >= thokThreshold {
            return "Make \(bid) or more: Thok, you win · Miss: −\(bid)"
        }
        return "Make \(bid) or more: +\(bid) · Miss: −\(bid)"
    }

    func explainWhyCardIsUnavailable(_ card: Card) {
        guard case .playing(_, .bottom) = phase, !isProcessingBotTurn,
              !legalCards.contains(card) else { return }
        guard let message = Self.unavailableCardMessage(
            hand: currentRound?.hands[.bottom] ?? [],
            trick: currentRound?.currentTrick,
            rules: gameState.rules
        ) else { return }
        withAnimation(.spring(duration: 0.25)) { invalidMoveMessage = message }
        triggerHaptic(.light)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard self?.invalidMoveMessage == message else { return }
            withAnimation(.easeOut(duration: 0.2)) { self?.invalidMoveMessage = nil }
        }
    }

    /// Explains the rule behind `LegalMoves.restriction`, naming the card to
    /// beat. Nil when nothing restricts the hand.
    nonisolated static func unavailableCardMessage(hand: [Card], trick: Trick?, rules: RuleSet) -> String? {
        func singular(_ suit: Suit) -> String { String(suit.name.dropLast()).lowercased() }

        switch LegalMoves.restriction(for: hand, in: trick, rules: rules) {
        case .none:
            return nil
        case .followSuit(let suit):
            if trick?.highestSpade != nil {
                return "Follow \(suit.name). The trick is trumped, so any \(singular(suit)) is allowed."
            }
            if rules.mustGoHigher, let highest = trick?.highestOfLedSuit {
                return "Follow \(suit.name). None of yours beats the \(highest.description), so any \(singular(suit)) is allowed."
            }
            return "Follow \(suit.name)."
        case .beat(let target):
            let higher = hand.filter { $0.suit == target.suit && $0.rank > target.rank }
            if higher.count == 1 {
                return "Beat the \(target.description): play your \(higher[0].description)."
            }
            return "Beat the \(target.description) with a higher \(singular(target.suit))."
        case .trump:
            let led = trick?.ledSuit.name.lowercased() ?? "the led suit"
            return "You’re out of \(led), so you must play a Spade."
        case .overtrump(let target):
            let higher = hand.filter { $0.suit == .spades && $0.rank > target.rank }
            if higher.count == 1 {
                return "Beat the \(target.description): play your \(higher[0].description)."
            }
            return "Beat the \(target.description) with a higher Spade."
        }
    }

    func setupBots() {
        activeDifficulty = botDifficulty
        bots = [
            .right: BotFactory.make(difficulty: activeDifficulty),
            .top: BotFactory.make(difficulty: activeDifficulty),
            .left: BotFactory.make(difficulty: activeDifficulty),
        ]
    }

    func startNewGame() {
        gameFlowTask?.cancel()
        cancelSummaryCountdown()
        resumeRoundSummaryIfNeeded()
        gameState = GameState(rules: nextGameRules)
        showingBidSelector = false
        showingGameOver = false
        showingProCard = false
        reviewDueAtGameOver = false
        showingRoundSummary = false
        isProcessingBotTurn = false
        trickWinner = nil
        pendingTrickWinner = nil
        displayedTrickPlays = []
        trickCardsToCollect = false
        collectToSeat = nil
        roundSummaryScores = []
        showingStandings = false
        gameOverStreak = nil
        setupBots()
        gameFlowTask = Task { [weak self] in
            await self?.startRoundAnimated()
        }
    }

    func stopGame() {
        gameFlowTask?.cancel()
        gameFlowTask = nil
        cancelSummaryCountdown()
        resumeRoundSummaryIfNeeded()
        gameState = GameState()
        showingBidSelector = false
        showingRoundSummary = false
        showingGameOver = false
        showingProCard = false
        reviewDueAtGameOver = false
        isProcessingBotTurn = false
        trickWinner = nil
        pendingTrickWinner = nil
        displayedTrickPlays = []
        trickCardsToCollect = false
        collectToSeat = nil
        showingStandings = false
        gameOverStreak = nil
        isDealing = false
        dealtCardCount = 0
        dealingCardSeat = nil
        dealingCardInFlight = false
    }

    func pauseGame() {
        if case .gameOver = phase { return }
        if isDealing {
            isDealing = false
            dealtCardCount = 52
            dealingCardSeat = nil
            dealingCardInFlight = false
        }
        gameFlowTask?.cancel()
        gameFlowTask = nil
    }

    func resumeGame() {
        gameFlowTask?.cancel()
        gameFlowTask = Task { [weak self] in
            guard let self else { return }
            switch self.phase {
            case .bidding(.bottom):
                withAnimation(.spring(duration: 0.25)) { self.showingBidSelector = true }
            case .bidding:
                await self.processBotBidsAnimated()
            case .playing(_, .bottom):
                break
            case .playing:
                await self.processBotPlaysAnimated()
            case .trickComplete, .roundComplete:
                await self.handleAfterPlayAnimated(continueBotTurns: true)
            case .dealing:
                await self.startRoundAnimated()
            case .gameOver:
                break
            }
        }
    }

    func startRoundAnimated() async {
        guard !Task.isCancelled else { return }
        isDealing = true
        dealtCardCount = 0
        dealingCardSeat = nil
        dealingCardInFlight = false
        displayedTrickPlays = []
        pendingTrickWinner = nil
        trickWinner = nil
        trickCardsToCollect = false
        collectToSeat = nil
        lastTrickPlays = []
        lastTrickWinner = nil
        showingLastTrick = false

        var rng = SystemRandomNumberGenerator()
        gameState.startRound(using: &rng)

        skipDealRequested = false
        let firstDealSeat = currentRound?.dealer.next() ?? .bottom
        for i in 1...52 {
            if skipDealRequested {
                dealtCardCount = 52
                dealingCardSeat = nil
                dealingCardInFlight = false
                break
            }
            let seat = Seat(rawValue: (firstDealSeat.rawValue + i - 1) % Seat.allCases.count) ?? .bottom
            dealingCardSeat = seat
            dealingCardInFlight = false

            guard await delay(milliseconds: reduceMotion ? 3 : 6) else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.07)) {
                dealingCardInFlight = true
            }
            playSound(.cardDeal)

            guard await delay(milliseconds: reduceMotion ? 7 : 50) else { return }
            dealtCardCount = i
        }

        guard await delay(milliseconds: 200) else { return }

        withAnimation(.spring(duration: 0.3)) {
            isDealing = false
            dealingCardSeat = nil
            dealingCardInFlight = false
        }

        guard await delay(milliseconds: 300) else { return }
        await processBotBidsAnimated()
    }

    /// Finishes the deal at once; play continues to bidding. The deal loop
    /// checks the flag on each card, so the flow is never cancelled.
    func skipDeal() {
        guard isDealing else { return }
        skipDealRequested = true
    }

    func placeBid(_ bid: Int) {
        withAnimation(.spring(duration: 0.25)) {
            gameState.placeBid(seat: .bottom, bid: bid)
            showingBidSelector = false
        }
        triggerHaptic(.light)
        playSound(.bidPlace)
        gameFlowTask?.cancel()
        gameFlowTask = Task { [weak self] in
            guard let self else { return }
            if case .bidding = self.phase {
                await self.processBotBidsAnimated()
            } else if case .playing = self.phase {
                await self.startPlayingPhase()
            }
        }
    }

    func playCard(_ card: Card) {
        guard case .playing(_, .bottom) = phase else { return }
        let completedTrickCount = currentRound?.completedTricks.count ?? 0
        withAnimation(.spring(duration: 0.3)) {
            gameState.playCard(seat: .bottom, card: card)
            captureTrickDisplay(previousCompletedTrickCount: completedTrickCount)
        }
        triggerHaptic(.light)
        playSound(.cardPlay)
        gameFlowTask?.cancel()
        gameFlowTask = Task { [weak self] in
            await self?.handleAfterPlayAnimated(continueBotTurns: true)
        }
    }

    private func processBotBidsAnimated() async {
        while case .bidding(let nextBidder) = phase, nextBidder != .bottom {
            guard let bot = bots[nextBidder],
                  let hand = currentRound?.hands[nextBidder] else { break }

            guard await delay(milliseconds: 300) else { return }

            let bid = bot.chooseBid(
                hand: hand, seat: nextBidder, existingBids: currentRound?.bids ?? [:]
            )

            withAnimation(.spring(duration: 0.25)) {
                gameState.placeBid(seat: nextBidder, bid: bid)
            }
            playSound(.bidPlace)
        }

        if case .bidding(.bottom) = phase {
            withAnimation(.spring(duration: 0.3)) {
                showingBidSelector = true
            }
        }

        if case .playing = phase {
            await startPlayingPhase()
        }
    }

    private func startPlayingPhase() async {
        guard await delay(milliseconds: 150) else { return }
        await processBotPlaysAnimated()
    }

    private func processBotPlaysAnimated() async {
        if isProcessingBotTurn { return }
        isProcessingBotTurn = true
        defer { isProcessingBotTurn = false }

        while case .playing(_, let currentTurn) = phase, currentTurn != .bottom {
            guard let bot = bots[currentTurn],
                  let hand = currentRound?.hands[currentTurn],
                  let round = currentRound else { break }

            guard await delay(milliseconds: 380) else { return }

            let card = bot.chooseCard(
                hand: hand, trick: round.currentTrick, seat: currentTurn,
                round: round, rules: gameState.rules
            )

            let completedTrickCount = currentRound?.completedTricks.count ?? 0
            withAnimation(.spring(duration: 0.3)) {
                gameState.playCard(seat: currentTurn, card: card)
                captureTrickDisplay(previousCompletedTrickCount: completedTrickCount)
            }
            playSound(.cardSlide)

            await handleAfterPlayAnimated(continueBotTurns: false)

            if case .playing(_, .bottom) = phase { break }
        }
    }

    private func handleAfterPlayAnimated(continueBotTurns: Bool) async {
        if let winner = pendingTrickWinner {
            guard await delay(milliseconds: 120) else { return }

            withAnimation(.spring(duration: 0.2)) {
                trickWinner = winner
            }
            triggerHaptic(.medium)
            playSound(.trickWin)

            guard await delay(milliseconds: 420) else { return }

            lastTrickPlays = displayedTrickPlays
            lastTrickWinner = winner
            showingLastTrick = false

            withAnimation(.easeIn(duration: 0.35)) {
                trickCardsToCollect = true
                collectToSeat = winner
            }

            guard await delay(milliseconds: 300) else { return }

            withAnimation(.easeOut(duration: 0.25)) {
                trickCardsToCollect = false
                collectToSeat = nil
                trickWinner = nil
                pendingTrickWinner = nil
                displayedTrickPlays = []
                if case .trickComplete = phase {
                    gameState.startNextTrick()
                }
            }

            guard await delay(milliseconds: 80) else { return }

            if continueBotTurns, case .playing(_, let nextTurn) = phase, nextTurn != .bottom {
                await processBotPlaysAnimated()
            }
        }

        if case .roundComplete = phase {
            await showRoundSummary()
        } else if continueBotTurns, case .playing(_, let nextTurn) = phase, nextTurn != .bottom {
            await processBotPlaysAnimated()
        }
    }

    private func showRoundSummary() async {
        guard let round = currentRound else { return }

        switch gameState.roundOutcome() {
        case .invalid:
            return
        case .gameOver, .instantWin:
            gameState.endRound()
            let stats = await recordGameStats()
            guard await delay(milliseconds: 400) else { return }
            // The rating request goes first: on a game that is due both, the card waits for a later session.
            reviewDueAtGameOver = shouldRequestReview(afterWin: winners.contains(.bottom))
            if let stats { showingProCard = shouldShowProCard(gamesPlayed: stats.gamesPlayed) }
            playSound(winners.contains(.bottom) ? .gameWin : .gameLose)
            withAnimation(.spring(duration: 0.5)) {
                showingGameOver = true
            }
            return
        case .nextRound:
            break
        }

        roundSummaryNumber = round.roundNumber
        roundSummaryScores = Seat.allCases.map { seat in
            let bid = round.bids[seat] ?? 0
            let tricks = round.tricksWon[seat] ?? 0
            let score = Scoring.roundScore(bid: bid, tricksWon: tricks)
            return (seat: seat, bid: bid, tricks: tricks, score: score)
        }

        playSound(.roundComplete)
        withAnimation(.spring(duration: 0.4)) {
            showingRoundSummary = true
        }
        beginSummaryCountdownIfNeeded()

        await waitForRoundSummaryAcknowledgement()
        guard !Task.isCancelled else { return }

        gameState.endRound()

        withAnimation(.spring(duration: 0.3)) {
            showingRoundSummary = false
        }

        guard await delay(milliseconds: 300) else { return }
        await startRoundAnimated()
    }

    func acknowledgeRoundSummary() {
        cancelSummaryCountdown()
        resumeRoundSummaryIfNeeded()
    }

    func suspendSummaryCountdown() {
        guard let deadline = summaryAutoAdvanceDeadline else { return }
        summaryRemainingInterval = max(0, deadline.timeIntervalSinceNow)
        summaryAdvanceTask?.cancel()
        summaryAdvanceTask = nil
        summaryAutoAdvanceDeadline = nil
    }

    func resumeSummaryCountdown() {
        guard let interval = summaryRemainingInterval, showingRoundSummary else { return }
        summaryRemainingInterval = nil
        scheduleSummaryCountdown(after: interval)
    }

    func openLastTrick() {
        guard !isDealing, !isGameOver, !lastTrickPlays.isEmpty else { return }
        showingLastTrick = true
        gameFlowTask?.cancel()
        gameFlowTask = nil
    }

    func closeLastTrick() {
        guard showingLastTrick else { return }
        showingLastTrick = false
        resumeGame()
    }

    /// Pauses play like Last Trick; only `closeStandings()` resumes it.
    func openStandings() {
        guard !isDealing, !isGameOver else { return }
        showingStandings = true
        gameFlowTask?.cancel()
        gameFlowTask = nil
    }

    func closeStandings() {
        guard showingStandings else { return }
        showingStandings = false
        resumeGame()
    }

    /// Running totals, counting a round as soon as its summary shows.
    var standingTotalsTenths: [Seat: Int] {
        var totals = gameState.scoreTenths
        if showingRoundSummary {
            for item in roundSummaryScores {
                totals[item.seat, default: 0] += Scoring.roundScoreTenths(bid: item.bid, tricksWon: item.tricks)
            }
        }
        return totals
    }

    /// Seats by running total, highest first; ties keep seat order.
    var standingsOrder: [Seat] {
        let totals = standingTotalsTenths
        return Seat.allCases.sorted {
            let lhs = totals[$0] ?? 0
            let rhs = totals[$1] ?? 0
            return lhs == rhs ? $0.rawValue < $1.rawValue : lhs > rhs
        }
    }

    func standingRank(_ seat: Seat) -> (rank: Int, tied: Bool) {
        Self.rank(of: seat, in: standingTotalsTenths)
    }

    /// Competition ranking: tied seats share a rank, and the next rank skips.
    nonisolated static func rank(of seat: Seat, in totals: [Seat: Int]) -> (rank: Int, tied: Bool) {
        let mine = totals[seat] ?? 0
        let ahead = Seat.allCases.filter { (totals[$0] ?? 0) > mine }.count
        let level = Seat.allCases.filter { (totals[$0] ?? 0) == mine }.count
        return (ahead + 1, level > 1)
    }

    /// Places gained (positive) or lost over the summarised round. Nil after
    /// round 1, when there were no standings to move from.
    func summaryRankChange(_ seat: Seat) -> Int? {
        guard showingRoundSummary, roundSummaryNumber > 1 else { return nil }
        let before = Self.rank(of: seat, in: gameState.scoreTenths).rank
        return before - standingRank(seat).rank
    }

    /// "1st", or "=2nd" when tied.
    nonisolated static func rankLabel(rank: Int, tied: Bool) -> String {
        let suffix = switch rank {
        case 1: "st"
        case 2: "nd"
        case 3: "rd"
        default: "th"
        }
        return "\(tied ? "=" : "")\(rank)\(suffix)"
    }

    /// A seat's score for one round, once that round is scored or its summary shows.
    func roundScoreTenths(roundNumber: Int, seat: Seat) -> Int? {
        if let round = gameState.roundStates.first(where: { $0.roundNumber == roundNumber }),
           let bid = round.bids[seat], let tricks = round.tricksWon[seat] {
            return Scoring.roundScoreTenths(bid: bid, tricksWon: tricks)
        }
        if showingRoundSummary, roundNumber == roundSummaryNumber,
           let item = roundSummaryScores.first(where: { $0.seat == seat }) {
            return Scoring.roundScoreTenths(bid: item.bid, tricksWon: item.tricks)
        }
        return nil
    }

    func bidForSeat(_ seat: Seat) -> Int? {
        currentRound?.bids[seat]
    }

    func tricksForSeat(_ seat: Seat) -> Int {
        currentRound?.tricksWon[seat] ?? 0
    }

    func handCountForSeat(_ seat: Seat) -> Int {
        if isDealing {
            let firstDealSeat = currentRound?.dealer.next() ?? .bottom
            let seatOffset = (seat.rawValue - firstDealSeat.rawValue + Seat.allCases.count) % Seat.allCases.count
            guard dealtCardCount > seatOffset else { return 0 }
            return min(13, ((dealtCardCount - 1 - seatOffset) / 4) + 1)
        }
        return currentRound?.hands[seat]?.count ?? 0
    }

    var winners: [Seat] {
        guard isGameOver else { return [] }
        if let instant = gameState.instantWinner { return [instant] }
        guard let highest = gameState.scoreTenths.values.max() else { return [] }
        return Seat.allCases.filter { gameState.scoreTenths[$0] == highest }
    }

    func winner() -> Seat? {
        winners.count == 1 ? winners.first : nil
    }

    static let reviewWinMilestones: Set<Int> = [3, 15]

    /// Counts a finished game toward the rating prompt; call once per game over.
    /// True on the 3rd and 15th wins, unless a Pro card was shown this session.
    func shouldRequestReview(afterWin won: Bool) -> Bool {
        guard won else { return false }
        let wins = defaults.integer(forKey: ReviewKey.wins) + 1
        defaults.set(wins, forKey: ReviewKey.wins)
        guard Self.reviewWinMilestones.contains(wins), !proCardShownThisSession else { return false }
        reviewRequestedThisSession = true
        return true
    }

    static let proCardGameThreshold = 10

    /// The one proactive Pro prompt: true once ever, at the first game over with at least
    /// 10 completed games, unless the player has Pro or a rating was requested this session.
    /// A true answer marks the card shown.
    func shouldShowProCard(gamesPlayed: Int) -> Bool {
        guard gamesPlayed >= Self.proCardGameThreshold, !hasPro(), !reviewRequestedThisSession,
              !defaults.bool(forKey: ProCardKey.shown)
        else { return false }
        defaults.set(true, forKey: ProCardKey.shown)
        proCardShownThisSession = true
        return true
    }

    func dismissProCard() {
        withAnimation(.spring(duration: 0.25)) { showingProCard = false }
    }

    var instantWin: (seat: Seat, bid: Int)? {
        guard let seat = gameState.instantWinner,
              let bid = gameState.roundStates.last?.bids[seat]
        else { return nil }
        return (seat: seat, bid: bid)
    }

    /// Your calls made of rounds played, and your best round score.
    var yourGame: (callsMade: Int, rounds: Int, bestRound: Double)? {
        let rounds = gameState.roundStates
        guard isGameOver, !rounds.isEmpty else { return nil }
        let results = rounds.map { (bid: $0.bids[.bottom] ?? 0, tricks: $0.tricksWon[.bottom] ?? 0) }
        let made = results.filter { $0.tricks >= $0.bid }.count
        let best = results.map { Scoring.roundScore(bid: $0.bid, tricksWon: $0.tricks) }.max() ?? 0
        return (made, rounds.count, best)
    }

    /// Final places: a Thok winner is first whatever the totals, and the rest
    /// rank by total with ties sharing a place.
    var finalStandings: [(seat: Seat, rank: Int, tied: Bool)] {
        Self.finalStandings(totals: gameState.scoreTenths, instantWinner: gameState.instantWinner)
    }

    nonisolated static func finalStandings(totals: [Seat: Int], instantWinner: Seat?) -> [(seat: Seat, rank: Int, tied: Bool)] {
        let rest = Seat.allCases.filter { $0 != instantWinner }
        let firstPlace = instantWinner == nil ? 1 : 2
        var places: [(seat: Seat, rank: Int, tied: Bool)] = instantWinner.map { [($0, 1, false)] } ?? []
        for seat in rest {
            let mine = totals[seat] ?? 0
            let ahead = rest.filter { (totals[$0] ?? 0) > mine }.count
            let level = rest.filter { (totals[$0] ?? 0) == mine }.count
            places.append((seat, firstPlace + ahead, level > 1))
        }
        return places.sorted { lhs, rhs in
            lhs.rank == rhs.rank ? lhs.seat.rawValue < rhs.seat.rawValue : lhs.rank < rhs.rank
        }
    }

    struct WinStreak: Equatable {
        let current: Int
        let best: Int
        let isNewBest: Bool
    }

    /// A new best is a streak past an earlier best, so a first win isn't one.
    nonisolated static func winStreak(before: PlayerStats?, after: PlayerStats, won: Bool) -> WinStreak {
        let previousBest = before?.longestWinStreak ?? 0
        return WinStreak(
            current: after.currentWinStreak,
            best: after.longestWinStreak,
            isNewBest: won && previousBest > 0 && after.currentWinStreak > previousBest
        )
    }

    func scoreString(_ score: Double) -> String {
        if score == score.rounded() {
            return String(format: "%.0f", score)
        }
        return String(format: "%.1f", score)
    }

    func seatName(_ seat: Seat) -> String {
        if seat == .bottom {
            let name = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? "You" : name
        }
        return seat.name
    }

    /// Records the finished game and returns the stats after it, or nil if they couldn't be read.
    private func recordGameStats() async -> PlayerStats? {
        guard let repo = statsRepository else { return nil }
        let humanScore = scores[.bottom] ?? 0
        let won = winners.contains(.bottom)

        var roundScores: [Double] = []
        var bids: [Int] = []
        var tricksWon: [Int] = []

        for round in gameState.roundStates {
            let bid = round.bids[.bottom] ?? 0
            let tricks = round.tricksWon[.bottom] ?? 0
            bids.append(bid)
            tricksWon.append(tricks)
            roundScores.append(Scoring.roundScore(bid: bid, tricksWon: tricks))
        }

        let result = GameResult(
            won: won,
            difficulty: activeDifficulty,
            totalScore: humanScore,
            roundScores: roundScores,
            bids: bids,
            tricksWon: tricksWon,
            date: Date(),
            roundCount: gameState.rules.roundCount
        )

        let before = try? await repo.fetchStats()
        do {
            try await repo.recordGameResult(result)
        } catch {
            statsErrorMessage = "Your game finished, but its statistics could not be saved."
            return nil
        }
        guard let after = try? await repo.fetchStats() else { return nil }
        gameOverStreak = Self.winStreak(before: before, after: after, won: won)
        return after
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func playSound(_ effect: SoundManager.SoundEffect) {
        guard soundEnabled else { return }
        SoundManager.shared.isEnabled = soundEnabled
        SoundManager.shared.play(effect)
    }

    private func captureTrickDisplay(previousCompletedTrickCount: Int) {
        if let currentTrick = currentRound?.currentTrick {
            displayedTrickPlays = currentTrick.plays
            return
        }

        guard let round = currentRound,
              round.completedTricks.count > previousCompletedTrickCount,
              let completedTrick = round.completedTricks.last else { return }

        displayedTrickPlays = completedTrick.plays
        pendingTrickWinner = TrickResolver.winner(of: completedTrick)
    }

    private func delay(milliseconds: Int64) async -> Bool {
        do {
            let effectiveDelay = fastPlayEnabled ? max(1, milliseconds * 65 / 100) : milliseconds
            try await Task.sleep(for: .milliseconds(effectiveDelay))
            return !Task.isCancelled
        } catch {
            return false
        }
    }

    private func waitForRoundSummaryAcknowledgement() async {
        await withCheckedContinuation { continuation in
            roundSummaryContinuation = continuation
        }
    }

    private func beginSummaryCountdownIfNeeded() {
        guard defaults.bool(forKey: PreferenceKey.hasSeenRoundSummary), !isAssistiveTechRunning() else {
            defaults.set(true, forKey: PreferenceKey.hasSeenRoundSummary)
            return
        }
        scheduleSummaryCountdown(after: summaryAutoAdvanceInterval)
    }

    private func scheduleSummaryCountdown(after interval: TimeInterval) {
        guard showingRoundSummary else { return }
        let deadline = Date().addingTimeInterval(interval)
        summaryAutoAdvanceDeadline = deadline
        summaryAdvanceTask?.cancel()
        summaryAdvanceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(interval))
            } catch {
                return
            }
            guard !Task.isCancelled, self?.summaryAutoAdvanceDeadline == deadline else { return }
            self?.acknowledgeRoundSummary()
        }
    }

    private func cancelSummaryCountdown() {
        summaryAdvanceTask?.cancel()
        summaryAdvanceTask = nil
        summaryAutoAdvanceDeadline = nil
        summaryRemainingInterval = nil
    }

    private func resumeRoundSummaryIfNeeded() {
        roundSummaryContinuation?.resume()
        roundSummaryContinuation = nil
    }

    private enum PreferenceKey {
        static let difficulty = "settings.difficulty"
        static let haptics = "settings.haptics"
        static let sound = "settings.sound"
        static let playerName = "settings.playerName"
        static let cardBack = "settings.cardBack"
        static let tableTheme = "settings.tableTheme"
        static let freeDiscard = "settings.freeDiscard"
        static let fairDeal = "settings.fairDeal"
        static let instantWin = "settings.instantWin"
        static let roundCount = "settings.roundCount"
        static let thokThreshold = "settings.thokThreshold"
        static let reduceMotion = "settings.reduceMotion"
        static let highContrast = "settings.highContrastCards"
        static let bidSuggestion = "settings.bidSuggestion"
        static let fastPlay = "settings.fastPlay"
        static let hasSeenRoundSummary = "settings.hasSeenRoundSummary"
    }

    /// Kept outside `settings.*`, which `savePreferences` rewrites wholesale.
    private enum ReviewKey {
        static let wins = "review.wins"
    }

    /// Kept outside `settings.*`, which `savePreferences` rewrites wholesale.
    private enum ProCardKey {
        static let shown = "pro.cardShown"
    }

    private func loadPreferences() {
        isLoadingPreferences = true
        defer { isLoadingPreferences = false }
        if let raw = defaults.string(forKey: PreferenceKey.difficulty),
           let difficulty = BotDifficulty(rawValue: raw) { botDifficulty = difficulty }
        if defaults.object(forKey: PreferenceKey.haptics) != nil { hapticsEnabled = defaults.bool(forKey: PreferenceKey.haptics) }
        if defaults.object(forKey: PreferenceKey.sound) != nil { soundEnabled = defaults.bool(forKey: PreferenceKey.sound) }
        if let name = defaults.string(forKey: PreferenceKey.playerName), !name.isEmpty { playerName = name }
        if defaults.object(forKey: PreferenceKey.cardBack) != nil { cardBack = CardBack(stored: defaults.integer(forKey: PreferenceKey.cardBack)) }
        if defaults.object(forKey: PreferenceKey.tableTheme) != nil { tableTheme = TableThemeChoice(stored: defaults.integer(forKey: PreferenceKey.tableTheme)) }
        if defaults.object(forKey: PreferenceKey.freeDiscard) != nil { canDiscardWhenCantOvertrump = defaults.bool(forKey: PreferenceKey.freeDiscard) }
        if defaults.object(forKey: PreferenceKey.fairDeal) != nil { redealOnWeakHand = defaults.bool(forKey: PreferenceKey.fairDeal) }
        if defaults.object(forKey: PreferenceKey.instantWin) != nil { instantWinEnabled = defaults.bool(forKey: PreferenceKey.instantWin) }
        if Self.roundCountChoices.contains(defaults.integer(forKey: PreferenceKey.roundCount)) { roundCount = defaults.integer(forKey: PreferenceKey.roundCount) }
        if Self.thokThresholdChoices.contains(defaults.integer(forKey: PreferenceKey.thokThreshold)) { thokThreshold = defaults.integer(forKey: PreferenceKey.thokThreshold) }
        if defaults.object(forKey: PreferenceKey.reduceMotion) != nil { reduceMotion = defaults.bool(forKey: PreferenceKey.reduceMotion) }
        if defaults.object(forKey: PreferenceKey.highContrast) != nil { highContrastCards = defaults.bool(forKey: PreferenceKey.highContrast) }
        if defaults.object(forKey: PreferenceKey.bidSuggestion) != nil { showBidSuggestion = defaults.bool(forKey: PreferenceKey.bidSuggestion) }
        if defaults.object(forKey: PreferenceKey.fastPlay) != nil { fastPlayEnabled = defaults.bool(forKey: PreferenceKey.fastPlay) }
    }

    private func savePreferences() {
        guard !isLoadingPreferences else { return }
        defaults.set(botDifficulty.rawValue, forKey: PreferenceKey.difficulty)
        defaults.set(hapticsEnabled, forKey: PreferenceKey.haptics)
        defaults.set(soundEnabled, forKey: PreferenceKey.sound)
        defaults.set(playerName, forKey: PreferenceKey.playerName)
        defaults.set(cardBack.rawValue, forKey: PreferenceKey.cardBack)
        defaults.set(tableTheme.rawValue, forKey: PreferenceKey.tableTheme)
        defaults.set(canDiscardWhenCantOvertrump, forKey: PreferenceKey.freeDiscard)
        defaults.set(redealOnWeakHand, forKey: PreferenceKey.fairDeal)
        defaults.set(instantWinEnabled, forKey: PreferenceKey.instantWin)
        defaults.set(roundCount, forKey: PreferenceKey.roundCount)
        defaults.set(thokThreshold, forKey: PreferenceKey.thokThreshold)
        defaults.set(reduceMotion, forKey: PreferenceKey.reduceMotion)
        defaults.set(highContrastCards, forKey: PreferenceKey.highContrast)
        defaults.set(showBidSuggestion, forKey: PreferenceKey.bidSuggestion)
        defaults.set(fastPlayEnabled, forKey: PreferenceKey.fastPlay)
    }
}
