//
//  GameResultRow.swift
//  Chess Base
//

import Foundation

/// One finished game: rating change for each side (Lichess `ratingDiff` style).
/// Populate when you load the games export per time control.
struct GameResultRow: Identifiable, Hashable {
    let id: String
    let playedAt: Date?
    /// Signed rating change for player 1 (your first text field).
    let player1RatingDiff: Int?
    /// Signed rating change for player 2.
    let player2RatingDiff: Int?
    /// Short label, e.g. "1-0" or "½-½".
    let resultLabel: String?
}
