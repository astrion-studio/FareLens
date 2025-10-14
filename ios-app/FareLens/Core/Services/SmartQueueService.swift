import Foundation

protocol SmartQueueServiceProtocol {
    func rankDeals(_ deals: [FlightDeal], for user: User) async -> [RankedDeal]
    func calculateQueueScore(deal: FlightDeal, user: User) async -> Double
}

actor SmartQueueService: SmartQueueServiceProtocol {
    static let shared = SmartQueueService()

    /// Rank deals using smart queue algorithm
    /// Formula: finalScore = dealScore × (1 + watchlistBoost) × (1 + airportWeight)
    /// Tiebreaker: price ASC, then departureDate ASC
    func rankDeals(_ deals: [FlightDeal], for user: User) async -> [RankedDeal] {
        var rankedDeals: [RankedDeal] = []

        // Calculate queue score for each deal
        for deal in deals {
            let score = await calculateQueueScore(deal: deal, user: user)
            rankedDeals.append(RankedDeal(deal: deal, queueScore: score))
        }

        // Sort by queue score (highest first), then by tiebreaker rules
        return rankedDeals.sorted { a, b in
            if abs(a.queueScore - b.queueScore) < 0.001 { // Same score (accounting for floating point)
                if abs(a.totalPrice - b.totalPrice) < 0.01 { // Same price
                    return a.departureDate < b.departureDate // Soonest departure first
                }
                return a.totalPrice < b.totalPrice // Lower price first
            }
            return a.queueScore > b.queueScore // Higher score first
        }
    }

    /// Calculate smart queue score for a deal
    /// Formula: finalScore = dealScore × (1 + watchlistBoost) × (1 + airportWeight)
    func calculateQueueScore(deal: FlightDeal, user: User) async -> Double {
        var score = Double(deal.dealScore) // Base: 0-100

        // 1. Watchlist boost: +20% if deal matches user's watchlist
        let watchlistBoost: Double = user.watchlists.contains(where: { $0.matches(deal) }) ? 0.2 : 0.0

        // 2. Airport weight: Apply user's preferred airport weight
        var airportWeight: Double = 0.0
        if let airport = user.preferredAirports.first(where: { $0.iata == deal.origin }) {
            airportWeight = airport.weight // 0.0-1.0
        }

        // 3. Final score formula
        let finalScore = score * (1.0 + watchlistBoost) * (1.0 + airportWeight)
        return finalScore
    }
}

// MARK: - Examples (from ARCHITECTURE.md)

extension SmartQueueService {
    /// Example 1: Watchlist Priority
    /// Deal: LAX→NYC, $450, DealScore 85
    /// User has watchlist: LAX→NYC, preferred airport LAX (weight 0.6)
    /// Calculation: 85 × (1 + 0.2) × (1 + 0.6) = 85 × 1.2 × 1.6 = 163.2
    static func example1() -> Double {
        let dealScore: Double = 85
        let watchlistBoost: Double = 0.2 // Matches watchlist
        let airportWeight: Double = 0.6 // LAX is preferred
        return dealScore * (1.0 + watchlistBoost) * (1.0 + airportWeight) // 163.2
    }

    /// Example 2: No Watchlist Match
    /// Deal: SFO→London, $380, DealScore 90
    /// User has watchlist: LAX→NYC (doesn't match), no SFO in preferred airports
    /// Calculation: 90 × (1 + 0) × (1 + 0) = 90
    static func example2() -> Double {
        let dealScore: Double = 90
        let watchlistBoost: Double = 0.0 // No match
        let airportWeight: Double = 0.0 // Not preferred
        return dealScore * (1.0 + watchlistBoost) * (1.0 + airportWeight) // 90.0
    }

    /// Example 3: Tiebreaker
    /// Deal A: LAX→Tokyo, $550, DealScore 85, finalScore 163.2
    /// Deal B: LAX→Paris, $480, DealScore 85, finalScore 163.2
    /// Tiebreaker: Deal B wins (lower price: $480 < $550)
    static func example3Tiebreaker() -> String {
        "Deal A: $550 (163.2), Deal B: $480 (163.2) → Deal B wins (lower price)"
    }
}
