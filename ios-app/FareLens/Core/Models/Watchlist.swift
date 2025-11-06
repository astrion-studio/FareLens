// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation

struct Watchlist: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let origin: String // IATA code
    let destination: String // IATA code or "ANY"
    var dateRange: DateRange?
    var maxPrice: Double?
    let createdAt: Date
    var isActive: Bool

    // Custom CodingKeys to map database fields (snake_case) to Swift properties (camelCase)
    // Raw values match actual JSON keys from API (not converted by convertFromSnakeCase)
    private enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case origin
        case destination
        case dateRangeStart = "date_range_start"
        case dateRangeEnd = "date_range_end"
        case maxPrice = "max_price"
        case createdAt = "created_at"
        case isActive = "is_active"
    }

    init(
        id: UUID = UUID(),
        userId: UUID,
        name: String,
        origin: String,
        destination: String,
        dateRange: DateRange? = nil,
        maxPrice: Double? = nil,
        createdAt: Date = Date(),
        isActive: Bool = true
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.origin = origin
        self.destination = destination
        self.dateRange = dateRange
        self.maxPrice = maxPrice
        self.createdAt = createdAt
        self.isActive = isActive
    }

    // Custom decoder to convert date_range_start/end into DateRange
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        origin = try container.decode(String.self, forKey: .origin)
        destination = try container.decode(String.self, forKey: .destination)
        maxPrice = try container.decodeIfPresent(Double.self, forKey: .maxPrice)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        isActive = try container.decode(Bool.self, forKey: .isActive)

        // Combine dateRangeStart and dateRangeEnd into DateRange
        if let start = try container.decodeIfPresent(Date.self, forKey: .dateRangeStart),
           let end = try container.decodeIfPresent(Date.self, forKey: .dateRangeEnd)
        {
            dateRange = DateRange(start: start, end: end)
        } else {
            dateRange = nil
        }
    }

    // Custom encoder to split DateRange into date_range_start/end
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(name, forKey: .name)
        try container.encode(origin, forKey: .origin)
        try container.encode(destination, forKey: .destination)
        try container.encodeIfPresent(maxPrice, forKey: .maxPrice)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(isActive, forKey: .isActive)

        // Split DateRange into dateRangeStart and dateRangeEnd
        if let dateRange {
            try container.encode(dateRange.start, forKey: .dateRangeStart)
            try container.encode(dateRange.end, forKey: .dateRangeEnd)
        }
    }

    var displayDestination: String {
        destination == "ANY" ? "Anywhere" : destination
    }

    var displayDateRange: String? {
        guard let dateRange else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end))"
    }

    var displayMaxPrice: String? {
        guard let maxPrice else { return nil }
        return "Up to $\(Int(maxPrice))"
    }

    func matches(_ deal: FlightDeal) -> Bool {
        deal.matches(self)
    }
}

struct DateRange: Codable {
    let start: Date
    let end: Date

    var isValid: Bool {
        end >= start
    }

    func contains(_ date: Date) -> Bool {
        date >= start && date <= end
    }
}

extension Watchlist {
    static func preview(
        name: String = "LAX to NYC",
        origin: String = "LAX",
        destination: String = "JFK"
    ) -> Watchlist {
        Watchlist(
            userId: UUID(),
            name: name,
            origin: origin,
            destination: destination
        )
    }
}
