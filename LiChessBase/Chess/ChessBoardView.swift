//
//  ChessBoardView.swift
//  Chess Base
//

import SwiftUI

/// Pure display board — no engine dependency. Lichess-style square colors,
/// last-move tint, selection highlight, legal-move dots, edge coordinates.
struct ChessBoardView: View {
    let board: [[ChessPiece?]]
    let lastMove: (from: (Int, Int), to: (Int, Int))?
    let selected: (Int, Int)?
    let legalTargets: [(Int, Int)]
    let flipped: Bool
    let onTapSquare: ((Int, Int)) -> Void

    private static let lightSquare = Color(red: 0.94, green: 0.85, blue: 0.71) // #f0d9b5
    private static let darkSquare = Color(red: 0.71, green: 0.53, blue: 0.39)  // #b58863
    private static let highlight = Color(red: 0.61, green: 0.78, blue: 0.0).opacity(0.45) // lichess yellow-green

    var body: some View {
        GeometryReader { geometry in
            let squareSize = geometry.size.width / 8
            VStack(spacing: 0) {
                ForEach(0..<8, id: \.self) { displayRow in
                    HStack(spacing: 0) {
                        ForEach(0..<8, id: \.self) { displayCol in
                            let row = flipped ? displayRow : 7 - displayRow
                            let col = flipped ? 7 - displayCol : displayCol
                            squareView(row: row, col: col, size: squareSize, displayRow: displayRow, displayCol: displayCol)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func squareView(row: Int, col: Int, size: CGFloat, displayRow: Int, displayCol: Int) -> some View {
        let isLight = (row + col) % 2 == 1
        let piece = board[safe: row]?[safe: col] ?? nil
        let isLastMove = lastMove.map { $0.from == (row, col) || $0.to == (row, col) } ?? false
        let isSelected = selected.map { $0 == (row, col) } ?? false
        let isTarget = legalTargets.contains(where: { $0 == (row, col) })

        return ZStack {
            (isLight ? Self.lightSquare : Self.darkSquare)
            if isLastMove || isSelected {
                Self.highlight
            }

            if let piece {
                Image("\(piece.type.rawValue)_\(piece.color.rawValue)")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.06)
            }

            if isTarget {
                if piece == nil {
                    Circle()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: size * 0.3, height: size * 0.3)
                } else {
                    Circle() // capture ring
                        .strokeBorder(Color.black.opacity(0.25), lineWidth: size * 0.08)
                        .padding(size * 0.04)
                }
            }

            coordinates(row: row, col: col, isLight: isLight, size: size, displayRow: displayRow, displayCol: displayCol)
        }
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .onTapGesture { onTapSquare((row, col)) }
    }

    /// Rank labels down the left display edge, file labels along the bottom display edge.
    @ViewBuilder
    private func coordinates(row: Int, col: Int, isLight: Bool, size: CGFloat, displayRow: Int, displayCol: Int) -> some View {
        let labelColor = isLight ? Self.darkSquare : Self.lightSquare
        if displayCol == 0 {
            Text("\(row + 1)")
                .font(.system(size: size * 0.2, weight: .semibold))
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(size * 0.05)
        }
        if displayRow == 7 {
            Text(String(Character(UnicodeScalar(UInt8(97 + col)))))
                .font(.system(size: size * 0.2, weight: .semibold))
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(size * 0.05)
        }
    }
}

#Preview("Start position") {
    let engine = ChessEngine()
    return ChessBoardView(
        board: engine.board,
        lastMove: nil,
        selected: nil,
        legalTargets: [],
        flipped: false,
        onTapSquare: { _ in }
    )
    .padding()
}

#Preview("Mid-game, flipped, highlights") {
    let result = GameReplayBuilder.build(movesSAN: "e4 c5 Nf3 d6 d4 cxd4 Nxd4 Nf6 Nc3 a6")
    let ply = result.plies.last!
    return ChessBoardView(
        board: ply.board,
        lastMove: ply.lastMove,
        selected: (4, 4),
        legalTargets: [(3, 3), (3, 4)],
        flipped: true,
        onTapSquare: { _ in }
    )
    .padding()
}
