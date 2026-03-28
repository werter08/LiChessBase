//
//  CompareModel.swift
//  Chess Base
//
//  Created by Begench Yangibayev on 23.03.2026.
//

import Foundation

/// Decodes Lichess [`GET /api/crosstable/{user1}/{user2}`](https://lichess.org/api#tag/users/GET/api/crosstable/{user1}/{user2}) JSON.
struct CompareModel: Decodable {

    /// Head-to-head win counts keyed by **lowercase** Lichess usernames.
    let users: [String: Float]
    let nbGames: Int

    /// Resolves wins for what the user typed; Lichess returns lowercase keys.
    func wins(for username: String) -> Float? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let v = users[trimmed] { return v }
        let lower = trimmed.lowercased()
        return users.first { $0.key.lowercased() == lower }?.value
    }
}
