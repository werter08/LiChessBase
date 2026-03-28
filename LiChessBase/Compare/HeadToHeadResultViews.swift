//
//  HeadToHeadResultViews.swift
//  LiChessBase
//

import SwiftUI

// MARK: - Main crosstable card

struct HeadToHeadMainResultCard: View {
    let result: HeadToHeadMainResult
    var showsSectionTitle: Bool = true
    /// When set, shown instead of "Results" (e.g. per time control).
    var sectionTitle: String = "Results"

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsSectionTitle {
                Text(sectionTitle)
                    .font(.headline)
            }

            HStack(spacing: 12) {
                PlayerWinSummaryPill(
                    title: result.player1Title,
                    wins: result.player1Wins,
                    opponentWins: result.player2Wins
                )
                PlayerWinSummaryPill(
                    title: result.player2Title,
                    wins: result.player2Wins,
                    opponentWins: result.player1Wins
                )
            }

            GamesPlayedRow(totalGames: result.totalGames)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
        }
    }
}

// MARK: - Shared rows

struct GamesPlayedRow: View {
    let totalGames: Int

    var body: some View {
        HStack {
            Label("Games played", systemImage: "square.grid.3x3.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(totalGames)")
                .font(.title3.monospacedDigit().weight(.semibold))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        }
    }
}

struct PlayerWinSummaryPill: View {
    let title: String
    let wins: Float
    let opponentWins: Float

    private var winColor: Color {
        if abs(wins - opponentWins) < 0.001 { return Color(.tertiaryLabel) }
        return wins > opponentWins ? Color(.systemGreen) : Color(.systemRed)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(String(format: "%.1f", wins))
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(winColor)
            Text("wins")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
        }
    }
}

// MARK: - Per–time-control cards (same layout as main result; data from one export, grouped in-app)

struct PerfTypeCarousel: View {
    let groups: [PerfTypeGroupModel]
    let player1Name: String
    let player2Name: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filtered By Type")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(groups) { group in
                        NavigationLink(
                            value: PerfTypeRoute(
                                perfTypeKey: group.perfTypeKey,
                                player1Name: player1Name,
                                player2Name: player2Name
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .center, spacing: 10) {
                                    PerfTypeFlairImage(perfTypeKey: group.perfTypeKey, size: 36)
                                    Text(group.title)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                }
                                HeadToHeadMainResultCard(
                                    result: group.mainResult,
                                    showsSectionTitle: false,
                                    sectionTitle: group.title
                                )
                            }
                            .frame(width: 280, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}
