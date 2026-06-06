//
//  GameDetailView.swift
//  Chess Base
//

import SwiftUI

/// Lichess-style game viewer: board + tappable move list + replay controls,
/// with free analysis — move pieces from any position, then "Back to game".
struct GameDetailView: View {
    let route: GameDetailRoute
    @StateObject private var viewModel: GameDetailViewModel

    init(route: GameDetailRoute) {
        self.route = route
        _viewModel = StateObject(wrappedValue: GameDetailViewModel(movesSAN: route.row.movesSAN))
    }

    var body: some View {
        VStack(spacing: 12) {
            if viewModel.isLoading {
                Spacer()
                ProgressView("Loading game…")
                Spacer()
            } else {
                playerBar(forWhite: viewModel.flipped)   // side shown at the top
                board
                playerBar(forWhite: !viewModel.flipped)  // side shown at the bottom
                statusLine
                moveList
                controls
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if let pending = viewModel.pendingPromotion {
                Color.black.opacity(0.3).ignoresSafeArea()
                PromotionPickerView(
                    color: pending.color,
                    onPick: { viewModel.completePromotion(with: $0) },
                    onCancel: { viewModel.cancelPromotion() }
                )
            }
        }
    }

    // MARK: - Board

    private var board: some View {
        ChessBoardView(
            board: viewModel.currentPly?.board ?? [],
            lastMove: viewModel.currentPly?.lastMove,
            selected: viewModel.selectedSquare,
            legalTargets: viewModel.legalTargets,
            flipped: viewModel.flipped,
            onTapSquare: { viewModel.handleTap(on: $0) }
        )
    }

    // MARK: - Player bars

    private var whiteName: String { route.row.player1PlayedWhite ? route.player1Name : route.player2Name }
    private var blackName: String { route.row.player1PlayedWhite ? route.player2Name : route.player1Name }
    private var whiteRating: Int? { route.row.player1PlayedWhite ? route.row.player1Rating : route.row.player2Rating }
    private var blackRating: Int? { route.row.player1PlayedWhite ? route.row.player2Rating : route.row.player1Rating }

    private func playerBar(forWhite isWhite: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isWhite ? "circle" : "circle.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(isWhite ? whiteName : blackName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if let rating = isWhite ? whiteRating : blackRating {
                Text("\(rating)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Status / variation line

    @ViewBuilder
    private var statusLine: some View {
        if viewModel.isInVariation {
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(variationText)
                        .font(.caption.italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Button {
                    viewModel.backToGame()
                } label: {
                    Label("Back to game", systemImage: "arrow.uturn.backward")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        } else if viewModel.isAtEnd, let result = resultText {
            Text(result)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        } else if let failed = viewModel.failedAtMove {
            Label("Replay available up to move \((failed + 1) / 2)", systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }

    private var variationText: String {
        viewModel.variation.compactMap(\.san).joined(separator: " ")
    }

    private var resultText: String? {
        guard let label = route.row.resultLabel else { return nil }
        if let termination = route.row.terminationLabel {
            return "\(label) · \(termination)"
        }
        return label
    }

    // MARK: - Move list

    private var moveList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(36), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading),
                        GridItem(.flexible(), alignment: .leading)
                    ],
                    spacing: 2
                ) {
                    ForEach(1...max(1, (viewModel.plies.count - 1 + 1) / 2), id: \.self) { moveNumber in
                        Text("\(moveNumber).")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        moveCell(plyIndex: moveNumber * 2 - 1)
                        moveCell(plyIndex: moveNumber * 2)
                    }
                }
                .padding(8)
            }
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .onChange(of: viewModel.mainlineIndex) { _, newIndex in
                withAnimation {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func moveCell(plyIndex: Int) -> some View {
        if let ply = viewModel.plies[safe: plyIndex], let san = ply.san {
            let isCurrent = !viewModel.isInVariation && viewModel.mainlineIndex == plyIndex
            Text(san)
                .font(.subheadline.weight(isCurrent ? .bold : .regular).monospaced())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    isCurrent ? Color.accentColor.opacity(0.2) : Color.clear,
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .id(plyIndex)
                .onTapGesture { viewModel.jump(to: plyIndex) }
        } else {
            Text("")
        }
    }

    // MARK: - Controls

    private var controls: some View {
        HStack {
            controlButton("backward.end.fill", disabled: viewModel.isAtStart) { viewModel.toStart() }
            controlButton("chevron.backward", disabled: !viewModel.canGoBack) { viewModel.back() }
            Spacer()
            Button {
                viewModel.flipped.toggle()
            } label: {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .font(.title3)
            }
            Spacer()
            controlButton("chevron.forward", disabled: viewModel.isInVariation || viewModel.isAtEnd) { viewModel.forward() }
            controlButton("forward.end.fill", disabled: viewModel.isInVariation || viewModel.isAtEnd) { viewModel.toEnd() }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 4)
    }

    private func controlButton(_ systemImage: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3)
                .frame(width: 44, height: 36)
        }
        .disabled(disabled)
    }

    private var navigationTitle: String {
        "\(route.player1Name) – \(route.player2Name)"
    }
}

#Preview {
    NavigationStack {
        GameDetailView(
            route: GameDetailRoute(
                row: GameResultRow(
                    id: "preview1",
                    playedAt: Date(timeIntervalSince1970: 1_770_000_000),
                    player1RatingDiff: 5,
                    player2RatingDiff: -4,
                    resultLabel: "1-0",
                    outcome: .player1Win,
                    player1Rating: 2456,
                    player2Rating: 2511,
                    player1PlayedWhite: true,
                    terminationLabel: "Checkmate",
                    openingLabel: "C20 · King's Pawn Game: Wayward Queen Attack",
                    timeControlLabel: "3+2",
                    moveCount: 4,
                    rated: true,
                    movesSAN: "e4 e5 Qh5 Nc6 Bc4 Nf6 Qxf7#"
                ),
                player1Name: "PlayerA",
                player2Name: "PlayerB"
            )
        )
    }
}
