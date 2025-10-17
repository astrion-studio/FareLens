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
    private let user: User

    init(user: User, alertService: AlertServiceProtocol = AlertService.shared) {
        self.user = user
        self.alertService = alertService
        dailyLimit = user.maxAlertsPerDay
    }

    func loadAlerts(forceRefresh _: Bool = false) async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // In production, fetch from repository
            // For now, create mock data
            alerts = []
            filteredAlerts = alerts
            alertsSentToday = await alertService.getAlertsSentToday(for: user.id)
        } catch {
            errorMessage = error.localizedDescription
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
