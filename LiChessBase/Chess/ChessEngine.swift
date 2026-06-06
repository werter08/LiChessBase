//
//  ChessEngine.swift
//  Chess Base
//
//  Ported from chess_swiftui (ChessGame.swift) with fixes:
//  - en passant captures now remove the captured pawn
//  - enPassantTarget is cleared on every move
//  - promotion is applied directly via parameter (no pending-UI flow)
//  - board-snapshot history removed (the replay layer owns snapshots)
//  - SAN generation and arbitrary-position seeding added
//

import Foundation

// The whole chess model layer is nonisolated (the project defaults to MainActor
// isolation) so replays can be built off the main thread.

nonisolated enum PieceType: String {
    case pawn, knight, bishop, rook, queen, king
}

nonisolated enum PieceColor: String, Hashable {
    case white, black

    var opponent: PieceColor {
        self == .white ? .black : .white
    }
}

nonisolated struct ChessPiece: Hashable {
    let type: PieceType
    let color: PieceColor
    var position: (Int, Int)
    var hasMoved: Bool = false

    static func == (lhs: ChessPiece, rhs: ChessPiece) -> Bool {
        lhs.type == rhs.type
            && lhs.color == rhs.color
            && lhs.position == rhs.position
            && lhs.hasMoved == rhs.hasMoved
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(type)
        hasher.combine(color)
        hasher.combine(position.0)
        hasher.combine(position.1)
        hasher.combine(hasMoved)
    }
}

/// Castling rights, snapshot-friendly (the engine's per-rook/king flags in one value).
nonisolated struct CastlingState: Hashable {
    var whiteKingMoved = false
    var blackKingMoved = false
    var whiteRookLeftMoved = false   // queenside, col 0
    var whiteRookRightMoved = false  // kingside, col 7
    var blackRookLeftMoved = false
    var blackRookRightMoved = false
}

/// Square of a pawn that just double-pushed (capturable en passant this ply).
nonisolated struct EnPassantTarget: Hashable {
    let row: Int
    let col: Int
    let color: PieceColor
}

