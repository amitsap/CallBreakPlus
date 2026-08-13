import SwiftUI

@Observable
@MainActor
final class GameViewModel {
    var gameState: GameState
    var botDifficulty: BotDifficulty = .intermediate { didSet { savePreferences() } }
    var showingBidSelector = false
    var showingRoundSummary = false
    var showingGameOver = false
    var isProcessingBotTurn = false
    var trickWinner: Seat?
    var hapticsEnabled = true { didSet { savePreferences() } }
    var soundEnabled = true { didSet { savePreferences() } }
    var playerName = "You" { didSet { savePreferences() } }
    var cardBackStyle = 0 { didSet { savePreferences() } }
    var canDiscardWhenCantOvertrump = true { didSet { savePreferences() } }
    var redealOnWeakHand = true { didSet { savePreferences() } }
    var instantWinEnabled = true { didSet { savePreferences() } }
    var reduceMotion = false { didSet { savePreferences() } }
    var highContrastCards = false { didSet { savePreferences() } }
    var showMoveHints = true { didSet { savePreferences() } }
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
    var showingSettings = false
    var lastTrickPlays: [TrickPlay] = []
    var lastTrickWinner: Seat?
    var showingLastTrick = false
    private(set) var summaryAutoAdvanceDeadline: Date?

    var statsRepository: (any StatsRepository)?
    let statsUnavailable: Bool
    private(set) var activeDifficulty: BotDifficulty = .intermediate
    private var bots: [Seat: any BotStrategy] = [:]
    @ObservationIgnored private var gameFlowTask: Task<Void, Never>?
    @ObservationIgnored private var pendingTrickWinner: Seat?
    @ObservationIgnored private var roundSummaryContinuation: CheckedContinuation<Void, Never>?
    @ObservationIgnored private var summaryAdvanceTask: Task<Void, Never>?
    @ObservationIgnored private var summaryRemainingInterval: TimeInterval?
    @ObservationIgnored private var isLoadingPreferences = false
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var isAssistiveTechRunning: () -> Bool = {
        UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
    }
    @ObservationIgnored var summaryAutoAdvanceInterval: TimeInterval = 6

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

    var currentTrickNumber: Int {
        min((currentRound?.completedTricks.count ?? 0) + 1, 13)
    }

    var recommendedBid: Int {
        guard let hand = currentRound?.hands[.bottom] else { return 1 }
        return BotFactory.make(difficulty: .intermediate).chooseBid(
            hand: hand, seat: .bottom, existingBids: currentRound?.bids ?? [:]
        )
    }

