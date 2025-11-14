// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let email: String
    let createdAt: Date
    var timezone: String
    var subscriptionTier: SubscriptionTier
    var alertPreferences: AlertPreferences
    var preferredAirports: [PreferredAirport]
    var watchlists: [Watchlist]

    var isProUser: Bool {
        subscriptionTier == .pro
    }

    var maxWatchlists: Int {
        isProUser ? Int.max : 5
    }

    var maxAlertsPerDay: Int {
        isProUser ? 6 : 3
    }

    var maxPreferredAirports: Int {
        isProUser ? 3 : 1
    }
}

enum SubscriptionTier: String, Codable {
    case free
    case pro

    var displayName: String {
        switch self {
        case .free: "Free"
        case .pro: "Pro"
        }
    }
}

struct AlertPreferences: Codable {
    var alertEnabled: Bool // Matches database: alert_enabled → alertEnabled via snake_case conversion
    var quietHoursEnabled: Bool // Matches database: quiet_hours_enabled
    var quietHoursStart: Int // Hour (0-23) - Matches database: quiet_hours_start
    var quietHoursEnd: Int // Hour (0-23) - Matches database: quiet_hours_end
    var watchlistOnlyMode: Bool // Pro only - Matches database: watchlist_only_mode

    static let `default` = AlertPreferences(
        alertEnabled: true,
        quietHoursEnabled: true,
        quietHoursStart: 22, // 10pm
        quietHoursEnd: 7, // 7am
        watchlistOnlyMode: false
    )

    func isQuietHour(at date: Date, timezone: TimeZone) -> Bool {
        guard quietHoursEnabled else { return false }

        var calendar = Calendar.current
        calendar.timeZone = timezone
        let hour = calendar.component(.hour, from: date)

        if quietHoursStart < quietHoursEnd {
            return hour >= quietHoursStart && hour < quietHoursEnd
        } else {
            // Spans midnight
            return hour >= quietHoursStart || hour < quietHoursEnd
        }
    }
}

struct PreferredAirport: Codable, Identifiable {
    let id: UUID
    let iata: String
    var weight: Double // 0.0-1.0, must sum to 1.0 for all airports

    init(id: UUID = UUID(), iata: String, weight: Double) {
        self.id = id
        self.iata = iata
        self.weight = weight
    }
}

extension [PreferredAirport] {
    var totalWeight: Double {
        reduce(0) { $0 + $1.weight }
    }

    var isValidWeightSum: Bool {
        abs(totalWeight - 1.0) < 0.001 // Allow small floating point errors
    }
}
