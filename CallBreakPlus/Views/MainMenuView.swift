import SwiftUI

struct MainMenuView: View {
    let onNewGame: () -> Void
    let onSettings: () -> Void
    let onStats: () -> Void

    @State private var showingHowToPlay = false
    @State private var suitPulse = false
    @State private var howToPlayLabelIndex = 0
    @State private var labelShuffleTimer: Timer?
    @AppStorage("onboarding.hasSeenRules") private var hasSeenRules = false

    private let howToPlayLabels = ["How to Play", "खेल्ने तरिका", "कैसे खेलें"]

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [
                    Color(red: 0.08, green: 0.32, blue: 0.10),
                    Color(red: 0.04, green: 0.18, blue: 0.05),
                    Color(red: 0.02, green: 0.10, blue: 0.03),
                ],
                center: .center,
                startRadius: 40,
                endRadius: 500
            )
            .ignoresSafeArea()

            HStack(spacing: 0) {
                VStack(spacing: 16) {
                    titleSection

                    VStack(spacing: 10) {
                        menuButton("New Game", icon: "play.fill", color: Color(red: 0.10, green: 0.56, blue: 0.20)) {
                            onNewGame()
                        }

                        menuButton("Settings", icon: "gearshape.fill", color: Color(red: 0.50, green: 0.30, blue: 0.12)) {
                            onSettings()
                        }

                        HStack(spacing: 10) {
                            smallButton("Stats", icon: "trophy.fill") { onStats() }
                            howToPlayButton
                        }

                    }
                }
                .frame(maxWidth: .infinity)

                if showingHowToPlay {
                    HowToPlayCard(
                        initialLanguage: howToPlayLabelIndex,
                        onDismiss: {
                            withAnimation(.spring(duration: 0.3)) {
                                showingHowToPlay = false
                            }
                        }
                    )
                    .frame(maxWidth: 360)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            if !hasSeenRules {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    showingHowToPlay = true
                }
                hasSeenRules = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                suitPulse = true
            }
            startLabelShuffle()
        }
        .onDisappear {
            labelShuffleTimer?.invalidate()
            labelShuffleTimer = nil
        }
    }

    private var titleSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("Call")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("Break")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(Color(red: 0.92, green: 0.72, blue: 0.10))
                Text("+")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
            }

            HStack(spacing: 12) {
                ForEach(Array(zip([Suit.spades, .hearts, .diamonds, .clubs],
                                  [Color.white, .red, .red, .white])), id: \.0) { suit, color in
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.08))
                            .frame(width: 36, height: 36)
                        Text(suit.symbol)
                            .font(.system(size: 22))
                            .foregroundColor(color.opacity(suitPulse ? 0.7 : 0.4))
                    }
                }
            }
        }
    }

    private var howToPlayButton: some View {
        Button {
            withAnimation(.spring(duration: 0.3)) {
                showingHowToPlay = true
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 11, weight: .bold))

                Text(howToPlayLabels[howToPlayLabelIndex])
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .id(howToPlayLabelIndex)
                    .transition(.opacity)
            }
            .frame(width: 138, height: 36)
            .background(.white.opacity(0.12))
            .foregroundColor(.white.opacity(0.8))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
        .animation(.easeInOut(duration: 0.6), value: howToPlayLabelIndex)
    }

    private func startLabelShuffle() {
        labelShuffleTimer?.invalidate()
        labelShuffleTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            Task { @MainActor in
                withAnimation {
                    howToPlayLabelIndex = (howToPlayLabelIndex + 1) % howToPlayLabels.count
                }
            }
        }
    }

    private func menuButton(_ title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .frame(width: 180, height: 46)
            .background(
                LinearGradient(colors: [color, color.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            )
            .foregroundColor(.white)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
            .shadow(color: color.opacity(0.3), radius: 4, y: 2)
        }
    }

    private func smallButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .frame(width: 118, height: 36)
            .background(.white.opacity(0.12))
            .foregroundColor(.white.opacity(0.8))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.15), lineWidth: 1))
        }
    }
}

// MARK: - How to Play Card

struct HowToPlayCard: View {
    let initialLanguage: Int
    let onDismiss: () -> Void

    @State private var selectedLanguage: Int = 0

    private let paper = Color(red: 0.99, green: 0.93, blue: 0.76)
    private let ink = Color(red: 0.25, green: 0.10, blue: 0.04)
    private let faded = Color(red: 0.55, green: 0.35, blue: 0.18)

