// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation
import SwiftUI

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

    init(deal: FlightDeal) {
        self.deal = deal
        checkIfSaved()
    }

    func checkIfSaved() {
        // TODO: Check if deal matches any watchlist
        // For now, just set to false
        isSaved = false
    }

    func toggleSave() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if isSaved {
                // Remove from watchlists
                // TODO: Implement remove logic
                isSaved = false
            } else {
                // Add to watchlists or create new one
                // TODO: Implement add logic
                isSaved = true
            }
        } catch {
            errorMessage = error.localizedDescription
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
