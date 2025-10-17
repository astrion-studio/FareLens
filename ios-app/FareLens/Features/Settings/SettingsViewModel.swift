// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation

@Observable
@MainActor
final class SettingsViewModel {
    var user: User
    var alertPreferences: AlertPreferences
    var preferredAirports: [PreferredAirport]
    var isLoading = false
    var errorMessage: String?
    var showingUpgradeSheet = false

    init(user: User) {
        self.user = user
        alertPreferences = user.alertPreferences
        preferredAirports = user.preferredAirports
    }

    // Safe URL accessors for settings links
    var privacyPolicyURL: URL? {
        URL(string: "https://farelens.com/privacy")
    }

    var termsOfServiceURL: URL? {
        URL(string: "https://farelens.com/terms")
    }

    var canAddPreferredAirport: Bool {
        preferredAirports.count < user.maxPreferredAirports
    }

    var isWeightSumValid: Bool {
        preferredAirports.isValidWeightSum
    }

    func updateAlertPreferences() async {
        do {
            let endpoint = APIEndpoint.updateAlertPreferences(alertPreferences)
            try await APIClient.shared.requestNoResponse(endpoint)
            user.alertPreferences = alertPreferences
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePreferredAirports() async {
        // Validate weights sum to 1.0
        guard isWeightSumValid else {
            errorMessage = "Airport weights must sum to 1.0"
            return
        }

        do {
            let endpoint = APIEndpoint.updatePreferredAirports(preferredAirports)
            try await APIClient.shared.requestNoResponse(endpoint)
            user.preferredAirports = preferredAirports
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addPreferredAirport(_ airport: PreferredAirport) {
        guard canAddPreferredAirport else {
            showingUpgradeSheet = true
            return
        }

        preferredAirports.append(airport)
    }

    func removePreferredAirport(at index: Int) {
        guard index >= 0, index < preferredAirports.count else {
            errorMessage = "Invalid airport index"
            return
        }
        preferredAirports.remove(at: index)
    }

    func updateAirportWeight(at index: Int, weight: Double) {
        guard index >= 0, index < preferredAirports.count else {
            errorMessage = "Invalid airport index"
            return
        }
        preferredAirports[index].weight = weight
    }

    func updateTimezone(_ timezone: String) async {
        user.timezone = timezone

        do {
            let endpoint = APIEndpoint.updateUser(user)
            try await APIClient.shared.requestNoResponse(endpoint)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleQuietHours() {
        alertPreferences.quietHoursEnabled.toggle()
        Task {
            await updateAlertPreferences()
        }
    }

    func updateQuietHours(start: Int, end: Int) {
        alertPreferences.quietHoursStart = start
        alertPreferences.quietHoursEnd = end
        Task {
            await updateAlertPreferences()
        }
    }

    func toggleWatchlistOnlyMode() {
        // Pro feature only
        guard user.isProUser else {
            showingUpgradeSheet = true
            return
        }

        alertPreferences.watchlistOnlyMode.toggle()
        Task {
            await updateAlertPreferences()
        }
    }
}
