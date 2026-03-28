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
                        CompareResultsBlockView(viewModel: viewModel, model: model)
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



#Preview {
    CompareView()
}
