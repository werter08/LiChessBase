//
//  COmpareViewModel.swift
//  Chess Base
//
//  Created by Begench Yangibayev on 23.03.2026.
//

import Foundation
import Combine
import Resolver

final class CompareViewModel: ObservableObject {
    @Injected var repo: MainRepo
    private var cancellables = Set<AnyCancellable>()

    @Published var firstUser = ""
    @Published var secondUser = ""

    @Published var isLoading = false
    @Published var isLoadingGamesExport = false
    @Published var errorMessage = ""
    @Published var gamesExportError: String?

    @Published var model: CompareModel?
    /// One export, grouped by `speed` with manual win/total counts per type.
    @Published var perfGroups: [PerfTypeGroupModel] = []

    func compareUsers() {
        guard !isLoading else { return }
        let u1 = firstUser.trimmingCharacters(in: .whitespacesAndNewlines)
        let u2 = secondUser.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !u1.isEmpty, !u2.isEmpty else {
            errorMessage = "Enter both Lichess usernames."
            return
        }
        errorMessage = ""
        gamesExportError = nil
        model = nil
        perfGroups = []
        isLoading = true

        repo.compare(firsstUserId: u1, seconUserId: u2)
            .receive(on: DispatchQueue.main)
            .sink { completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self.errorMessage = error.errorDescription ?? "Something went wrong."
                    self.isLoading = false
                }
            } receiveValue: { model in
                self.model = model
                self.errorMessage = ""
                self.isLoading = false
                self.loadGamesExport(u1: u1, u2: u2)
            }
            .store(in: &cancellables)
    }

    private func loadGamesExport(u1: String, u2: String) {
        isLoadingGamesExport = true
        gamesExportError = nil
        perfGroups = []

        repo.exportAllGamesBetween(primaryUsername: u1, opponentUsername: u2, maxGames: 300)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingGamesExport = false
                    if case .failure(let err) = completion {
                        self?.gamesExportError = err.errorDescription
                    }
                },
                receiveValue: { [weak self] ndjson in
                    guard let self else { return }
                    self.perfGroups = LichessGamesExportParser.groupedByPerfType(
                        ndjson: ndjson,
                        player1Id: u1,
                        player2Id: u2,
                        player1Display: u1,
                        player2Display: u2
                    )
                }
            )
            .store(in: &cancellables)
    }

    func games(for perfTypeKey: String) -> [GameResultRow] {
        perfGroups.first { $0.perfTypeKey == perfTypeKey }?.games ?? []
    }

    func displayTitle(for perfTypeKey: String) -> String {
        perfGroups.first { $0.perfTypeKey == perfTypeKey }?.title ?? LichessSpeed.title(forSpeedKey: perfTypeKey)
    }
}