/// Board convention: `board[row][col]`, row 0 = white back rank, col 0 = a-file.
/// SAN square e4 = (row 3, col 4).
nonisolated final class ChessEngine {
    private(set) var board: [[ChessPiece?]] = Array(repeating: Array(repeating: nil, count: 8), count: 8)
    private(set) var currentPlayer: PieceColor = .white
    private(set) var isInCheck = false
    private(set) var isCheckmate = false
    private(set) var isStalemate = false
    private(set) var castling = CastlingState()
    private(set) var enPassantTarget: EnPassantTarget?

    init() {
        setupBoard()
        updateGameState()
    }

    // MARK: - Setup / seeding

    func setupBoard() {
        board = Array(repeating: Array(repeating: nil, count: 8), count: 8)
        for i in 0..<8 {
            board[1][i] = ChessPiece(type: .pawn, color: .white, position: (1, i))
            board[6][i] = ChessPiece(type: .pawn, color: .black, position: (6, i))
        }
        let backRank: [PieceType] = [.rook, .knight, .bishop, .queen, .king, .bishop, .knight, .rook]
        for (col, type) in backRank.enumerated() {
            board[0][col] = ChessPiece(type: type, color: .white, position: (0, col))
            board[7][col] = ChessPiece(type: type, color: .black, position: (7, col))
        }
    }

    /// Seed the engine from an arbitrary position (e.g. a replay ply, to start free analysis).
    func load(
        board: [[ChessPiece?]],
        currentPlayer: PieceColor,
        castling: CastlingState,
        enPassantTarget: EnPassantTarget?
    ) {
        self.board = board
        self.currentPlayer = currentPlayer
        self.castling = castling
        self.enPassantTarget = enPassantTarget
        updateGameState()
    }

    // MARK: - Legal moves

    func piece(at position: (Int, Int)) -> ChessPiece? {
        guard isValidPosition(position.0, position.1) else { return nil }
        return board[position.0][position.1]
    }

    func calculateLegalMoves(for piece: ChessPiece) -> [(Int, Int)] {
        calculateMoves(for: piece).filter { willResolveCheck(for: piece, to: $0) }
    }

    private func calculateMoves(for piece: ChessPiece) -> [(Int, Int)] {
        var moves: [(Int, Int)] = []
        let position = piece.position

        switch piece.type {
        case .pawn:
            moves += calculatePawnMoves(for: piece)

        case .rook:
            moves += directionalMoves(for: piece, directions: [(1, 0), (-1, 0), (0, 1), (0, -1)])

        case .knight:
            let knightMoves = [(2, 1), (2, -1), (-2, 1), (-2, -1),
                               (1, 2), (1, -2), (-1, 2), (-1, -2)]
            for move in knightMoves {
                let newRow = position.0 + move.0
                let newCol = position.1 + move.1
                if isValidPosition(newRow, newCol), board[newRow][newCol]?.color != piece.color {
                    moves.append((newRow, newCol))
                }
            }

        case .bishop:
            moves += directionalMoves(for: piece, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1)])

        case .queen:
            moves += directionalMoves(for: piece, directions: [(1, 0), (-1, 0), (0, 1), (0, -1),
                                                               (1, 1), (1, -1), (-1, 1), (-1, -1)])

        case .king:
            let kingMoves = [(1, 0), (-1, 0), (0, 1), (0, -1),
                             (1, 1), (1, -1), (-1, 1), (-1, -1)]
            for move in kingMoves {
                let newRow = position.0 + move.0
                let newCol = position.1 + move.1
                if isValidPosition(newRow, newCol), board[newRow][newCol]?.color != piece.color {
                    if !isSquareUnderAttack((newRow, newCol), byColor: piece.color.opponent) {
                        moves.append((newRow, newCol))
                    }
                }
            }
            moves += calculateCastlingMoves(for: piece)
        }

        return moves
    }

    private func calculatePawnMoves(for piece: ChessPiece) -> [(Int, Int)] {
        var moves: [(Int, Int)] = []
        let position = piece.position
        let direction = piece.color == .white ? 1 : -1
        let startRow = piece.color == .white ? 1 : 6
        let nextRow = position.0 + direction

        // Forward
        if isValidPosition(nextRow, position.1), board[nextRow][position.1] == nil {
            moves.append((nextRow, position.1))

            let twoStepsRow = position.0 + 2 * direction
            if position.0 == startRow, board[twoStepsRow][position.1] == nil {
                moves.append((twoStepsRow, position.1))
            }
        }

        // Diagonal captures (incl. en passant)
        for dx in [-1, 1] {
            let newCol = position.1 + dx
            if isValidPosition(nextRow, newCol) {
                if let targetPiece = board[nextRow][newCol], targetPiece.color == piece.color.opponent {
                    moves.append((nextRow, newCol))
                }
                if let enPassant = enPassantTarget,
                   enPassant.row == position.0, enPassant.col == newCol,
                   enPassant.color == piece.color.opponent {
                    moves.append((nextRow, newCol))
                }
            }
        }

        return moves
    }

    private func directionalMoves(for piece: ChessPiece, directions: [(Int, Int)]) -> [(Int, Int)] {
        var moves: [(Int, Int)] = []
        for direction in directions {
            var newRow = piece.position.0 + direction.0
            var newCol = piece.position.1 + direction.1
            while isValidPosition(newRow, newCol) {
                if let targetPiece = board[newRow][newCol] {
                    if targetPiece.color != piece.color {
                        moves.append((newRow, newCol))
                    }
                    break
                }
                moves.append((newRow, newCol))
                newRow += direction.0
                newCol += direction.1
            }
        }
        return moves
    }

    private func calculateCastlingMoves(for king: ChessPiece) -> [(Int, Int)] {
        guard king.type == .king else { return [] }
        var castlingMoves: [(Int, Int)] = []

        let row = king.color == .white ? 0 : 7
        let kingMoved = king.color == .white ? castling.whiteKingMoved : castling.blackKingMoved
        let leftRookMoved = king.color == .white ? castling.whiteRookLeftMoved : castling.blackRookLeftMoved
        let rightRookMoved = king.color == .white ? castling.whiteRookRightMoved : castling.blackRookRightMoved
        let opponentColor = king.color.opponent

        if kingMoved || king.position != (row, 4) || isSquareUnderAttack((row, 4), byColor: opponentColor) {
            return castlingMoves
        }

        // Kingside
        if !rightRookMoved,
           board[row][5] == nil,
           board[row][6] == nil,
           !isSquareUnderAttack((row, 5), byColor: opponentColor),
           !isSquareUnderAttack((row, 6), byColor: opponentColor),
           board[row][7]?.type == .rook,
           board[row][7]?.color == king.color {
            castlingMoves.append((row, 6))
        }

        // Queenside
        if !leftRookMoved,
           board[row][1] == nil,
           board[row][2] == nil,
           board[row][3] == nil,
           !isSquareUnderAttack((row, 3), byColor: opponentColor),
           !isSquareUnderAttack((row, 2), byColor: opponentColor),
           board[row][0]?.type == .rook,
           board[row][0]?.color == king.color {
            castlingMoves.append((row, 2))
        }

        return castlingMoves
    }

    // MARK: - Attack detection

    private func isSquareUnderAttack(_ position: (Int, Int), byColor attackingColor: PieceColor) -> Bool {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col], piece.color == attackingColor {
                    if calculateAttackSquares(for: piece).contains(where: { $0 == position }) {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func calculateAttackSquares(for piece: ChessPiece) -> [(Int, Int)] {
        var attackSquares: [(Int, Int)] = []
        let position = piece.position

        switch piece.type {
        case .pawn:
            let direction = piece.color == .white ? 1 : -1
            for dx in [-1, 1] {
                let newRow = position.0 + direction
                let newCol = position.1 + dx
                if isValidPosition(newRow, newCol) {
                    attackSquares.append((newRow, newCol))
                }
            }

        case .knight:
            let knightMoves = [(2, 1), (2, -1), (-2, 1), (-2, -1),
                               (1, 2), (1, -2), (-1, 2), (-1, -2)]
            for move in knightMoves {
                let newRow = position.0 + move.0
                let newCol = position.1 + move.1
                if isValidPosition(newRow, newCol) {
                    attackSquares.append((newRow, newCol))
                }
            }

        case .bishop:
            attackSquares += attackDirectionalMoves(for: piece, directions: [(1, 1), (1, -1), (-1, 1), (-1, -1)])

        case .rook:
            attackSquares += attackDirectionalMoves(for: piece, directions: [(1, 0), (-1, 0), (0, 1), (0, -1)])

        case .queen:
            attackSquares += attackDirectionalMoves(for: piece, directions: [(1, 0), (-1, 0), (0, 1), (0, -1),
                                                                             (1, 1), (1, -1), (-1, 1), (-1, -1)])

        case .king:
            let kingMoves = [(1, 0), (-1, 0), (0, 1), (0, -1),
                             (1, 1), (1, -1), (-1, 1), (-1, -1)]
            for move in kingMoves {
                let newRow = position.0 + move.0
                let newCol = position.1 + move.1
                if isValidPosition(newRow, newCol) {
                    attackSquares.append((newRow, newCol))
                }
            }
        }

        return attackSquares
    }

    private func attackDirectionalMoves(for piece: ChessPiece, directions: [(Int, Int)]) -> [(Int, Int)] {
        var attackSquares: [(Int, Int)] = []
        for direction in directions {
            var newRow = piece.position.0 + direction.0
            var newCol = piece.position.1 + direction.1
            while isValidPosition(newRow, newCol) {
                attackSquares.append((newRow, newCol))
                if board[newRow][newCol] != nil {
                    break
                }
                newRow += direction.0
                newCol += direction.1
            }
        }
        return attackSquares
    }

    // TODO: doesn't simulate the en-passant-captured pawn's removal — a pinned en passant
    // capture could be wrongly allowed. Irrelevant for replaying legal Lichess games.
    private func willResolveCheck(for piece: ChessPiece, to destination: (Int, Int)) -> Bool {
        let originalPosition = piece.position
        let targetPiece = board[destination.0][destination.1]
        board[originalPosition.0][originalPosition.1] = nil
        board[destination.0][destination.1] = ChessPiece(type: piece.type, color: piece.color, position: destination)

        let kingPosition = piece.type == .king ? destination : findKingPosition(color: piece.color)
        let isStillInCheck = isSquareUnderAttack(kingPosition, byColor: piece.color.opponent)

        board[originalPosition.0][originalPosition.1] = piece
        board[destination.0][destination.1] = targetPiece

        return !isStillInCheck
    }

    private func findKingPosition(color: PieceColor) -> (Int, Int) {
        for row in 0..<8 {
            for col in 0..<8 {
                if let piece = board[row][col], piece.type == .king, piece.color == color {
                    return (row, col)
                }
            }
        }
        return (-1, -1)
    }

    // MARK: - Making moves

    /// Applies a legal move and returns its SAN string (with `+`/`#` suffix).
    /// `promotion` is consulted only when a pawn reaches the back rank (defaults to queen).
    @discardableResult
    func makeMove(piece: ChessPiece, to position: (Int, Int), promotion: PieceType? = nil) -> String {
        let base = sanBase(for: piece, to: position, promotion: promotion)
        performMove(piece: piece, to: position, promotion: promotion)
        if isCheckmate { return base + "#" }
        if isInCheck { return base + "+" }
        return base
    }

    private func performMove(piece: ChessPiece, to position: (Int, Int), promotion: PieceType?) {
        let startRow = piece.position.0
        let startCol = piece.position.1

        // En passant capture: pawn moves diagonally onto an empty square —
        // the captured pawn sits beside the start square.
        if piece.type == .pawn, position.1 != startCol, board[position.0][position.1] == nil {
            board[startRow][position.1] = nil
        }

        // A target only survives for the one reply move.
        enPassantTarget = nil
        if piece.type == .pawn, abs(position.0 - startRow) == 2 {
            enPassantTarget = EnPassantTarget(row: position.0, col: position.1, color: piece.color)
        }

        // Castling: move the rook too.
        if piece.type == .king, abs(position.1 - startCol) == 2 {
            let rookStartCol = position.1 == 6 ? 7 : 0
            let rookEndCol = position.1 == 6 ? 5 : 3
            if let rook = board[startRow][rookStartCol] {
                board[startRow][rookEndCol] = ChessPiece(type: rook.type, color: rook.color, position: (startRow, rookEndCol), hasMoved: true)
                board[startRow][rookStartCol] = nil
            }
        }

        // Move the piece (promoting if a pawn reaches the back rank).
        var placedType = piece.type
        if piece.type == .pawn, position.0 == (piece.color == .white ? 7 : 0) {
            placedType = promotion ?? .queen
        }
        board[startRow][startCol] = nil
        board[position.0][position.1] = ChessPiece(type: placedType, color: piece.color, position: position, hasMoved: true)

        // Castling rights
        if piece.type == .king {
            if piece.color == .white { castling.whiteKingMoved = true } else { castling.blackKingMoved = true }
        }
        if piece.type == .rook {
            switch (piece.color, startCol) {
            case (.white, 0): castling.whiteRookLeftMoved = true
            case (.white, 7): castling.whiteRookRightMoved = true
            case (.black, 0): castling.blackRookLeftMoved = true
            case (.black, 7): castling.blackRookRightMoved = true
            default: break
            }
        }
        // Losing a rook on its home square also forfeits that side's castling right.
        switch position {
        case (0, 0): castling.whiteRookLeftMoved = true
        case (0, 7): castling.whiteRookRightMoved = true
        case (7, 0): castling.blackRookLeftMoved = true
        case (7, 7): castling.blackRookRightMoved = true
        default: break
        }

        currentPlayer = currentPlayer.opponent
        updateGameState()
    }

    private func updateGameState() {
        let kingPosition = findKingPosition(color: currentPlayer)
        isInCheck = isSquareUnderAttack(kingPosition, byColor: currentPlayer.opponent)
        let anyMoves = hasLegalMoves(forColor: currentPlayer)
        isCheckmate = isInCheck && !anyMoves
        isStalemate = !isInCheck && !anyMoves
    }

    private func hasLegalMoves(forColor color: PieceColor) -> Bool {
        let pieces = board.flatMap { $0 }.compactMap { $0 }.filter { $0.color == color }
        for piece in pieces where !calculateLegalMoves(for: piece).isEmpty {
            return true
        }
        return false
    }

    // MARK: - SAN

    static func squareName(_ position: (Int, Int)) -> String {
        let file = Character(UnicodeScalar(UInt8(97 + position.1)))
        return "\(file)\(position.0 + 1)"
    }

    /// SAN without the check/mate suffix — must be computed against the pre-move position.
    private func sanBase(for piece: ChessPiece, to position: (Int, Int), promotion: PieceType?) -> String {
        // Castling
        if piece.type == .king, abs(position.1 - piece.position.1) == 2 {
            return position.1 == 6 ? "O-O" : "O-O-O"
        }

        let destination = Self.squareName(position)
        let isCapture = board[position.0][position.1] != nil
            || (piece.type == .pawn && position.1 != piece.position.1)

        if piece.type == .pawn {
            var san = isCapture
                ? "\(Character(UnicodeScalar(UInt8(97 + piece.position.1))))x\(destination)"
                : destination
            if position.0 == (piece.color == .white ? 7 : 0) {
                san += "=\(Self.pieceLetter(promotion ?? .queen))"
            }
            return san
        }

        var san = String(Self.pieceLetter(piece.type))
        san += disambiguation(for: piece, to: position)
        if isCapture { san += "x" }
        san += destination
        return san
    }

    /// Minimal origin disambiguation: file, then rank, then both (SAN rules).
    private func disambiguation(for piece: ChessPiece, to position: (Int, Int)) -> String {
        guard piece.type != .king else { return "" }
        let rivals = board.flatMap { $0 }.compactMap { $0 }.filter {
            $0.type == piece.type
                && $0.color == piece.color
                && $0.position != piece.position
                && calculateLegalMoves(for: $0).contains(where: { $0 == position })
        }
        guard !rivals.isEmpty else { return "" }

        let fileChar = String(Character(UnicodeScalar(UInt8(97 + piece.position.1))))
        let rankChar = "\(piece.position.0 + 1)"
        if !rivals.contains(where: { $0.position.1 == piece.position.1 }) {
            return fileChar
        }
        if !rivals.contains(where: { $0.position.0 == piece.position.0 }) {
            return rankChar
        }
        return fileChar + rankChar
    }

    static func pieceLetter(_ type: PieceType) -> Character {
        switch type {
        case .pawn: return "P"
        case .knight: return "N"
        case .bishop: return "B"
        case .rook: return "R"
        case .queen: return "Q"
        case .king: return "K"
        }
    }

    static func pieceType(forLetter letter: Character) -> PieceType? {
        switch letter {
        case "N": return .knight
        case "B": return .bishop
        case "R": return .rook
        case "Q": return .queen
        case "K": return .king
        case "P": return .pawn
        default: return nil
        }
    }

    // MARK: - Helpers

    func isValidPosition(_ row: Int, _ col: Int) -> Bool {
        (0..<8).contains(row) && (0..<8).contains(col)
    }
}
