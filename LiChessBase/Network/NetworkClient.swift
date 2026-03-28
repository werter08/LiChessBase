//
//  Network.swift
//  Academy
//
//  Created by Begench on 20.10.2025.
//

import Foundation
import Alamofire
import Combine

class Network {
    /// Seconds; avoids infinite loading if the host is unreachable or the server hangs.
    private static let requestTimeout: TimeInterval = 30

    class func perform<T: Decodable>(endpoint: Endpoint) -> AnyPublisher<T, APIError> {
        Future { promise in
            AF.request(
                endpoint.path,
                method: endpoint.method,
                parameters: endpoint.parameters,
                encoding: endpoint.encoder,
                headers: endpoint.header,
                requestModifier: { $0.timeoutInterval = requestTimeout }
            )
            .validate()
            .responseDecodable(of: T.self) { response in
                debugPrint(response)
                switch response.result {
                case .success(let data):
                    promise(.success(data))
                case .failure(let error):
                    if let data = response.data,
                       let message = String(data: data, encoding: .utf8), !message.isEmpty {
                        promise(.failure(APIError(message: message)))
                    } else {
                        let msg = error.localizedDescription
                        promise(.failure(APIError(message: msg.isEmpty ? "Request failed." : msg)))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }

    /// NDJSON games export (`Accept: application/x-ndjson`).
    class func performString(endpoint: Endpoint) -> AnyPublisher<String, APIError> {
        Future { promise in
            AF.request(
                endpoint.path,
                method: endpoint.method,
                parameters: endpoint.parameters,
                encoding: endpoint.encoder,
                headers: endpoint.header,
                requestModifier: { $0.timeoutInterval = requestTimeout }
            )
            .validate()
            .responseString { response in
                debugPrint(response)
                switch response.result {
                case .success(let text):
                    promise(.success(text))
                case .failure(let error):
                    if let data = response.data,
                       let message = String(data: data, encoding: .utf8), !message.isEmpty {
                        promise(.failure(APIError(message: message)))
                    } else {
                        let msg = error.localizedDescription
                        promise(.failure(APIError(message: msg.isEmpty ? "Request failed." : msg)))
                    }
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

struct APIError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
