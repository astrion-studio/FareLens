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
        struct WatchlistsResponse: Codable {
            let watchlists: [Watchlist]
        }

        let endpoint = APIEndpoint.getWatchlists()
        let response: WatchlistsResponse = try await apiClient.request(endpoint)
        return response.watchlists
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
