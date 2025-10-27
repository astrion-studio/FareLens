// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation
import SwiftUI
import UIKit

@Observable
@MainActor
final class DealDetailViewModel {
    var deal: FlightDeal
    var isSaved = false
    var isLoading = false
    var priceHistory: [PricePoint] = []
    var isLoadingHistory = false
    var showingError = false
    var errorMessage: String?

    private let savedDealsRepository: SavedDealsRepositoryProtocol

    init(
        deal: FlightDeal,
        savedDealsRepository: SavedDealsRepositoryProtocol = SavedDealsRepository.shared
    ) {
        self.deal = deal
        self.savedDealsRepository = savedDealsRepository

        Task { [deal] in
            let saved = await savedDealsRepository.isDealSaved(deal.id)
            await MainActor.run {
                self.isSaved = saved
            }
        }
    }

    func toggleSave() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if isSaved {
                try await savedDealsRepository.removeDeal(deal.id)
                isSaved = false
            } else {
                try await savedDealsRepository.saveDeal(deal)
                isSaved = true
            }
        } catch {
            errorMessage = "We couldn't update your saved deals. Please try again."
            showingError = true
        }
    }

    func loadPriceHistory() async {
        guard !isLoadingHistory else { return }

        isLoadingHistory = true
        errorMessage = nil
        defer { isLoadingHistory = false }

        // TODO: Implement price history fetching from backend
        // TODO: Call price history API endpoint
        // TODO: Parse and populate priceHistory array

        // Placeholder implementation
        priceHistory = []
    }

    func openBookingURL() {
        // In production, this would be the actual booking URL from the deal
        guard let url = URL(string: deal.bookingURL) else {
            errorMessage = "Invalid booking URL"
            showingError = true
            return
        }

        UIApplication.shared.open(url)
    }

    func sharePressed() {
        let text = "Check out this deal: \(deal.origin) → \(deal.destination) for \(deal.formattedPrice)!"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController
        {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Price Point Model

struct PricePoint: Identifiable, Codable {
    let id: UUID
    let date: Date
    let price: Double

    init(id: UUID = UUID(), date: Date, price: Double) {
        self.id = id
        self.date = date
        self.price = price
    }
}
