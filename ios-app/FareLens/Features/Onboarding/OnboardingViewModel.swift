// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class OnboardingViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var currentStep: OnboardingStep = .welcome

    // Validation errors (field-level)
    var emailError: ValidationError?
    var passwordError: ValidationError?

    // Server errors (screen-level)
    var serverError: ServerError?

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    var isFormValid: Bool {
        !email.isEmpty && isValidEmail(email) && password.count >= 8
    }

    // MARK: - Validation

    /// Validates email format (called on blur)
    func validateEmailFormat() {
        guard !email.isEmpty else {
            emailError = nil // Don't show error for empty field on blur
            return
        }

        if !isValidEmail(email) {
            emailError = .invalidFormat
        } else {
            emailError = nil
        }
    }

    /// Validates all fields and submits form (called on submit button tap)
    func validateAndSubmit(isSignUp: Bool) async {
        // Clear previous errors
        emailError = nil
        passwordError = nil
        serverError = nil

        // Validate all fields and collect errors (don't return early)
        var hasErrors = false

        // Validate email
        if email.isEmpty {
            emailError = .empty
            hasErrors = true
        } else if !isValidEmail(email) {
            emailError = .invalidFormat
            hasErrors = true
        }

        // Validate password
        if password.isEmpty {
            passwordError = .empty
            hasErrors = true
        } else if password.count < 8 {
            passwordError = .tooShort
            hasErrors = true
        }

        // If any validation errors, show haptic feedback and stop
        if hasErrors {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }

        // All validation passed - proceed with auth
        if isSignUp {
            await signUp()
        } else {
            await signIn()
        }
    }

    /// Clears all errors (called when switching between sign in/sign up)
    func clearErrors() {
        emailError = nil
        passwordError = nil
        serverError = nil
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }

    // MARK: - Authentication

    private func signIn() async {
        isLoading = true
        serverError = nil

        do {
            let user = try await AuthService.shared.signIn(email: email, password: password)
            isLoading = false

            // Success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Update AppState to transition to main app
            appState.isAuthenticated = true
            appState.currentUser = user
            appState.subscriptionTier = user.subscriptionTier
            await registerForNotifications()
        } catch let error as AuthError {
            isLoading = false
            serverError = mapAuthError(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            isLoading = false
            serverError = .network
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func signUp() async {
        isLoading = true
        serverError = nil

        do {
            let user = try await AuthService.shared.signUp(email: email, password: password)
            isLoading = false

            // Success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Update AppState to transition to main app
            appState.isAuthenticated = true
            appState.currentUser = user
            appState.subscriptionTier = user.subscriptionTier
            await registerForNotifications()
        } catch let error as AuthError {
            isLoading = false
            serverError = mapAuthError(error)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        } catch {
            isLoading = false
            serverError = .network
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    private func mapAuthError(_ error: AuthError) -> ServerError {
        switch error {
        case .invalidCredentials, .userNotFound:
            return .invalidCredentials
        case .emailNotConfirmed:
            return .emailNotConfirmed
        case .emailAlreadyExists:
            return .emailAlreadyExists
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .network
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

// MARK: - Validation Errors

enum ValidationError: Identifiable {
    case empty
    case invalidFormat
    case tooShort

    var id: String {
        switch self {
        case .empty: "empty"
        case .invalidFormat: "invalid"
        case .tooShort: "short"
        }
    }

    var message: String {
        switch self {
        case .empty:
            "This field is required"
        case .invalidFormat:
            "Please enter a valid email address"
        case .tooShort:
            "Password must be at least 8 characters"
        }
    }
}

// MARK: - Server Errors

enum ServerError: Identifiable {
    case invalidCredentials
    case emailNotConfirmed
    case emailAlreadyExists
    case network
    case unknown
    case weakPassword

    var id: String {
        switch self {
        case .invalidCredentials: "invalid"
        case .emailNotConfirmed: "not_confirmed"
        case .emailAlreadyExists: "exists"
        case .network: "network"
        case .unknown: "unknown"
        case .weakPassword: "weak_password"
        }
    }

    var message: String {
        switch self {
        case .invalidCredentials:
            "The email or password you entered is incorrect. Please try again."
        case .emailNotConfirmed:
            "Please verify your email address. Check your inbox for a confirmation link."
        case .emailAlreadyExists:
            "An account with this email already exists. Try signing in instead."
        case .network:
            "Unable to connect. Please check your internet connection and try again."
        case .unknown:
            "Something went wrong. Please try again."
        case .weakPassword:
            "Password must be at least 8 characters."
        }
    }

    var actionTitle: String? {
        switch self {
        case .emailNotConfirmed:
            "Resend Confirmation"
        case .emailAlreadyExists:
            "Go to Sign In"
        case .network:
            "Try Again"
        case .weakPassword:
            "Update Password"
        default:
            nil
        }
    }
}
