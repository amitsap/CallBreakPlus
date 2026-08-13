import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: GameViewModel
    @State private var showingResetConfirmation = false
    @State private var ruleExplanation: RuleExplanation?
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    private let paper = Color(red: 0.99, green: 0.93, blue: 0.76)
    private let ink = Color(red: 0.25, green: 0.10, blue: 0.04)
    private let faded = Color(red: 0.55, green: 0.35, blue: 0.18)
    private let ruled = Color(red: 0.82, green: 0.62, blue: 0.36).opacity(0.35)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.76, green: 0.43, blue: 0.16),
                    Color(red: 0.42, green: 0.20, blue: 0.08),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            HStack(spacing: 14) {
                notepadCard {
                    VStack(spacing: 0) {
                        sectionLabel("Game", icon: "suit.spade.fill")

                        settingRow {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Difficulty")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(ink)
                                Text("Applies from the next game")
                                    .font(.system(size: 9, weight: .medium, design: .rounded))
                                    .foregroundColor(faded)
                            }
                            Spacer()
                            Picker("", selection: $viewModel.botDifficulty) {
                                Text("Easy").tag(BotDifficulty.beginner)
                                Text("Medium").tag(BotDifficulty.intermediate)
                                Text("Hard").tag(BotDifficulty.advanced)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 200)
                        }

                        divider

                        settingRow {
                            Text("Card Back")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(ink)
                            Spacer()
                            Picker("", selection: $viewModel.cardBackStyle) {
                                Text("Blue").tag(0)
                                Text("Red").tag(1)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 110)
                        }

                        divider

                        settingRow {
                            Text("Name")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(ink)
                            Spacer()
                            TextField("You", text: $viewModel.playerName)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(ink)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }

                        divider

                        settingRow {
                            Toggle(isOn: $viewModel.canDiscardWhenCantOvertrump) {
                                VStack(alignment: .leading, spacing: 1) {
                                    ruleTitle("Free Discard", explanation: .freeDiscard)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(ink)
                                    Text("Skip trump if can't beat")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundColor(faded)
                                }
                            }
                            .tint(Color(red: 0.10, green: 0.56, blue: 0.20))
                        }

                        divider

                        settingRow {
                            Toggle(isOn: $viewModel.redealOnWeakHand) {
                                VStack(alignment: .leading, spacing: 1) {
                                    ruleTitle("Fair Deal", explanation: .fairDeal)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(ink)
                                    Text("Re-deal if no spade or face card")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundColor(faded)
                                }
                            }
                            .tint(Color(red: 0.10, green: 0.56, blue: 0.20))
                        }

                        divider

                        settingRow {
                            Toggle(isOn: $viewModel.instantWinEnabled) {
                                VStack(alignment: .leading, spacing: 1) {
                                    ruleTitle("Thok (Instant Win)", explanation: .thok)
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(ink)
                                    Text("Bid 8+ and make it to win game")
                                        .font(.system(size: 9, weight: .medium, design: .rounded))
                                        .foregroundColor(faded)
                                }
                            }
                            .tint(Color(red: 0.10, green: 0.56, blue: 0.20))
                        }
                    }
                }

                notepadCard {
                    VStack(spacing: 0) {
                        sectionLabel("Experience", icon: "waveform")

                        settingRow {
                            Toggle(isOn: $viewModel.soundEnabled) {
                                Text("Sound")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(ink)
                            }
                            .tint(Color(red: 0.10, green: 0.56, blue: 0.20))
                        }

                        divider

                        settingRow {
                            Toggle(isOn: $viewModel.hapticsEnabled) {
                                Text("Haptics")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(ink)
                            }
                            .tint(Color(red: 0.10, green: 0.56, blue: 0.20))
                        }

                        divider

                        settingRow {
                            Toggle(isOn: $viewModel.showMoveHints) {
                                Text("Move Explanations")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(ink)
                            }
                            .tint(Color(red: 0.10, green: 0.56, blue: 0.20))
                        }

                        divider

                        settingRow {
                            Toggle(isOn: $viewModel.showBidSuggestion) {
                                Text("Bid Suggestion")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(ink)
                            }
                            .tint(Color(red: 0.10, green: 0.56, blue: 0.20))
                        }

                        divider

                        settingRow {
                            Toggle(isOn: $viewModel.reduceMotion) {
                                Text("Reduce Motion")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(ink)
                            }
                            .tint(Color(red: 0.10, green: 0.56, blue: 0.20))
                        }

                        divider

                        settingRow {
                            Toggle(isOn: $viewModel.highContrastCards) {
                                Text("High-Contrast Cards")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(ink)
                            }
                            .tint(Color(red: 0.10, green: 0.56, blue: 0.20))
                        }

                        divider

                        settingRow {
                            HStack(spacing: 0) {
                                supportAction("Feedback", icon: "envelope.fill") { openURL(feedbackURL) }

                                supportAction("Rate", icon: "star.fill") { openURL(Self.writeReviewURL) }
                            }
                            .frame(maxWidth: .infinity)
                        }

                        divider

                        Button {
                            showingResetConfirmation = true
                        } label: {
                            HStack {
                                Text("Reset Stats")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                Spacer()
                                Image(systemName: "trash")
                                    .font(.caption)
                            }
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(ink)
                    .frame(width: 26, height: 26)
                    .background(paper.opacity(0.9), in: Circle())
                    .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .padding(-9)
            }
            .padding(.top, 10)
            .padding(.trailing, 14)
        }
        .alert("Reset Statistics?", isPresented: $showingResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                Task {
                    do {
                        try await viewModel.statsRepository?.resetStats()
                    } catch {
                        viewModel.statsErrorMessage = "Statistics could not be reset. Please try again."
                    }
                }
            }
        } message: {
            Text("All game records will be permanently deleted.")
        }
        .alert(item: $ruleExplanation) { item in
            Alert(title: Text(item.title), message: Text(item.message), dismissButton: .default(Text("Got It")))
        }
        .alert("Statistics Error", isPresented: Binding(
            get: { viewModel.statsErrorMessage != nil },
            set: { if !$0 { viewModel.statsErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.statsErrorMessage = nil }
        } message: {
            Text(viewModel.statsErrorMessage ?? "")
        }
    }

    private func notepadCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(paper)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(red: 0.45, green: 0.20, blue: 0.08).opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    private func sectionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(faded)
            Text(title)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundColor(faded)
                .textCase(.uppercase)
                .tracking(1)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func settingRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack { content() }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    private var divider: some View {
        Rectangle().fill(ruled).frame(height: 1).padding(.leading, 12)
    }

    private func ruleTitle(_ title: String, explanation: RuleExplanation) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(ink)
            Button { ruleExplanation = explanation } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(faded)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Explain \(title)")
        }
    }

    private func supportAction(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundColor(ink)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var feedbackURL: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "callbreakplus@amitsapkota.me"
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Call Break+ Feedback"),
            URLQueryItem(
                name: "body",
                value: "\n\n—\nApp version: \(version) (\(build))\niOS: \(UIDevice.current.systemVersion)"
            ),
        ]
        return components.url ?? URL(string: "https://amitsapkota.me/callbreakplus/support/")!
    }

    private static let writeReviewURL = URL(
        string: "https://apps.apple.com/app/id617853649?action=write-review"
    )!
}

private enum RuleExplanation: String, Identifiable {
    case freeDiscard, fairDeal, thok
    var id: String { rawValue }
    var title: String {
        switch self { case .freeDiscard: "Free Discard"; case .fairDeal: "Fair Deal"; case .thok: "Thok" }
    }
    var message: String {
        switch self {
        case .freeDiscard: "When you cannot beat a Spade already in the trick, you may discard another suit instead of playing a lower Spade."
        case .fairDeal: "Hands with no Spade, or with no Jack, Queen, King, or Ace, are automatically dealt again."
        case .thok: "A player who bids 8 or more and meets that bid wins the game immediately."
        }
    }
}
