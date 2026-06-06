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
                            if row.movesSAN?.isEmpty == false {
                                NavigationLink(
                                    value: GameDetailRoute(
                                        row: row,
                                        player1Name: route.player1Name,
                                        player2Name: route.player2Name
                                    )
                                ) {
                                    GameResultRowView(
                                        row: row,
                                        player1Label: route.player1Name,
                                        player2Label: route.player2Name
                                    )
                                }
                            } else {
                                GameResultRowView(
                                    row: row,
                                    player1Label: route.player1Name,
                                    player2Label: route.player2Name
                                )
                            }
                        }
                    } header: {
                        Text("^[\(games.count) game](inflect: true)")
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
        VStack(alignment: .leading, spacing: 8) {
            header
            playerLine(
                title: player1Label,
                playsWhite: row.player1PlayedWhite,
                rating: row.player1Rating,
                diff: row.player1RatingDiff,
                isWinner: row.outcome == .player1Win
            )
            playerLine(
                title: player2Label,
                playsWhite: !row.player1PlayedWhite,
                rating: row.player2Rating,
                diff: row.player2RatingDiff,
                isWinner: row.outcome == .player2Win
            )
            footer
        }
        .padding(.vertical, 4)
    }

    // MARK: Header — result, termination, date+time

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            if let label = row.resultLabel {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            if let termination = row.terminationLabel {
                Text("· \(termination)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let d = row.playedAt {
                Text(d, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: Player line — color, name, rating, diff

    private func playerLine(title: String, playsWhite: Bool, rating: Int?, diff: Int?, isWinner: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: playsWhite ? "circle" : "circle.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.subheadline.weight(isWinner ? .semibold : .regular))
                .foregroundStyle(isWinner ? .primary : .secondary)
                .lineLimit(1)
            if let rating {
                Text("\(rating)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if isWinner {
                Image(systemName: "crown.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
            Spacer(minLength: 12)
            Text(formatDiff(diff))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(color(for: diff))
        }
    }

    // MARK: Footer — opening + meta

    @ViewBuilder
    private var footer: some View {
        if let opening = row.openingLabel {
            Text(opening)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        if !metaParts.isEmpty {
            Text(metaParts.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private var metaParts: [String] {
        var parts: [String] = []
        if let tc = row.timeControlLabel { parts.append(tc) }
        if let moves = row.moveCount {
            parts.append(moves == 1 ? "1 move" : "\(moves) moves")
        }
        parts.append(row.rated ? "Rated" : "Casual")
        return parts
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

#Preview("Games list") {
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

#Preview("Rows") {
    List {
        GameResultRowView(
            row: GameResultRow(
                id: "abc123",
                playedAt: Date(timeIntervalSince1970: 1_770_000_000),
                player1RatingDiff: 5,
                player2RatingDiff: -4,
                resultLabel: "1-0",
                outcome: .player1Win,
                player1Rating: 2456,
                player2Rating: 2511,
                player1PlayedWhite: true,
                terminationLabel: "Resignation",
                openingLabel: "B90 · Sicilian Defense: Najdorf Variation",
                timeControlLabel: "3+2",
                moveCount: 42,
                rated: true,
                movesSAN: "e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6"
            ),
            player1Label: "PlayerA",
            player2Label: "PlayerB"
        )
        GameResultRowView(
            row: GameResultRow(
                id: "def456",
                playedAt: Date(timeIntervalSince1970: 1_769_000_000),
                player1RatingDiff: 0,
                player2RatingDiff: 0,
                resultLabel: "½-½",
                outcome: .draw,
                player1Rating: 1850,
                player2Rating: 1843,
                player1PlayedWhite: false,
                terminationLabel: "Stalemate",
                openingLabel: "C50 · Italian Game",
                timeControlLabel: "½+0",
                moveCount: 67,
                rated: false,
                movesSAN: nil
            ),
            player1Label: "PlayerA",
            player2Label: "PlayerB"
        )
        GameResultRowView(
            row: GameResultRow(
                id: "ghi789",
                playedAt: nil,
                player1RatingDiff: nil,
                player2RatingDiff: nil,
                resultLabel: "0-1",
                outcome: .player2Win,
                player1Rating: nil,
                player2Rating: nil,
                player1PlayedWhite: true,
                terminationLabel: nil,
                openingLabel: nil,
                timeControlLabel: "2 days/move",
                moveCount: nil,
                rated: true,
                movesSAN: nil
            ),
            player1Label: "PlayerA",
            player2Label: "PlayerB"
        )
    }
    .listStyle(.insetGrouped)
}
