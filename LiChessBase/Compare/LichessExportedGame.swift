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
    let rated: Bool?
    /// How the game ended: mate, resign, outoftime, timeout, draw, stalemate, aborted, noStart, cheat, variantEnd, …
    let status: String?
    /// SAN moves, space-separated (ply count → full moves).
    let moves: String?
    /// Real-time clock; `nil` for correspondence.
    let clock: Clock?
    /// Correspondence games only.
    let daysPerTurn: Int?
    /// Only present when requested with `opening=true`.
    let opening: Opening?
    let players: Players

    struct Players: Decodable {
        let white: Side
        let black: Side
    }

    struct Side: Decodable {
        let user: User
        /// Rating at game time.
        let rating: Int?
        let ratingDiff: Int?
    }

    struct User: Decodable {
        let id: String
        /// Display-cased username (`id` is lowercase).
        let name: String?
    }

    struct Clock: Decodable {
        /// Seconds on the clock at start.
        let initial: Int
        /// Increment per move, seconds.
        let increment: Int
    }

    struct Opening: Decodable {
        let eco: String
        let name: String
        let ply: Int
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
    ) -> [PerfTypeGroupModel] {
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

            // Aborted/never-started games carry no result or rating info — skip them
            // so they don't pollute the draw count or the list.
            if let status = game.status, status == "aborted" || status == "noStart" { continue }

            let perfSource = game.perf ?? game.speed
            let perfTypeKey = LichessSpeed.normalizePerfTypeKey(perfSource)
            var bucket = buckets[perfTypeKey, default: Bucket()]

            let p1IsWhite = (white == p1)
            let outcome: GameResultRow.Outcome?
            switch game.winner {
            case "white":
                outcome = p1IsWhite ? .player1Win : .player2Win
            case "black":
                outcome = p1IsWhite ? .player2Win : .player1Win
            default:
                outcome = .draw
            }
            switch outcome {
            case .player1Win: bucket.winsP1 += 1
            case .player2Win: bucket.winsP2 += 1
            default: bucket.draws += 1
            }

            let p1Side = p1IsWhite ? game.players.white : game.players.black
            let p2Side = p1IsWhite ? game.players.black : game.players.white
            let playedAt = Date(timeIntervalSince1970: TimeInterval(game.createdAt) / 1000)

            bucket.rows.append(
                GameResultRow(
                    id: game.id,
                    playedAt: playedAt,
                    player1RatingDiff: p1Side.ratingDiff,
                    player2RatingDiff: p2Side.ratingDiff,
                    resultLabel: resultLabel(winner: game.winner),
                    outcome: outcome,
                    player1Rating: p1Side.rating,
                    player2Rating: p2Side.rating,
                    player1PlayedWhite: p1IsWhite,
                    terminationLabel: terminationLabel(status: game.status),
                    openingLabel: openingLabel(opening: game.opening),
                    timeControlLabel: timeControlLabel(clock: game.clock, daysPerTurn: game.daysPerTurn),
                    moveCount: moveCount(moves: game.moves),
                    rated: game.rated ?? false,
                    movesSAN: game.moves
                )
            )
            buckets[perfTypeKey] = bucket
        }

        let orderedKeys = orderedPerfTypeKeys(from: Set(buckets.keys))
        return orderedKeys.compactMap { key in
            guard let b = buckets[key] else { return nil }
            let sortedRows = b.rows.sorted { ($0.playedAt ?? .distantPast) > ($1.playedAt ?? .distantPast) }
            return PerfTypeGroupModel(
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

    private static func resultLabel(winner: String?) -> String? {
        if winner == nil { return "½-½" }
        if winner == "white" { return "1-0" }
        if winner == "black" { return "0-1" }
        return "—"
    }

    private static func terminationLabel(status: String?) -> String? {
        switch status {
        case "mate": return "Checkmate"
        case "resign": return "Resignation"
        case "outoftime": return "Time out"
        case "timeout": return "Abandoned"
        case "draw": return "Draw"
        case "stalemate": return "Stalemate"
        case "cheat": return "Cheat detected"
        case "variantEnd": return "Variant end"
        default: return nil
        }
    }

    /// "3+2" for real-time clocks (Lichess fraction style for sub-minute initials), "N days/move" for correspondence.
    private static func timeControlLabel(clock: LichessExportedGame.Clock?, daysPerTurn: Int?) -> String? {
        if let clock {
            let initialLabel: String
            if clock.initial % 60 == 0 {
                initialLabel = "\(clock.initial / 60)"
            } else {
                switch clock.initial {
                case 15: initialLabel = "¼"
                case 30: initialLabel = "½"
                case 45: initialLabel = "¾"
                case 90: initialLabel = "1.5"
                default: initialLabel = "\(clock.initial)s"
                }
            }
            return "\(initialLabel)+\(clock.increment)"
        }
        if let days = daysPerTurn {
            return days == 1 ? "1 day/move" : "\(days) days/move"
        }
        return nil
    }

    private static func moveCount(moves: String?) -> Int? {
        guard let moves else { return nil }
        let ply = moves.split(separator: " ").count
        guard ply > 0 else { return nil }
        return (ply + 1) / 2
    }

    private static func openingLabel(opening: LichessExportedGame.Opening?) -> String? {
        guard let opening else { return nil }
        return "\(opening.eco) · \(opening.name)"
    }

    private static func orderedPerfTypeKeys(from keys: Set<String>) -> [String] {
        let knownOrder = LichessSpeed.displayOrder.map(\.rawValue)
        let known = knownOrder.filter { keys.contains($0) }
        let unknown = keys.subtracting(known).sorted()
        return known + unknown
    }
}
