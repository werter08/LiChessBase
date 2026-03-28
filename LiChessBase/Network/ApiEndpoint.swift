//
//  Endpoint.swift
//  Academy
//
//  Created by Begench on 20.10.2025.
//

import Alamofire
import Foundation

protocol Endpoint {
    var method: Alamofire.HTTPMethod { get }
    var path: String { get }
    var encoder: ParameterEncoding { get }
    var header: HTTPHeaders { get }
    var parameters: Parameters? { get }
}

private let LICHESS_API_BASE = "https://lichess.org"

enum Endpoints: Endpoint {

    /// [`GET /api/crosstable/{user1}/{user2}`](https://lichess.org/api#tag/users/GET/api/crosstable/{user1}/{user2})
    case compareTwoUserGames(firstUserId: String, secondUserId: String)

    /// [`GET /api/games/user/{username}`](https://lichess.org/api#tag/Games/operation/apiGamesUser) — NDJSON. Omit `perfType` to fetch all speeds (then group client-side).
    case gamesExport(username: String, vs: String, perfType: String?, maxGames: Int)

    var method: Alamofire.HTTPMethod { .get }

    var path: String {
        switch self {
        case let .compareTwoUserGames(firstUserId, secondUserId):
            let a = Self.pathSegment(firstUserId)
            let b = Self.pathSegment(secondUserId)
            return "\(LICHESS_API_BASE)/api/crosstable/\(a)/\(b)"
        case let .gamesExport(username, _, _, _):
            let u = Self.pathSegment(username)
            return "\(LICHESS_API_BASE)/api/games/user/\(u)"
        }
    }

    var encoder: any Alamofire.ParameterEncoding {
        switch self {
        case .compareTwoUserGames:
            return URLEncoding.default
        case .gamesExport:
            return URLEncoding(destination: .queryString, arrayEncoding: .noBrackets, boolEncoding: .literal)
        }
    }

    var header: Alamofire.HTTPHeaders {
        switch self {
        case .compareTwoUserGames:
            return [
                "Accept": "application/json",
                "User-Agent": Self.userAgent
            ]
        case .gamesExport:
            return [
                "Accept": "application/x-ndjson",
                "User-Agent": Self.userAgent
            ]
        }
    }

    var parameters: Parameters? {
        switch self {
        case .compareTwoUserGames:
            return nil
        case let .gamesExport(_, vs, perfType, maxGames):
            var p: Parameters = [
                "vs": vs.trimmingCharacters(in: .whitespacesAndNewlines),
                "max": "\(maxGames)"
            ]
            if let perf = perfType {
                p["perfType"] = perf
            }
            return p
        }
    }

    private static let userAgent = "ChessBase/1.0 (iOS; https://lichess.org/api#description/clients)"

    private static func pathSegment(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? raw
    }
}

// Custom ParameterEncoder to handle "include[]" correctly
struct CustomURLEncoding: ParameterEncoding {

    static let `default` = CustomURLEncoding()

    func encode(
        _ urlRequest: any Alamofire.URLRequestConvertible,
        with parameters: Alamofire.Parameters?
    ) throws -> URLRequest {
        var urlRequest = try urlRequest.asURLRequest()

        guard let parameters = parameters else { return urlRequest }

        var components = URLComponents(url: urlRequest.url!, resolvingAgainstBaseURL: false)!

        var queryItems = components.queryItems ?? []

        if parameters is [String: Any] && !parameters.isEmpty {
            for (key, value) in parameters as! [String: Any] {
                if let arrayValue = value as? [String] {
                    for item in arrayValue {
                        queryItems.append(URLQueryItem(name: "\(key)[]", value: item))
                    }
                } else {
                    queryItems.append(URLQueryItem(name: key, value: "\(value)"))
                }
            }
        }

        components.queryItems = queryItems
        urlRequest.url = components.url

        return urlRequest
    }
}
