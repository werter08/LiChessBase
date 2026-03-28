//
//  PerfTypeRoute.swift
//  Chess Base
//

import Foundation

/// Detail screen: games list for one `perfType` bucket (matches `PerfTypeGroup.perfTypeKey`).
struct PerfTypeRoute: Hashable {
    let perfTypeKey: String
    let player1Name: String
    let player2Name: String
}
