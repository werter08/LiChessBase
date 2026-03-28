//
//  LichessSpeed.swift
//  Chess Base
//

import Foundation

/// Lichess `speed` / `perf` labels from game exports.
enum LichessSpeed: String, CaseIterable, Identifiable {
    case ultraBullet = "ultrabullet"
    case bullet = "bullet"
    case blitz = "blitz"
    case rapid = "rapid"
    case classical = "classical"
    case correspondence = "correspondence"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ultraBullet: return "UltraBullet"
        case .bullet: return "Bullet"
        case .blitz: return "Blitz"
        case .rapid: return "Rapid"
        case .classical: return "Classical"
        case .correspondence: return "Correspondence"
        }
    }

    static func title(forSpeedKey key: String) -> String {
        if let known = LichessSpeed(rawValue: key.lowercased()) {
            return known.title
        }
        return key.capitalized
    }

    /// Sort order for horizontal lists (fast → slow).
    static let displayOrder: [LichessSpeed] = allCases

    /// `perfType` query value for [`GET /api/games/user/{username}`](https://lichess.org/api#tag/Games/operation/apiGamesUser).
    var perfTypeQueryValue: String {
        switch self {
        case .ultraBullet: return "ultraBullet"
        case .bullet, .blitz, .rapid, .classical, .correspondence:
            return rawValue
        }
    }

    /// Normalizes JSON `perf` / `speed` values (same namespace as API query `perfType`).
    static func normalizePerfTypeKey(_ api: String) -> String {
        let t = api.trimmingCharacters(in: .whitespacesAndNewlines)
        if t == "ultraBullet" || t.lowercased() == "ultrabullet" {
            return LichessSpeed.ultraBullet.rawValue
        }
        return t.lowercased()
    }
}
