import Foundation

struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let queryItems: [URLQueryItem]?
    let body: [String: Any]?

    init(
        path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem]? = nil,
        body: [String: Any]? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
    }
}

// MARK: - Endpoints (from API.md)

extension APIEndpoint {
    // MARK: - Deals

    static func getDeals(origin: String?, limit: Int = 20) -> APIEndpoint {
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "limit", value: "\(limit)")
        ]
        if let origin = origin {
            queryItems.append(URLQueryItem(name: "origin", value: origin))
        }
        return APIEndpoint(
            path: "/deals",
            method: .get,
            queryItems: queryItems
        )
    }

    static func getDealDetail(dealId: String) -> APIEndpoint {
        APIEndpoint(
            path: "/deals/\(dealId)",
            method: .get
        )
    }

    // MARK: - Watchlists

    static func getWatchlists() -> APIEndpoint {
        APIEndpoint(
            path: "/watchlists",
            method: .get
        )
    }

    static func createWatchlist(_ watchlist: Watchlist) -> APIEndpoint {
        APIEndpoint(
            path: "/watchlists",
            method: .post,
            body: [
                "name": watchlist.name,
                "origin": watchlist.origin,
                "destination": watchlist.destination,
                "date_range": watchlist.dateRange.map { ["start": $0.start, "end": $0.end] } as Any,
                "max_price": watchlist.maxPrice as Any
            ]
        )
    }

    static func updateWatchlist(id: UUID, watchlist: Watchlist) -> APIEndpoint {
        APIEndpoint(
            path: "/watchlists/\(id.uuidString)",
            method: .put,
            body: [
                "name": watchlist.name,
                "origin": watchlist.origin,
                "destination": watchlist.destination,
                "date_range": watchlist.dateRange.map { ["start": $0.start, "end": $0.end] } as Any,
                "max_price": watchlist.maxPrice as Any,
                "is_active": watchlist.isActive
            ]
        )
    }

    static func deleteWatchlist(id: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/watchlists/\(id.uuidString)",
            method: .delete
        )
    }

    // MARK: - Alert Preferences

    static func getAlertPreferences() -> APIEndpoint {
        APIEndpoint(
            path: "/alert-preferences",
            method: .get
        )
    }

    static func updateAlertPreferences(_ preferences: AlertPreferences) -> APIEndpoint {
        APIEndpoint(
            path: "/alert-preferences",
            method: .put,
            body: [
                "enabled": preferences.enabled,
                "quiet_hours_enabled": preferences.quietHoursEnabled,
                "quiet_hours_start": preferences.quietHoursStart,
                "quiet_hours_end": preferences.quietHoursEnd,
                "watchlist_only_mode": preferences.watchlistOnlyMode
            ]
        )
    }

    static func updatePreferredAirports(_ airports: [PreferredAirport]) -> APIEndpoint {
        APIEndpoint(
            path: "/alert-preferences/airports",
            method: .put,
            body: [
                "preferred_airports": airports.map { airport in
                    [
                        "iata": airport.iata,
                        "weight": airport.weight
                    ]
                }
            ]
        )
    }

    // MARK: - User

    static func updateUser(_ user: User) -> APIEndpoint {
        APIEndpoint(
            path: "/user",
            method: .patch,
            body: [
                "timezone": user.timezone
            ]
        )
    }

    static func registerAPNsToken(_ token: String) -> APIEndpoint {
        APIEndpoint(
            path: "/user/apns-token",
            method: .post,
            body: [
                "token": token,
                "platform": "ios"
            ]
        )
    }

    // MARK: - Background Refresh

    static func checkForNewDeals() -> APIEndpoint {
        APIEndpoint(
            path: "/background-refresh",
            method: .get
        )
    }
}
