// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import OSLog

protocol SavedDealsRepositoryProtocol {
    func isDealSaved(_ id: UUID) async -> Bool
    func saveDeal(_ deal: FlightDeal) async throws
    func removeDeal(_ id: UUID) async throws
    func allSavedDeals() async -> [FlightDeal]
}

actor SavedDealsRepository: SavedDealsRepositoryProtocol {
    static let shared = SavedDealsRepository()

    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.farelens.app", category: "savedDeals")
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "saved_deals") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
    }

    func isDealSaved(_ id: UUID) async -> Bool {
        let deals = await allSavedDeals()
        return deals.contains { $0.id == id }
    }

    func saveDeal(_ deal: FlightDeal) async throws {
        var deals = await allSavedDeals()
        guard !deals.contains(where: { $0.id == deal.id }) else {
            return
        }
        deals.append(deal)
        try persist(deals)
        logger.info("Saved deal \(deal.id.uuidString, privacy: .public)")
    }

    func removeDeal(_ id: UUID) async throws {
        var deals = await allSavedDeals()
        let initialCount = deals.count
        deals.removeAll { $0.id == id }
        guard deals.count != initialCount else { return }
        try persist(deals)
        logger.info("Removed saved deal \(id.uuidString, privacy: .public)")
    }

    func allSavedDeals() async -> [FlightDeal] {
        guard let data = userDefaults.data(forKey: storageKey) else {
            return []
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([FlightDeal].self, from: data)
        } catch {
            logger.error("Failed to decode saved deals: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    // MARK: - Private

    private func persist(_ deals: [FlightDeal]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(deals)
        userDefaults.set(data, forKey: storageKey)
    }
}
