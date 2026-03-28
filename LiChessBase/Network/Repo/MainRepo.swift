//
//  MainRepo.swift
//  Academy
//
//  Created by Begench Yangibayev on 23.10.2025.
//

import Foundation
import Combine

class MainRepo {
    func compare(firsstUserId: String, seconUserId: String) -> AnyPublisher<CompareModel, APIError> {
        Network.perform(endpoint: Endpoints.compareTwoUserGames(firstUserId: firsstUserId, secondUserId: seconUserId))
    }

    /// All games between two players (no `perfType`) — group and count in the app ([docs](https://lichess.org/api#tag/Games/operation/apiGamesUser)).
    func exportAllGamesBetween(
        primaryUsername: String,
        opponentUsername: String,
        maxGames: Int = 300
    ) -> AnyPublisher<String, APIError> {
        Network.performString(
            endpoint: Endpoints.gamesExport(
                username: primaryUsername,
                vs: opponentUsername,
                perfType: nil,
                maxGames: maxGames
            )
        )
    }
}
