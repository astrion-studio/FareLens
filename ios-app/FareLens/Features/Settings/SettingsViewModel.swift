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

    private var dismissSuccessTask: Task<Void, Never>?
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    init(user: User) {
        self.user = user
        alertPreferences = user.alertPreferences
        preferredAirports = user.preferredAirports
        feedbackGenerator.prepare()
    }

    deinit {
        dismissSuccessTask?.cancel()
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

        // Prepare haptic engine before save (reduces latency)
        feedbackGenerator.prepare()

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

            // VoiceOver announcement for save success
            UIAccessibility.post(notification: .announcement, argument: "Preferred airports saved successfully")

            // Optimized haptic timing - delay 50ms to coincide with visual update
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(50))
                feedbackGenerator.notificationOccurred(.success)
            }

            // Auto-hide success message after 1.2 seconds (optimized from 2s)
            // Cancel any existing dismiss task
            dismissSuccessTask?.cancel()
            dismissSuccessTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                showSaveSuccess = false
            }
        } catch let error as URLError {
            // Network-related errors
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut:
                errorMessage = "Network error. Please check your connection and try again."
            case .userAuthenticationRequired:
                errorMessage = "Session expired. Please sign in again."
            default:
                errorMessage = "Failed to save airports. Please try again."
            }
            feedbackGenerator.notificationOccurred(.error)
            // VoiceOver announcement for error
            if let errorMsg = errorMessage {
                UIAccessibility.post(notification: .announcement, argument: errorMsg)
            }
        } catch {
            // Other errors (API errors, etc.)
            // TODO: Add typed error handling for APIError when available
            errorMessage = "Failed to save airports. Please try again."
            feedbackGenerator.notificationOccurred(.error)
            // VoiceOver announcement for error
            UIAccessibility.post(notification: .announcement, argument: errorMessage ?? "Save failed")
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
