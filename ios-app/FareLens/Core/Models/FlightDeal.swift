import Foundation

struct FlightDeal: Codable, Identifiable {
    let id: UUID
    let origin: String // IATA code
    let destination: String // IATA code
    let departureDate: Date
    let returnDate: Date
    let totalPrice: Double
    let currency: String
    let dealScore: Int // 0-100
    let discountPercent: Int
    let normalPrice: Double
    let createdAt: Date
    let expiresAt: Date
    let airline: String
    let stops: Int
    let returnStops: Int?
    let deepLink: String

    var tripLength: Int {
        Calendar.current.dateComponents([.day], from: departureDate, to: returnDate).day ?? 0
    }

    var isExpired: Bool {
        Date() > expiresAt
    }

    var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: totalPrice)) ?? "\(currency) \(totalPrice)"
    }

    var dealScoreColor: String {
        switch dealScore {
        case 90...100: return "excellent" // DealScore.excellent
        case 80..<90: return "great" // DealScore.great
        case 70..<80: return "good" // DealScore.good
        default: return "fair" // DealScore.fair
        }
    }

    func matches(_ watchlist: Watchlist) -> Bool {
        // Check if deal matches watchlist criteria
        guard origin == watchlist.origin else { return false }

        // Match destination (wildcard "ANY" matches all)
        if watchlist.destination != "ANY" && destination != watchlist.destination {
            return false
        }

        // Match date range if specified
        if let dateRange = watchlist.dateRange {
            guard departureDate >= dateRange.start && departureDate <= dateRange.end else {
                return false
            }
        }

        // Match max price if specified
        if let maxPrice = watchlist.maxPrice {
            guard totalPrice <= maxPrice else {
                return false
            }
        }

        return true
    }
}

struct DealScore {
    static let excellent = 90...100
    static let great = 80..<90
    static let good = 70..<80
    static let fair = 0..<70
}
