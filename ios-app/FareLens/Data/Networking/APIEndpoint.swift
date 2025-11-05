// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

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
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        if let origin {
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
        let iso8601 = ISO8601DateFormatter()

        var body: [String: Any] = [
            "name": watchlist.name,
            "origin": watchlist.origin,
            "destination": watchlist.destination,
        ]

        // Flatten date range to match Supabase schema
        if let dateRange = watchlist.dateRange {
            body["date_range_start"] = iso8601.string(from: dateRange.start)
            body["date_range_end"] = iso8601.string(from: dateRange.end)
        }

        if let maxPrice = watchlist.maxPrice {
            body["max_price"] = maxPrice
        }

        return APIEndpoint(
            path: "/watchlists",
            method: .post,
            body: body
        )
    }

    static func updateWatchlist(id: UUID, watchlist: Watchlist) -> APIEndpoint {
        let iso8601 = ISO8601DateFormatter()

        var body: [String: Any] = [
            "name": watchlist.name,
            "origin": watchlist.origin,
            "destination": watchlist.destination,
            "is_active": watchlist.isActive,
        ]

        // Flatten date range to match Supabase schema
        if let dateRange = watchlist.dateRange {
            body["date_range_start"] = iso8601.string(from: dateRange.start)
            body["date_range_end"] = iso8601.string(from: dateRange.end)
        }

        if let maxPrice = watchlist.maxPrice {
            body["max_price"] = maxPrice
        }

        return APIEndpoint(
            path: "/watchlists/\(id.uuidString)",
            method: .put,
            body: body
        )
    }

    static func deleteWatchlist(id: UUID) -> APIEndpoint {
        APIEndpoint(
            path: "/watchlists/\(id.uuidString)",
            method: .delete
        )
    }

    // MARK: - User Settings (consolidated endpoint)

    static func getUser() -> APIEndpoint {
        APIEndpoint(
            path: "/user",
            method: .get
        )
    }

    static func updateUser(
        alertEnabled: Bool? = nil,
        quietHoursEnabled: Bool? = nil,
        quietHoursStart: Int? = nil,
        quietHoursEnd: Int? = nil,
        watchlistOnlyMode: Bool? = nil,
        preferredAirports: [PreferredAirport]? = nil,
        timezone: String? = nil
    ) -> APIEndpoint {
        var body: [String: Any] = [:]

        // Alert preferences (match Worker schema with snake_case keys)
        if let alertEnabled { body["alert_enabled"] = alertEnabled }
        if let quietHoursEnabled { body["quiet_hours_enabled"] = quietHoursEnabled }
        if let quietHoursStart { body["quiet_hours_start"] = quietHoursStart }
        if let quietHoursEnd { body["quiet_hours_end"] = quietHoursEnd }
        if let watchlistOnlyMode { body["watchlist_only_mode"] = watchlistOnlyMode }

        // Preferred airports (JSONB array in users table)
        if let airports = preferredAirports {
            body["preferred_airports"] = airports.map { airport in
                [
                    "iata": airport.iata,
                    "weight": airport.weight,
                ]
            }
        }

        // User profile
        if let timezone { body["timezone"] = timezone }

        return APIEndpoint(
            path: "/user",
            method: .patch,
            body: body
        )
    }

    static func getAlertHistory(page: Int = 1, perPage: Int = 50) -> APIEndpoint {
        APIEndpoint(
            path: "/alerts/history",
            method: .get,
            queryItems: [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "per_page", value: "\(perPage)"),
            ]
        )
    }

    static func registerAPNsToken(_ token: String) -> APIEndpoint {
        APIEndpoint(
            path: "/user/apns-token",
            method: .post,
            body: [
                "token": token,
                "platform": "ios",
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
