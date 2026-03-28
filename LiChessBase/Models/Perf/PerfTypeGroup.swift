//
//  PerfTypeGroup.swift
//  Chess Base
//

import Foundation

/// Head-to-head stats for one `perf` bucket (API `perfType`), plus the games in that bucket.
struct PerfTypeGroup: Identifiable {
    let perfTypeKey: String
    var id: String { perfTypeKey }

    let player1Title: String
    let player2Title: String

    let winsPlayer1: Int
    let winsPlayer2: Int
    let draws: Int

    /// Newest first (same order as export).
    let games: [GameResultRow]

    var title: String { LichessSpeed.title(forSpeedKey: perfTypeKey) }

    var totalGames: Int { winsPlayer1 + winsPlayer2 + draws }

    var mainResult: HeadToHeadMainResult {
        HeadToHeadMainResult(
            player1Title: player1Title,
            player2Title: player2Title,
            player1Wins: Float(winsPlayer1),
            player2Wins: Float(winsPlayer2),
            totalGames: totalGames
        )
    }
}
