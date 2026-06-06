//
//  GameReplay.swift
//  Chess Base
//

import Foundation

/// One position in a replay line. Index 0 is the starting position (no move).
/// Carries full engine state so analysis can branch from any ply.
nonisolated struct ReplayPly: Identifiable {
    let index: Int
    /// SAN of the move that produced this position (nil for the start position).
    let san: String?
    let lastMove: (from: (Int, Int), to: (Int, Int))?
    let board: [[ChessPiece?]]
    let sideToMove: PieceColor
    let castling: CastlingState
    let enPassantTarget: EnPassantTarget?

    var id: Int { index }

    /// 1-based full-move number for a move ply ("1." for plies 1 and 2).
    var moveNumber: Int { (index + 1) / 2 }
    var isWhiteMove: Bool { index % 2 == 1 }
}

nonisolated enum GameReplayBuilder {

    struct Result {
        let plies: [ReplayPly]
        /// 1-based index of the first SAN token that failed to apply; nil when complete.
        let failedAtMove: Int?
    }

    /// Replays a space-separated SAN string (Lichess export `moves` field) from the
    /// standard start position, snapshotting full state per ply.
    static func build(movesSAN: String) -> Result {
        let engine = ChessEngine()
        var plies: [ReplayPly] = [snapshot(engine: engine, index: 0, san: nil, lastMove: nil)]

        let tokens = movesSAN.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        for (i, token) in tokens.enumerated() {
            guard let move = SanParser.parse(token, engine: engine) else {
                return Result(plies: plies, failedAtMove: i + 1)
            }
            let from = move.piece.position
            let san = engine.makeMove(piece: move.piece, to: move.destination, promotion: move.promotion)
            plies.append(snapshot(engine: engine, index: i + 1, san: san, lastMove: (from, move.destination)))
        }
        return Result(plies: plies, failedAtMove: nil)
    }

    static func snapshot(
        engine: ChessEngine,
        index: Int,
        san: String?,
        lastMove: (from: (Int, Int), to: (Int, Int))?
    ) -> ReplayPly {
        ReplayPly(
            index: index,
            san: san,
            lastMove: lastMove,
            board: engine.board, // value semantics — array of structs copies
            sideToMove: engine.currentPlayer,
            castling: engine.castling,
            enPassantTarget: engine.enPassantTarget
        )
    }
}
