//
//  SanParser.swift
//  Chess Base
//

import Foundation

/// Parses one SAN token (as found in the Lichess export `moves` field) against the
/// engine's current position. Returns nil for illegal/ambiguous/unparseable moves.
nonisolated enum SanParser {

    struct ParsedMove {
        let piece: ChessPiece
        let destination: (Int, Int)
        let promotion: PieceType?
    }

    static func parse(_ san: String, engine: ChessEngine) -> ParsedMove? {
        // Strip check/mate/annotation suffixes.
        var token = san.trimmingCharacters(in: .whitespaces)
        while let last = token.last, "+#!?".contains(last) {
            token.removeLast()
        }
        guard !token.isEmpty else { return nil }

        // Castling
        if token == "O-O" || token == "0-0" {
            return castlingMove(kingside: true, engine: engine)
        }
        if token == "O-O-O" || token == "0-0-0" {
            return castlingMove(kingside: false, engine: engine)
        }

        // [piece][origin file][origin rank][x][destination][=promotion]
        guard let match = token.wholeMatch(of: #/([KQRBN])?([a-h])?([1-8])?(x)?([a-h][1-8])(?:=([QRBN]))?/#) else {
            return nil
        }

        let pieceType: PieceType
        if let letter = match.1?.first {
            guard let type = ChessEngine.pieceType(forLetter: letter) else { return nil }
            pieceType = type
        } else {
            pieceType = .pawn
        }

        guard let destination = square(from: String(match.5)) else { return nil }
        let originFile = match.2.flatMap { fileIndex($0.first!) }
        let originRank = match.3.flatMap { Int(String($0)).map { $0 - 1 } }
        let promotion = match.6?.first.flatMap { ChessEngine.pieceType(forLetter: $0) }

        // Candidates: side-to-move pieces of the right type that can legally reach the square
        // and match the origin disambiguation.
        let allPieces: [ChessPiece] = engine.board.flatMap { $0 }.compactMap { $0 }
        let candidates = allPieces.filter { piece in
            guard piece.type == pieceType, piece.color == engine.currentPlayer else { return false }
            if let originFile, piece.position.1 != originFile { return false }
            if let originRank, piece.position.0 != originRank { return false }
            return engine.calculateLegalMoves(for: piece).contains(where: { $0 == destination })
        }

        guard candidates.count == 1 else { return nil }
        return ParsedMove(piece: candidates[0], destination: destination, promotion: promotion)
    }

    private static func castlingMove(kingside: Bool, engine: ChessEngine) -> ParsedMove? {
        let row = engine.currentPlayer == .white ? 0 : 7
        let destination = (row, kingside ? 6 : 2)
        guard let king = engine.piece(at: (row, 4)),
              king.type == .king,
              king.color == engine.currentPlayer,
              engine.calculateLegalMoves(for: king).contains(where: { $0 == destination })
        else { return nil }
        return ParsedMove(piece: king, destination: destination, promotion: nil)
    }

    private static func square(from name: String) -> (Int, Int)? {
        guard name.count == 2,
              let file = fileIndex(name.first!),
              let rank = Int(String(name.last!)), (1...8).contains(rank)
        else { return nil }
        return (rank - 1, file)
    }

    private static func fileIndex(_ char: Character) -> Int? {
        guard let ascii = char.asciiValue, (97...104).contains(ascii) else { return nil }
        return Int(ascii) - 97
    }
}
