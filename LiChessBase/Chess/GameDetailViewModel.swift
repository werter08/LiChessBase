//
//  GameDetailViewModel.swift
//  Chess Base
//

import Foundation
import Combine

/// Replay navigation + single-line free analysis for one game.
/// Mainline plies are precomputed; a variation branches off the current ply
/// when the user moves a piece, and "back to game" discards it.
@MainActor
final class GameDetailViewModel: ObservableObject {

    struct PendingPromotion: Identifiable {
        let id = UUID()
        let piece: ChessPiece
        let destination: (Int, Int)
        let color: PieceColor
    }

    @Published private(set) var plies: [ReplayPly] = []
    @Published private(set) var mainlineIndex = 0
    @Published private(set) var variation: [ReplayPly] = []
    @Published private(set) var failedAtMove: Int?
    @Published private(set) var isLoading = true
    @Published private(set) var selectedSquare: (Int, Int)?
    @Published private(set) var legalTargets: [(Int, Int)] = []
    @Published var pendingPromotion: PendingPromotion?
    @Published var flipped: Bool

    private var analysisEngine: ChessEngine?

    init(movesSAN: String?, whiteAtBottom: Bool = true) {
        self.flipped = !whiteAtBottom
        guard let movesSAN, !movesSAN.isEmpty else {
            plies = [GameReplayBuilder.snapshot(engine: ChessEngine(), index: 0, san: nil, lastMove: nil)]
            isLoading = false
            return
        }
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = GameReplayBuilder.build(movesSAN: movesSAN)
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.plies = result.plies
                self.failedAtMove = result.failedAtMove
                self.mainlineIndex = result.plies.count - 1 // open at the final position, like lichess
                self.isLoading = false
            }
        }
    }

    // MARK: - Displayed position

    var currentPly: ReplayPly? { variation.last ?? plies[safe: mainlineIndex] }
    var isInVariation: Bool { !variation.isEmpty }
    var isAtStart: Bool { !isInVariation && mainlineIndex == 0 }
    var isAtEnd: Bool { mainlineIndex >= plies.count - 1 }
    var canGoBack: Bool { isInVariation || mainlineIndex > 0 }

    // MARK: - Mainline navigation

    func toStart() { jump(to: 0) }
    func toEnd() { jump(to: plies.count - 1) }

    func forward() {
        guard !isInVariation, mainlineIndex < plies.count - 1 else { return }
        mainlineIndex += 1
        clearSelection()
    }

    func back() {
        if isInVariation {
            variation.removeLast()
            if variation.isEmpty {
                analysisEngine = nil
            } else {
                reseedAnalysisEngine()
            }
            clearSelection()
            return
        }
        guard mainlineIndex > 0 else { return }
        mainlineIndex -= 1
        clearSelection()
    }

    func jump(to index: Int) {
        guard plies.indices.contains(index) else { return }
        mainlineIndex = index
        backToGame()
    }

    func backToGame() {
        variation = []
        analysisEngine = nil
        clearSelection()
    }

    // MARK: - Free analysis (board taps)

    func handleTap(on square: (Int, Int)) {
        guard !isLoading, let ply = currentPly else { return }

        // Complete a move if a piece is selected and the tap is a legal target.
        if let selected = selectedSquare,
           legalTargets.contains(where: { $0 == square }),
           let engine = ensureAnalysisEngine(),
           let piece = engine.piece(at: selected) {
            let isPromotion = piece.type == .pawn && square.0 == (piece.color == .white ? 7 : 0)
            if isPromotion {
                pendingPromotion = PendingPromotion(piece: piece, destination: square, color: piece.color)
            } else {
                applyAnalysisMove(piece: piece, to: square, promotion: nil)
            }
            return
        }

        // (Re)select one of the side-to-move's pieces.
        if let piece = ply.board[safe: square.0]?[safe: square.1] ?? nil, piece.color == ply.sideToMove {
            guard let engine = ensureAnalysisEngine() else { return }
            selectedSquare = square
            legalTargets = engine.piece(at: square).map(engine.calculateLegalMoves) ?? []
            return
        }

        clearSelection()
    }

    func completePromotion(with type: PieceType) {
        guard let pending = pendingPromotion else { return }
        pendingPromotion = nil
        applyAnalysisMove(piece: pending.piece, to: pending.destination, promotion: type)
    }

    func cancelPromotion() {
        pendingPromotion = nil
        clearSelection()
    }

    private func applyAnalysisMove(piece: ChessPiece, to square: (Int, Int), promotion: PieceType?) {
        guard let engine = analysisEngine else { return }
        let from = piece.position
        let san = engine.makeMove(piece: piece, to: square, promotion: promotion)
        variation.append(
            GameReplayBuilder.snapshot(
                engine: engine,
                index: variation.count + 1,
                san: san,
                lastMove: (from, square)
            )
        )
        clearSelection()
    }

    /// Seeds a live engine from the displayed position on first use.
    private func ensureAnalysisEngine() -> ChessEngine? {
        if let analysisEngine { return analysisEngine }
        guard let ply = currentPly else { return nil }
        let engine = ChessEngine()
        engine.load(
            board: ply.board,
            currentPlayer: ply.sideToMove,
            castling: ply.castling,
            enPassantTarget: ply.enPassantTarget
        )
        analysisEngine = engine
        return engine
    }

    private func reseedAnalysisEngine() {
        guard let ply = currentPly, let engine = analysisEngine else { return }
        engine.load(
            board: ply.board,
            currentPlayer: ply.sideToMove,
            castling: ply.castling,
            enPassantTarget: ply.enPassantTarget
        )
    }

    private func clearSelection() {
        selectedSquare = nil
        legalTargets = []
    }
}

// MARK: - Safe indexing

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