    func explainWhyCardIsUnavailable(_ card: Card) {
        guard showMoveHints, isHumanTurn, !legalCards.contains(card) else { return }
        let message: String
        if let leadSuit = currentRound?.currentTrick?.ledSuit,
           (currentRound?.hands[.bottom] ?? []).contains(where: { $0.suit == leadSuit }) {
            if currentRound?.currentTrick?.highestSpade != nil {
                message = "Follow \(leadSuit.name). The trick is trumped, so any \(leadSuit.name.lowercased()) card is legal."
            } else {
                message = "Follow \(leadSuit.name). Play a higher card if you can."
            }
        } else {
            message = "You must play a Spade when you cannot follow the lead suit."
        }
        withAnimation(.spring(duration: 0.25)) { invalidMoveMessage = message }
        triggerHaptic(.light)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard self?.invalidMoveMessage == message else { return }
            withAnimation(.easeOut(duration: 0.2)) { self?.invalidMoveMessage = nil }
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
        var rules = RuleSet.standard
        rules.canDiscardWhenCantOvertrump = canDiscardWhenCantOvertrump
        rules.redealOnWeakHand = redealOnWeakHand
        rules.instantWinBid = instantWinEnabled ? 8 : nil
        gameState = GameState(rules: rules)
        showingBidSelector = false
        showingGameOver = false
        showingRoundSummary = false
        showingSettings = false
        isProcessingBotTurn = false
        trickWinner = nil
        pendingTrickWinner = nil
        displayedTrickPlays = []
        trickCardsToCollect = false
        collectToSeat = nil
        roundSummaryScores = []
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
        isProcessingBotTurn = false
        trickWinner = nil
        pendingTrickWinner = nil
        displayedTrickPlays = []
        trickCardsToCollect = false
        collectToSeat = nil
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

        let firstDealSeat = currentRound?.dealer.next() ?? .bottom
        for i in 1...52 {
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
            await recordGameStats()
            guard await delay(milliseconds: 400) else { return }
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

    var instantWin: (seat: Seat, bid: Int)? {
        guard let seat = gameState.instantWinner,
              let bid = gameState.roundStates.last?.bids[seat]
        else { return nil }
        return (seat: seat, bid: bid)
    }

    func scoreString(_ score: Double) -> String {
        if score == score.rounded() {
            return String(format: "%.0f", score)
        }
        return String(format: "%.1f", score)
    }

    func seatName(_ seat: Seat) -> String {
        if seat == .bottom { return playerName }
        return seat.name
    }

    private func recordGameStats() async {
        guard let repo = statsRepository else { return }
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
            date: Date()
        )

        do {
            try await repo.recordGameResult(result)
        } catch {
            statsErrorMessage = "Your game finished, but its statistics could not be saved."
        }
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
        static let freeDiscard = "settings.freeDiscard"
        static let fairDeal = "settings.fairDeal"
        static let instantWin = "settings.instantWin"
        static let reduceMotion = "settings.reduceMotion"
        static let highContrast = "settings.highContrastCards"
        static let moveHints = "settings.moveHints"
        static let bidSuggestion = "settings.bidSuggestion"
        static let fastPlay = "settings.fastPlay"
        static let hasSeenRoundSummary = "settings.hasSeenRoundSummary"
    }

    private func loadPreferences() {
        isLoadingPreferences = true
        defer { isLoadingPreferences = false }
        if let raw = defaults.string(forKey: PreferenceKey.difficulty),
           let difficulty = BotDifficulty(rawValue: raw) { botDifficulty = difficulty }
        if defaults.object(forKey: PreferenceKey.haptics) != nil { hapticsEnabled = defaults.bool(forKey: PreferenceKey.haptics) }
        if defaults.object(forKey: PreferenceKey.sound) != nil { soundEnabled = defaults.bool(forKey: PreferenceKey.sound) }
        if let name = defaults.string(forKey: PreferenceKey.playerName), !name.isEmpty { playerName = name }
        if defaults.object(forKey: PreferenceKey.cardBack) != nil { cardBackStyle = defaults.integer(forKey: PreferenceKey.cardBack) }
        if defaults.object(forKey: PreferenceKey.freeDiscard) != nil { canDiscardWhenCantOvertrump = defaults.bool(forKey: PreferenceKey.freeDiscard) }
        if defaults.object(forKey: PreferenceKey.fairDeal) != nil { redealOnWeakHand = defaults.bool(forKey: PreferenceKey.fairDeal) }
        if defaults.object(forKey: PreferenceKey.instantWin) != nil { instantWinEnabled = defaults.bool(forKey: PreferenceKey.instantWin) }
        if defaults.object(forKey: PreferenceKey.reduceMotion) != nil { reduceMotion = defaults.bool(forKey: PreferenceKey.reduceMotion) }
        if defaults.object(forKey: PreferenceKey.highContrast) != nil { highContrastCards = defaults.bool(forKey: PreferenceKey.highContrast) }
        if defaults.object(forKey: PreferenceKey.moveHints) != nil { showMoveHints = defaults.bool(forKey: PreferenceKey.moveHints) }
        if defaults.object(forKey: PreferenceKey.bidSuggestion) != nil { showBidSuggestion = defaults.bool(forKey: PreferenceKey.bidSuggestion) }
        if defaults.object(forKey: PreferenceKey.fastPlay) != nil { fastPlayEnabled = defaults.bool(forKey: PreferenceKey.fastPlay) }
    }

    private func savePreferences() {
        guard !isLoadingPreferences else { return }
        defaults.set(botDifficulty.rawValue, forKey: PreferenceKey.difficulty)
        defaults.set(hapticsEnabled, forKey: PreferenceKey.haptics)
        defaults.set(soundEnabled, forKey: PreferenceKey.sound)
        defaults.set(playerName, forKey: PreferenceKey.playerName)
        defaults.set(cardBackStyle, forKey: PreferenceKey.cardBack)
        defaults.set(canDiscardWhenCantOvertrump, forKey: PreferenceKey.freeDiscard)
        defaults.set(redealOnWeakHand, forKey: PreferenceKey.fairDeal)
        defaults.set(instantWinEnabled, forKey: PreferenceKey.instantWin)
        defaults.set(reduceMotion, forKey: PreferenceKey.reduceMotion)
        defaults.set(highContrastCards, forKey: PreferenceKey.highContrast)
        defaults.set(showMoveHints, forKey: PreferenceKey.moveHints)
        defaults.set(showBidSuggestion, forKey: PreferenceKey.bidSuggestion)
        defaults.set(fastPlayEnabled, forKey: PreferenceKey.fastPlay)
    }
}
