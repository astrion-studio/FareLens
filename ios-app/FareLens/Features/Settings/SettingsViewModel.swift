// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class SettingsViewModel {
    var user: User
    var alertPreferences: AlertPreferences
    var preferredAirports: [PreferredAirport]
    var isLoading = false
    var isSaving = false
    var showSaveSuccess = false
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
            // Use consolidated /user endpoint with correct field names
            let endpoint = APIEndpoint.updateUser(
                alertEnabled: alertPreferences.alertEnabled,
                quietHoursEnabled: alertPreferences.quietHoursEnabled,
                quietHoursStart: alertPreferences.quietHoursStart,
                quietHoursEnd: alertPreferences.quietHoursEnd,
                watchlistOnlyMode: alertPreferences.watchlistOnlyMode
            )
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

        isSaving = true
        errorMessage = nil
        showSaveSuccess = false
        defer { isSaving = false }

        do {
            // Use consolidated /user endpoint
            let endpoint = APIEndpoint.updateUser(
                preferredAirports: preferredAirports
            )
            try await APIClient.shared.requestNoResponse(endpoint)
            user.preferredAirports = preferredAirports

            // Show success feedback
            showSaveSuccess = true

            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)

            // Auto-hide success message after 2 seconds
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                showSaveSuccess = false
            }
        } catch {
            // Provide specific error message
            if error.localizedDescription.lowercased().contains("network") {
                errorMessage = "Network error. Please check your connection and try again."
            } else if error.localizedDescription.lowercased().contains("unauthorized") {
                errorMessage = "Session expired. Please sign in again."
            } else {
                errorMessage = "Failed to save airports. Please try again."
            }
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
            let endpoint = APIEndpoint.updateUser(timezone: timezone)
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
