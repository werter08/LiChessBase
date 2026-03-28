//
//  CompareView.swift
//  Chess Base
//
//  Created by Begench Yangibayev on 23.03.2026.
//

import SwiftUI

struct CompareView: View {
    @StateObject private var viewModel = CompareViewModel()
    @FocusState private var focusedField: ComparePlayerField?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    CompareScreenHeader()
                    ComparePlayerInputSection(
                        viewModel: viewModel,
                        focusedField: $focusedField,
                        isFirstFocused: focusedField == .first,
                        isSecondFocused: focusedField == .second
                    )
                    PrimaryProminentButton(
                        title: "Compare",
                        systemImage: "arrow.left.arrow.right.circle.fill",
                        isLoading: viewModel.isLoading
                    ) {
                        focusedField = nil
                        viewModel.compareUsers()
                    }
                    if !viewModel.errorMessage.isEmpty {
                        ErrorBannerView(message: viewModel.errorMessage)
                    }
                    if let model = viewModel.model {
                        CompareResultsBlock(viewModel: viewModel, model: model)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Head-to-head")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: PerfTypeRoute.self) { route in
                GameTypeGamesListView(route: route)
            }
        }
        .environmentObject(viewModel)
    }
}

// MARK: - Screen sections (structs)

private enum ComparePlayerField: Hashable {
    case first, second
}

private struct CompareScreenHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Compare two players")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Overall record uses crosstable. All games load once, grouped by time control; tap a card for the game list.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ComparePlayerInputSection: View {
    @ObservedObject var viewModel: CompareViewModel
    var focusedField: FocusState<ComparePlayerField?>.Binding
    var isFirstFocused: Bool
    var isSecondFocused: Bool

    var body: some View {
        FormSectionCard {
            VStack(spacing: 16) {
                LabeledTextField(
                    title: "Player 1",
                    systemImage: "person.fill",
                    placeholder: "Lichess username",
                    text: $viewModel.firstUser,
                    isFocused: isFirstFocused,
                    focus: focusedField,
                    field: .first
                )
                VSOrnament()
                LabeledTextField(
                    title: "Player 2",
                    systemImage: "person.fill",
                    placeholder: "Lichess username",
                    text: $viewModel.secondUser,
                    isFocused: isSecondFocused,
                    focus: focusedField,
                    field: .second
                )
            }
        }
    }
}

private struct CompareResultsBlock: View {
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

#Preview {
    CompareView()
}
