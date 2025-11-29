// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class AlertsViewModel {
    var alerts: [AlertHistory] = []
    var filteredAlerts: [AlertHistory] = []
    var alertsSentToday = 0
    var dailyLimit = 3
    var isLoading = false
    var errorMessage: String?

    private let alertService: AlertServiceProtocol
    private let alertsRepository: AlertsRepositoryProtocol
    private let user: User

    init(
        user: User,
        alertService: AlertServiceProtocol = AlertService.shared,
        alertsRepository: AlertsRepositoryProtocol = AlertsRepository.shared
    ) {
        self.user = user
        self.alertService = alertService
        self.alertsRepository = alertsRepository
        dailyLimit = user.maxAlertsPerDay
    }

    func loadAlerts(forceRefresh: Bool = false) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let history = try await alertsRepository.fetchAlertHistory(forceRefresh: forceRefresh)
            alerts = history
            filteredAlerts = history
            alertsSentToday = await alertService.getAlertsSentToday(for: user.id)
        } catch {
            // Distinguish between "no alerts yet" (empty state) vs actual errors
            // If it's a 404 or "not found" error, treat as empty state (no error)
            let errorDescription = error.localizedDescription.lowercased()
            if errorDescription.contains("404") ||
               errorDescription.contains("not found") ||
               errorDescription.contains("no alerts") {
                // Treat as successful empty state
                alerts = []
                filteredAlerts = []
                errorMessage = nil
            } else {
                // Actual error (network, server, etc.)
                errorMessage = "Failed to load alerts. Please check your connection and try again."
            }

            // Still try to get today's count even if history fetch failed
            alertsSentToday = (try? await alertService.getAlertsSentToday(for: user.id)) ?? 0
        }
    }

    func refreshAlerts() async {
        await loadAlerts(forceRefresh: true)
    }

    func applyFilter(_ filter: AlertFilter) {
        let calendar = Calendar.current
        let now = Date()

        switch filter {
        case .all:
            filteredAlerts = alerts

        case .today:
            filteredAlerts = alerts.filter { alert in
                calendar.isDateInToday(alert.sentAt)
            }

        case .thisWeek:
            filteredAlerts = alerts.filter { alert in
                guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
                    return false
                }
                return alert.sentAt >= weekAgo
            }

        case .thisMonth:
            filteredAlerts = alerts.filter { alert in
                calendar.isDate(alert.sentAt, equalTo: now, toGranularity: .month)
            }
        }
    }

    func openDealDetail(_: AlertHistory) {
        // Navigate to deal detail view
        // This would be handled by the navigation coordinator
    }
}
