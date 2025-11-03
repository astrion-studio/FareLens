// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?
    var currentStep: OnboardingStep = .welcome

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 8
    }

    func signIn() async {
        guard isFormValid else {
            errorMessage = "Please enter a valid email and password (min 8 characters)"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await AuthService.shared.signIn(email: email, password: password)
            isLoading = false

            // Update AppState to transition to main app
            appState.isAuthenticated = true
            appState.currentUser = user
            appState.subscriptionTier = user.subscriptionTier
            await registerForNotifications()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func signUp() async {
        guard isFormValid else {
            errorMessage = "Please enter a valid email and password (min 8 characters)"
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let user = try await AuthService.shared.signUp(email: email, password: password)
            isLoading = false

            // Update AppState to transition to main app
            appState.isAuthenticated = true
            appState.currentUser = user
            appState.subscriptionTier = user.subscriptionTier
            await registerForNotifications()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .benefits
        case .benefits:
            currentStep = .auth
        case .auth:
            break
        }
    }

    func previousStep() {
        switch currentStep {
        case .welcome:
            break
        case .benefits:
            currentStep = .welcome
        case .auth:
            currentStep = .benefits
        }
    }

    private func registerForNotifications() async {
        // Note: Push notification registration temporarily disabled until paid Apple Developer
        // account is set up (see issue #121). When re-enabled, uncomment:
        // let granted = await NotificationService.shared.requestAuthorization()
        // if granted {
        //     await NotificationService.shared.registerForRemoteNotifications()
        // }
    }
}

enum OnboardingStep {
    case welcome
    case benefits
    case auth
}
