//
//  HeadToHeadMainResult.swift
//  Chess Base
//

import Foundation

/// Summary row for the overall crosstable card (reusable shape).
struct HeadToHeadMainResult: Equatable {
    let player1Title: String
    let player2Title: String
    let player1Wins: Float
    let player2Wins: Float
    let totalGames: Int
}
