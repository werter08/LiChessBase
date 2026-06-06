//
//  GameDetailRoute.swift
//  Chess Base
//

import Foundation

/// Detail screen: replay/analysis viewer for one game from the games list.
struct GameDetailRoute: Hashable {
    let row: GameResultRow
    let player1Name: String
    let player2Name: String
}
