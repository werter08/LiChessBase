//
//  LichessExportedGame.swift
//  Chess Base
//

import Foundation

/// One line from [`GET /api/games/user/{username}`](https://lichess.org/api#tag/Games/operation/apiGamesUser) NDJSON.
struct LichessExportedGame: Decodable {
    let id: String
    let createdAt: Int64
    /// Clock category (bullet, blitz, …).
    let speed: String
    /// Same family as API `perfType` — use for grouping (e.g. `chess960` vs standard at same speed).
    let perf: String?
    let winner: String?
    let players: Players

    struct Players: Decodable {
        let white: Side
        let black: Side
    }

    struct Side: Decodable {
        let user: User
        let ratingDiff: Int?
    }

    struct User: Decodable {
        let id: String
    }
}

enum LichessGamesExportParser {

    /// Single export, no `perfType` filter — group by JSON `perf` (else `speed`), i.e. same idea as `perfType` on the API.
    static func groupedByPerfType(
        ndjson: String,
        player1Id: String,
        player2Id: String,
        player1Display: String,
        player2Display: String
    ) -> [PerfTypeGroup] {
        let p1 = player1Id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let p2 = player2Id.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !p1.isEmpty, !p2.isEmpty else { return [] }

        let p1Title = player1Display.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Player 1" : player1Display
        let p2Title = player2Display.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Player 2" : player2Display

        struct Bucket {
            var winsP1 = 0
            var winsP2 = 0
            var draws = 0
            var rows: [GameResultRow] = []
        }

        var buckets: [String: Bucket] = [:]
        let decoder = JSONDecoder()

        for line in ndjson.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            guard let data = trimmed.data(using: .utf8),
                  let game = try? decoder.decode(LichessExportedGame.self, from: data)
            else { continue }

            let white = game.players.white.user.id.lowercased()
            let black = game.players.black.user.id.lowercased()
            guard (white == p1 && black == p2) || (white == p2 && black == p1) else { continue }

            let perfSource = game.perf ?? game.speed
            let perfTypeKey = LichessSpeed.normalizePerfTypeKey(perfSource)
            var bucket = buckets[perfTypeKey, default: Bucket()]

            switch game.winner {
            case "white":
                if white == p1 { bucket.winsP1 += 1 } else { bucket.winsP2 += 1 }
            case "black":
                if black == p1 { bucket.winsP1 += 1 } else { bucket.winsP2 += 1 }
            default:
                bucket.draws += 1
            }

            let d1 = diff(for: p1, white: game.players.white, black: game.players.black)
            let d2 = diff(for: p2, white: game.players.white, black: game.players.black)
            let label = resultLabel(winner: game.winner)
            let playedAt = Date(timeIntervalSince1970: TimeInterval(game.createdAt) / 1000)

            bucket.rows.append(
                GameResultRow(
                    id: game.id,
                    playedAt: playedAt,
                    player1RatingDiff: d1,
                    player2RatingDiff: d2,
                    resultLabel: label
                )
            )
            buckets[perfTypeKey] = bucket
        }

        let orderedKeys = orderedPerfTypeKeys(from: Set(buckets.keys))
        return orderedKeys.compactMap { key in
            guard let b = buckets[key] else { return nil }
            let sortedRows = b.rows.sorted { ($0.playedAt ?? .distantPast) > ($1.playedAt ?? .distantPast) }
            return PerfTypeGroup(
                perfTypeKey: key,
                player1Title: p1Title,
                player2Title: p2Title,
                winsPlayer1: b.winsP1,
                winsPlayer2: b.winsP2,
                draws: b.draws,
                games: sortedRows
            )
        }
    }

    private static func diff(for userId: String, white: LichessExportedGame.Side, black: LichessExportedGame.Side) -> Int? {
        let uid = userId.lowercased()
        if white.user.id.lowercased() == uid { return white.ratingDiff }
        if black.user.id.lowercased() == uid { return black.ratingDiff }
        return nil
    }

    private static func resultLabel(winner: String?) -> String? {
        if winner == nil { return "½-½" }
        if winner == "white" { return "1-0" }
        if winner == "black" { return "0-1" }
        return "—"
    }

    private static func orderedPerfTypeKeys(from keys: Set<String>) -> [String] {
        let knownOrder = LichessSpeed.displayOrder.map(\.rawValue)
        let known = knownOrder.filter { keys.contains($0) }
        let unknown = keys.subtracting(known).sorted()
        return known + unknown
    }
}

