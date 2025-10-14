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

    var displayDestination: String {
        destination == "ANY" ? "Anywhere" : destination
    }

    var displayDateRange: String? {
        guard let dateRange = dateRange else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(formatter.string(from: dateRange.start)) - \(formatter.string(from: dateRange.end))"
    }

    var displayMaxPrice: String? {
        guard let maxPrice = maxPrice else { return nil }
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
