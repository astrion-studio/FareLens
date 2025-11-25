// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation

protocol WatchlistRepositoryProtocol {
    func fetchWatchlists() async throws -> [Watchlist]
    func createWatchlist(_ watchlist: Watchlist) async throws -> Watchlist
    func updateWatchlist(_ watchlist: Watchlist) async throws -> Watchlist
    func deleteWatchlist(id: UUID) async throws
}

actor WatchlistRepository: WatchlistRepositoryProtocol {
    static let shared = WatchlistRepository()

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchWatchlists() async throws -> [Watchlist] {
        let endpoint = APIEndpoint.getWatchlists()
        // API returns bare array (not wrapped) to match single-item endpoint pattern
        return try await apiClient.request(endpoint)
    }

    func createWatchlist(_ watchlist: Watchlist) async throws -> Watchlist {
        let endpoint = APIEndpoint.createWatchlist(watchlist)
        return try await apiClient.request(endpoint)
    }

    func updateWatchlist(_ watchlist: Watchlist) async throws -> Watchlist {
        let endpoint = APIEndpoint.updateWatchlist(id: watchlist.id, watchlist: watchlist)
        return try await apiClient.request(endpoint)
    }

    func deleteWatchlist(id: UUID) async throws {
        let endpoint = APIEndpoint.deleteWatchlist(id: id)
        try await apiClient.requestNoResponse(endpoint)
    }
}
