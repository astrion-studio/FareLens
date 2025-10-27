// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import OSLog

protocol AlertsRepositoryProtocol {
    func fetchAlertHistory(forceRefresh: Bool) async throws -> [AlertHistory]
    func appendLocalAlerts(_ alerts: [AlertHistory]) async
}

actor AlertsRepository: AlertsRepositoryProtocol {
    static let shared = AlertsRepository()

    private let apiClient: APIClientProtocol
    private let persistenceService: PersistenceServiceProtocol
    private let logger = Logger(subsystem: "com.farelens.app", category: "alerts")

    init(
        apiClient: APIClientProtocol = APIClient.shared,
        persistenceService: PersistenceServiceProtocol = PersistenceService.shared
    ) {
        self.apiClient = apiClient
        self.persistenceService = persistenceService
    }

    func fetchAlertHistory(forceRefresh: Bool = false) async throws -> [AlertHistory] {
        if !forceRefresh, await persistenceService.isAlertCacheValid() {
            let cached = await persistenceService.loadAlerts()
            if !cached.isEmpty {
                return cached.sorted { $0.sentAt > $1.sentAt }
            }
        }

        do {
            struct AlertHistoryResponse: Decodable {
                let alerts: [AlertHistoryPayload]
            }

            let endpoint = APIEndpoint.getAlertHistory()
            let response: AlertHistoryResponse = try await apiClient.request(endpoint)
            let alerts = response.alerts.map(\.domainModel).sorted { $0.sentAt > $1.sentAt }

            await persistenceService.saveAlerts(alerts)
            return alerts
        } catch {
            logger.error("Failed to fetch alert history: \(error.localizedDescription, privacy: .public)")
            let fallback = await persistenceService.loadAlerts()
            if !fallback.isEmpty {
                return fallback.sorted { $0.sentAt > $1.sentAt }
            }
            throw error
        }
    }

    func appendLocalAlerts(_ alerts: [AlertHistory]) async {
        guard !alerts.isEmpty else { return }
        let existing = await persistenceService.loadAlerts()
        var merged = alerts + existing

        // Ensure unique IDs and sort
        var seen = Set<UUID>()
        merged = merged.filter { alert in
            if seen.contains(alert.id) {
                return false
            }
            seen.insert(alert.id)
            return true
        }
        merged.sort { $0.sentAt > $1.sentAt }

        // Keep last 100 alerts locally
        let trimmed = Array(merged.prefix(100))
        await persistenceService.saveAlerts(trimmed)
    }
}

// MARK: - DTO Mapping

private struct AlertHistoryPayload: Decodable {
    let id: UUID
    let sentAt: Date
    let openedAt: Date?
    let clickedThrough: Bool?
    let expiresAt: Date?
    let deal: DealPayload?

    struct DealPayload: Decodable {
        let id: UUID
        let origin: String
        let destination: String
        let departureDate: Date
        let returnDate: Date
        let totalPrice: Double
        let currency: String
        let dealScore: Int
        let discountPercent: Int
        let normalPrice: Double
        let createdAt: Date
        let expiresAt: Date
        let airline: String
        let stops: Int
        let returnStops: Int?
        let deepLink: String
    }

    var domainModel: AlertHistory {
        AlertHistory(
            id: id,
            deal: mapDeal(),
            sentAt: sentAt,
            wasClicked: clickedThrough ?? false,
            expiresAt: expiresAt
        )
    }

    private func mapDeal() -> FlightDeal {
        guard let deal else {
            // Fallback placeholder if backend payload is missing
            return FlightDeal.placeholder()
        }

        return FlightDeal(
            id: deal.id,
            origin: deal.origin,
            destination: deal.destination,
            departureDate: deal.departureDate,
            returnDate: deal.returnDate,
            totalPrice: deal.totalPrice,
            currency: deal.currency,
            dealScore: deal.dealScore,
            discountPercent: deal.discountPercent,
            normalPrice: deal.normalPrice,
            createdAt: deal.createdAt,
            expiresAt: deal.expiresAt,
            airline: deal.airline,
            stops: deal.stops,
            returnStops: deal.returnStops,
            deepLink: deal.deepLink
        )
    }
}

private extension FlightDeal {
    static func placeholder() -> FlightDeal {
        FlightDeal(
            id: UUID(),
            origin: "TBD",
            destination: "TBD",
            departureDate: Date(),
            returnDate: Date(),
            totalPrice: 0,
            currency: "USD",
            dealScore: 0,
            discountPercent: 0,
            normalPrice: 0,
            createdAt: Date(),
            expiresAt: Date(),
            airline: "Unknown",
            stops: 0,
            returnStops: 0,
            deepLink: ""
        )
    }
}
