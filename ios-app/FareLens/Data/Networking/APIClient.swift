// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation

protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T
    func requestNoResponse(_ endpoint: APIEndpoint) async throws
}

actor APIClient: APIClientProtocol {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    private var authToken: String?

    init(session: URLSession = .shared) {
        self.session = session
        // Use Cloudflare Worker URL from configuration
        self.baseURL = Config.cloudflareWorkerURL
    }

    func setAuthToken(_ token: String?) {
        authToken = token
    }

    /// Make API request with response
    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        let urlRequest = try buildRequest(endpoint)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Parse error responses for better context
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error JSON for detailed message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Make API request without response
    func requestNoResponse(_ endpoint: APIEndpoint) async throws {
        let urlRequest = try buildRequest(endpoint)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Parse error responses for better context
        guard (200...299).contains(httpResponse.statusCode) else {
            // Try to parse error JSON for detailed message
            if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw APIError.serverError(errorResponse.error)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Error Response

    private struct ErrorResponse: Decodable {
        let error: String
    }

    // MARK: - Private Methods

    private func buildRequest(_ endpoint: APIEndpoint) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if let queryItems = endpoint.queryItems {
            components?.queryItems = queryItems
        }

        guard let finalURL = components?.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body if present
        if let body = endpoint.body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        return request
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)
    case unauthorized
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid URL"
        case .invalidResponse:
            "Invalid response from server"
        case let .httpError(code):
            "HTTP error: \(code)"
        case let .decodingError(error):
            "Failed to decode response: \(error.localizedDescription)"
        case .unauthorized:
            "Unauthorized"
        case let .serverError(message):
            "Server error: \(message)"
        }
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
