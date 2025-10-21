// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation

protocol DealsRepositoryProtocol {
    func fetchDeals(origin: String?, forceRefresh: Bool) async throws -> [FlightDeal]
    func fetchDealDetail(dealId: String) async throws -> FlightDeal
    func applySmartQueue(_ deals: [FlightDeal], for user: User) async -> [FlightDeal]
}

actor DealsRepository: DealsRepositoryProtocol {
    static let shared = DealsRepository()

    private let apiClient: APIClient
    private let persistenceService: PersistenceService
    private let smartQueueService: SmartQueueService

    init(
        apiClient: APIClient = .shared,
        persistenceService: PersistenceService = .shared,
        smartQueueService: SmartQueueService = .shared
    ) {
        self.apiClient = apiClient
        self.persistenceService = persistenceService
        self.smartQueueService = smartQueueService
    }

    /// Fetch deals with optional origin filter
    /// Implements 5-minute cache TTL per ARCHITECTURE.md line 335
    func fetchDeals(origin: String? = nil, forceRefresh: Bool = false) async throws -> [FlightDeal] {
        // Check cache if not forcing refresh
        if !forceRefresh, await persistenceService.isCacheValid() {
            let cachedDeals = await persistenceService.loadDeals()
            if !cachedDeals.isEmpty {
                return filterByOrigin(cachedDeals, origin: origin)
            }
        }

        // Fetch from API
        struct DealsResponse: Codable {
            let deals: [FlightDeal]
        }

        let endpoint = APIEndpoint.getDeals(origin: origin)
        let response: DealsResponse = try await apiClient.request(endpoint)

        // Cache full unfiltered response to avoid cross-origin pollution
        // Per Codex P1 feedback: filtering before cache causes wrong results
        // when switching between origins within TTL window
        await persistenceService.saveDeals(response.deals)

        // Filter deals by origin after caching
        return filterByOrigin(response.deals, origin: origin)
    }

    /// Fetch single deal detail
    func fetchDealDetail(dealId: String) async throws -> FlightDeal {
        let endpoint = APIEndpoint.getDealDetail(dealId: dealId)
        return try await apiClient.request(endpoint)
    }

    /// Apply smart queue ranking to deals
    /// Implements 20-deal algorithm: show all ≥80, remove lowest if >20, backfill ≥70 if <20
    func applySmartQueue(_ deals: [FlightDeal], for user: User) async -> [FlightDeal] {
        // Rank deals using smart queue algorithm
        let rankedDeals = await smartQueueService.rankDeals(deals, for: user)

        // Apply 20-deal algorithm for Free tier
        if !user.isProUser {
            return apply20DealAlgorithm(rankedDeals)
        }

        // Pro users see all deals (extract FlightDeal from RankedDeal)
        return rankedDeals.map(\.deal)
    }

    // MARK: - Private Methods

    /// Apply 20-deal algorithm (from PRD.md line 130)
    /// 1. Show all deals with DealScore ≥80
    /// 2. If >20 deals, remove lowest scores to cap at 20
    /// 3. If <20 deals, backfill with deals ≥70
    private func apply20DealAlgorithm(_ rankedDeals: [RankedDeal]) -> [FlightDeal] {
        // Step 1: Get all deals with score ≥80
        var excellentDeals = rankedDeals.filter { $0.dealScore >= 80 }

        // Step 2: If >20, remove lowest scores
        if excellentDeals.count > 20 {
            // Already sorted by queue score (highest first), so take first 20
            excellentDeals = Array(excellentDeals.prefix(20))
        }

        // Step 3: If <20, backfill with deals ≥70
        if excellentDeals.count < 20 {
            let goodDeals = rankedDeals.filter { $0.dealScore >= 70 && $0.dealScore < 80 }
            let needed = 20 - excellentDeals.count
            excellentDeals.append(contentsOf: Array(goodDeals.prefix(needed)))
        }

        // Extract FlightDeal from RankedDeal
        return excellentDeals.map(\.deal)
    }

    private func filterByOrigin(_ deals: [FlightDeal], origin: String?) -> [FlightDeal] {
        guard let origin else { return deals }
        return deals.filter { $0.origin == origin }
    }
}
