// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation

@Observable
@MainActor
final class DealsViewModel {
    var deals: [FlightDeal] = []
    var isLoading = false
    var errorMessage: String?
    var selectedOrigin: String?

    private let user: User

    init(user: User) {
        self.user = user
    }

    func loadDeals(forceRefresh: Bool = false) async {
        isLoading = true
        errorMessage = nil

        do {
            // Fetch deals from repository - access actor directly in async context
            let fetchedDeals = try await DealsRepository.shared.fetchDeals(
                origin: selectedOrigin,
                forceRefresh: forceRefresh
            )

            // Apply smart queue ranking
            deals = await DealsRepository.shared.applySmartQueue(fetchedDeals, for: user)

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func selectOrigin(_ origin: String?) {
        selectedOrigin = origin
        Task {
            await loadDeals(forceRefresh: true)
        }
    }

    func refreshDeals() async {
        await loadDeals(forceRefresh: true)
    }

    func getDealsByScore() -> [String: [FlightDeal]] {
        Dictionary(grouping: deals) { deal in
            deal.dealScoreColor
        }
    }
}
