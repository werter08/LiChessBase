//
//  LichessPerfFlair.swift
//  LiChessBase
//
//  Flair artwork from Lichess lila (official WebP): https://github.com/lichess-org/lila/tree/master/public/flair/img
//  Bundled as SVG in Assets for sharp scaling; see Resources/LichessFlair/LICENSE.txt — AGPL-3.0 (same as lila).
//

import SwiftUI

/// Maps API `perf` / `perfType` keys to bundled Asset Catalog names (`LichessFlair*`).
enum LichessPerfFlair {

    static func assetCatalogName(forPerfTypeKey key: String) -> String? {
        let k = key.lowercased()
        switch k {
        case "bullet":
            return "LichessFlairBullet"
        case "blitz":
            return "LichessFlairBlitz"
        case "rapid":
            return "LichessFlairRapid"
        case "classical":
            return "LichessFlairClassical"
        case "correspondence":
            return "LichessFlairCorrespondence"
        case "ultrabullet":
            return "LichessFlairUltraBullet"
        case "chess960", "960":
            return "LichessFlairChess960"
        default:
            return nil
        }
    }
}

struct PerfTypeFlairImage: View {
    let perfTypeKey: String
    var size: CGFloat = 36

    var body: some View {
        Group {
            if let name = LichessPerfFlair.assetCatalogName(forPerfTypeKey: perfTypeKey) {
                Image(name)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.system(size: size * 0.55))
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}
