//
//  GameTypeGamesListView.swift
//  Chess Base
//

import SwiftUI

/// Games for one time control — data comes from the grouped export in `CompareViewModel` (no second request).
struct GameTypeGamesListView: View {
    let route: PerfTypeRoute
    @EnvironmentObject private var compareSession: CompareViewModel

    var body: some View {
        let games = compareSession.games(for: route.perfTypeKey)

        Group {
            if games.isEmpty {
                ContentUnavailableView {
                    Label("No games", systemImage: "square.stack.3d.up.slash")
                } description: {
                    Text("No games in this time control for the loaded export.")
                        .font(.subheadline)
                }
            } else {
                List {
                    Section {
                        ForEach(games) { row in
                            GameResultRowView(
                                row: row,
                                player1Label: route.player1Name,
                                player2Label: route.player2Name
                            )
                        }
                    } header: {
                        Text("Rating change (points)")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(compareSession.displayTitle(for: route.perfTypeKey))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Row

struct GameResultRowView: View {
    let row: GameResultRow
    let player1Label: String
    let player2Label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let label = row.resultLabel {
                    Text(label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                if let d = row.playedAt {
                    Text(d, style: .date)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            HStack(alignment: .firstTextBaseline) {
                ratingColumn(title: player1Label, diff: row.player1RatingDiff)
                Spacer(minLength: 16)
                ratingColumn(title: player2Label, diff: row.player2RatingDiff)
            }
        }
        .padding(.vertical, 4)
    }

    private func ratingColumn(title: String, diff: Int?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(formatDiff(diff))
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(color(for: diff))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatDiff(_ diff: Int?) -> String {
        guard let diff else { return "—" }
        if diff > 0 { return "+\(diff)" }
        return "\(diff)"
    }

    private func color(for diff: Int?) -> Color {
        guard let diff else { return Color(.tertiaryLabel) }
        if diff > 0 { return .green }
        if diff < 0 { return .red }
        return Color(.secondaryLabel)
    }
}

#Preview {
    NavigationStack {
        GameTypeGamesListView(
            route: PerfTypeRoute(
                perfTypeKey: "blitz",
                player1Name: "PlayerA",
                player2Name: "PlayerB"
            )
        )
        .environmentObject(CompareViewModel())
    }
}
