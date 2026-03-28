//
//  CompareResultsBlock.swift
//  Chess Base
//
//  Created by Begench Yangibayev on 28.03.2026.
//


import SwiftUI

struct CompareResultsBlockView: View {
    @ObservedObject var viewModel: CompareViewModel
    let model: CompareModel

    private var player1Name: String { viewModel.firstUser.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var player2Name: String { viewModel.secondUser.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var mainResult: HeadToHeadMainResult {
        let p1 = player1Name.isEmpty ? "Player 1" : player1Name
        let p2 = player2Name.isEmpty ? "Player 2" : player2Name
        let w1 = model.wins(for: player1Name) ?? 0
        let w2 = model.wins(for: player2Name) ?? 0
        return HeadToHeadMainResult(
            player1Title: p1,
            player2Title: p2,
            player1Wins: w1,
            player2Wins: w2,
            totalGames: model.nbGames
        )
    }

    private var displayP1: String { player1Name.isEmpty ? "Player 1" : player1Name }
    private var displayP2: String { player2Name.isEmpty ? "Player 2" : player2Name }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HeadToHeadMainResultCard(result: mainResult)

            if viewModel.isLoadingGamesExport {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Loading games…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if let msg = viewModel.gamesExportError, viewModel.perfGroups.isEmpty {
                ErrorBannerView(message: msg)
            }

            if !viewModel.perfGroups.isEmpty {
                PerfTypeCarousel(
                    groups: viewModel.perfGroups,
                    player1Name: displayP1,
                    player2Name: displayP2
                )
            }
        }
    }
}
