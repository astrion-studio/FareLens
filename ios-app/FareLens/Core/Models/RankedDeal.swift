import Foundation

/// A flight deal with its calculated queue score for prioritization
struct RankedDeal {
    let deal: FlightDeal
    let queueScore: Double

    // Convenience accessors
    var id: UUID { deal.id }
    var dealScore: Int { deal.dealScore }
    var totalPrice: Double { deal.totalPrice }
    var departureDate: Date { deal.departureDate }
}
