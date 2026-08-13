import SwiftUI

struct StatisticsView: View {
    let statsRepository: (any StatsRepository)?
    let statsUnavailable: Bool
    @State private var stats = PlayerStats()
    @State private var recentGames: [GameSummary] = []
    @State private var loadError: String?
    @Environment(\.dismiss) private var dismiss

    private let paper = Color(red: 0.99, green: 0.93, blue: 0.76)
    private let ink = Color(red: 0.25, green: 0.10, blue: 0.04)
    private let faded = Color(red: 0.55, green: 0.35, blue: 0.18)
    private let ruled = Color(red: 0.82, green: 0.62, blue: 0.36).opacity(0.35)
    private let green = Color(red: 0.10, green: 0.56, blue: 0.20)

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
                        sectionLabel("Overview", icon: "chart.pie.fill")
                        ruledRow("Played", value: "\(stats.gamesPlayed)")
                        ruledRow("Won", value: "\(stats.gamesWon)")
                        ruledRow("Win Rate", value: pct(stats.winRate), valueColor: green)
                        ruledRow("Best Round", value: String(format: "%.1f", stats.bestRoundScore))
                        ruledRow("Bid Accuracy", value: pct(stats.bidAccuracy), valueColor: green)
                        ruledRow("Average Score", value: String(format: "%.1f", stats.averageScore), last: true)
                    }
                }

                VStack(spacing: 10) {
                    notepadCard {
                        VStack(spacing: 0) {
                            sectionLabel("Streaks", icon: "flame.fill")
                            ruledRow("Current", value: "\(stats.currentWinStreak)", valueColor: stats.currentWinStreak > 0 ? green : ink)
                            ruledRow("Longest", value: "\(stats.longestWinStreak)", last: true)
                        }
                    }

                    notepadCard {
                        VStack(spacing: 0) {
                            sectionLabel("By Difficulty", icon: "slider.horizontal.3")
                            diffRow("Easy", games: stats.beginnerGames, wins: stats.beginnerWins)
                            diffRow("Medium", games: stats.intermediateGames, wins: stats.intermediateWins)
                            diffRow("Hard", games: stats.advancedGames, wins: stats.advancedWins, last: true)
                        }
                    }

                    if !recentGames.isEmpty {
                        notepadCard {
                            VStack(spacing: 0) {
                                sectionLabel("Recent Games", icon: "clock.arrow.circlepath")
                                ForEach(Array(recentGames.enumerated()), id: \.element.id) { index, game in
                                    recentGameRow(game, last: index == recentGames.count - 1)
                                }
                            }
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
        .overlay(alignment: .bottom) {
            if statsUnavailable {
                notepadCard {
                    Text("Stats can't be saved on this device right now. This session's numbers are temporary.")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(faded)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .padding(.bottom, 10)
            }
        }
        .task {
            if let repo = statsRepository {
                do {
                    stats = try await repo.fetchStats()
                    recentGames = try await repo.fetchRecentGames(limit: 3)
                } catch {
                    loadError = "Statistics could not be loaded. Please try again."
                }
            }
        }
        .alert("Statistics Unavailable", isPresented: Binding(
            get: { loadError != nil },
            set: { if !$0 { loadError = nil } }
        )) {
            Button("OK", role: .cancel) { loadError = nil }
        } message: {
            Text(loadError ?? "")
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

    private func ruledRow(_ label: String, value: String, valueColor: Color? = nil, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(ink)
                Spacer()
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(valueColor ?? ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if !last {
                Rectangle().fill(ruled).frame(height: 1).padding(.leading, 12)
            }
        }
    }

    private func diffRow(_ label: String, games: Int, wins: Int, last: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(ink)
                Spacer()
                HStack(spacing: 2) {
                    Text("\(wins)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(green)
                    Text("/")
                        .font(.system(size: 10))
                        .foregroundColor(faded)
                    Text("\(games)")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(ink)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            if !last {
                Rectangle().fill(ruled).frame(height: 1).padding(.leading, 12)
            }
        }
    }

    private func pct(_ v: Double) -> String {
        String(format: "%.0f%%", v * 100)
    }

    private func recentGameRow(_ game: GameSummary, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: game.won ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(game.won ? green : .red)
                VStack(alignment: .leading, spacing: 1) {
                    Text(game.won ? "Win" : "Loss")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                    Text(game.date, format: .dateTime.month(.abbreviated).day())
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(faded)
                }
                Spacer()
                Text(String(format: "%.0f%% bids", game.bidAccuracy * 100))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(faded)
                Text(String(format: "%.1f", game.totalScore))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            if !last { Rectangle().fill(ruled).frame(height: 1).padding(.leading, 12) }
        }
    }
}
