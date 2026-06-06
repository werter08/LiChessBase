//
//  GameResultRow.swift
//  Chess Base
//

import Foundation

/// One finished game: rating change for each side (Lichess `ratingDiff` style).
/// Populate when you load the games export per time control.
struct GameResultRow: Identifiable, Hashable {

    enum Outcome: Hashable {
        case player1Win
        case player2Win
        case draw
    }

    let id: String
    let playedAt: Date?
    /// Signed rating change for player 1 (your first text field).
    let player1RatingDiff: Int?
    /// Signed rating change for player 2.
    let player2RatingDiff: Int?
    /// Short label, e.g. "1-0" or "½-½".
    let resultLabel: String?
    /// Who won relative to player 1/2; `nil` when unknown.
    let outcome: Outcome?
    /// Rating at game time.
    let player1Rating: Int?
    let player2Rating: Int?
    /// Color assignment — player 2 has the opposite color.
    let player1PlayedWhite: Bool
    /// How the game ended, e.g. "Checkmate", "Resignation".
    let terminationLabel: String?
    /// Opening, e.g. "B90 · Sicilian Defense: Najdorf".
    let openingLabel: String?
    /// Clock, e.g. "3+2", "½+0", "2 days/move".
    let timeControlLabel: String?
    /// Full moves played.
    let moveCount: Int?
    let rated: Bool
    /// Space-separated SAN moves from the export — powers the replay screen.
    let movesSAN: String?
}