    private let languages = ["English", "नेपाली", "हिंदी"]

    private let rules: [[RuleItem]] = [
        [
            RuleItem(emoji: "🃏", text: "4 players, 13 cards each. Spades are the most powerful cards."),
            RuleItem(emoji: "🎯", text: "Guess how many hands (1–13) you will win. You must choose at least 1."),
            RuleItem(emoji: "🃏", text: "Follow the starting suit. If you have a higher card of that suit, you must play it."),
            RuleItem(emoji: "♠️", text: "Out of the starting suit? You must play a Spade if you have one."),
            RuleItem(emoji: "🏆", text: "The highest Spade wins. If no Spades are played, the highest card of the starting suit wins."),
            RuleItem(emoji: "📊", text: "Meet your target to earn those points. Extra wins add 0.1 each. Miss your target and you lose those points."),
            RuleItem(emoji: "5️⃣", text: "5 rounds per game. Highest total score wins!"),
        ],
        [
            RuleItem(emoji: "🃏", text: "४ खेलाडी, सबैलाई १३-१३ पत्ती। हुकुम (Spades) सबैभन्दा शक्तिशाली हुन्छ।"),
            RuleItem(emoji: "🎯", text: "आफूले जित्ने हात (१-१३) अनुमान गर्नुहोस्। कम्तीमा १ कल गर्नुपर्छ।"),
            RuleItem(emoji: "🃏", text: "सुरुमा फालिएको रङकै पत्ती फाल्नुपर्छ। आफूसँग ठूलो पत्ती छ भने त्यही फाल्नुपर्छ।"),
            RuleItem(emoji: "♠️", text: "त्यो रङ छैन भने, हुकुम (Spades) छ भने काट्नैपर्छ।"),
            RuleItem(emoji: "🏆", text: "सबैभन्दा ठूलो हुकुमले जित्छ। हुकुम छैन भने सुरुको रङको सबैभन्दा ठूलो पत्तीले जित्छ।"),
            RuleItem(emoji: "📊", text: "अनुमान मिलाएमा कल गरे बराबरको पोइन्ट पाइन्छ। बढी जितेमा +०.१ थपिन्छ। नपुगेमा कल बराबरको घट्छ।"),
            RuleItem(emoji: "5️⃣", text: "एक गेममा ५ राउन्ड हुन्छन्। सबैभन्दा धेरै पोइन्ट हुनेले जित्छ!"),
        ],
        [
            RuleItem(emoji: "🃏", text: "4 खिलाड़ी, सबको 13-13 पत्ते। हुकुम (Spades) सबसे ताकतवर होते हैं।"),
            RuleItem(emoji: "🎯", text: "अनुमान लगाएं कि आप कितनी बार (1-13) जीतेंगे। कम से कम 1 कॉल ज़रूरी है।"),
            RuleItem(emoji: "🃏", text: "जो रंग चला है, उसी रंग का पत्ता चलें। बड़ा पत्ता है, तो वही चलना होगा।"),
            RuleItem(emoji: "♠️", text: "वह रंग नहीं है? आपको हुकुम (Spades) का पत्ता चलना होगा (अगर है)।"),
            RuleItem(emoji: "🏆", text: "सबसे बड़ा हुकुम जीतता है। हुकुम नहीं? चले गए रंग का सबसे बड़ा पत्ता जीतता है।"),
            RuleItem(emoji: "📊", text: "लक्ष्य पूरा करने पर उतने पॉइंट्स मिलते हैं। ज़्यादा जीतने पर +0.1 जुड़ता है। कम जीतने पर पॉइंट्स कटते हैं।"),
            RuleItem(emoji: "5️⃣", text: "हर गेम में 5 राउंड। सबसे ज़्यादा स्कोर वाला जीतेगा!"),
        ],
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("How to Play")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(ink)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(ink)
                    .frame(width: 22, height: 22)
                    .background(ink.opacity(0.1), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .padding(-9)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Picker("", selection: $selectedLanguage) {
                ForEach(0..<languages.count, id: \.self) { i in
                    Text(languages[i]).tag(i)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(rules[selectedLanguage]) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text(item.emoji)
                                .font(.system(size: 13))
                                .frame(width: 20)
                            Text(item.text)
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundColor(ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .id(selectedLanguage)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .background(paper)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color(red: 0.45, green: 0.20, blue: 0.08).opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
        .onAppear { selectedLanguage = initialLanguage }
    }
}

private struct RuleItem: Identifiable {
    let id = UUID()
    let emoji: String
    let text: String
}
