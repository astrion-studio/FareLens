// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class OnboardingViewModel {
    // W3C HTML5 email validation regex (matches user expectations from web forms)
    // Server does authoritative validation - this is just client-side UX
    // Anchors (^$) ensure entire string matches (prevents partial matches like "valid@test.com invalid")
    private static let emailValidationRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}$"

    var email = ""
    var password = ""
    var isLoading = false
    var currentStep: OnboardingStep = .welcome

    // Validation errors (field-level)
    var emailError: ValidationError?
    var passwordError: ValidationError?

    // Server errors (screen-level)
    var serverError: ServerError?

    // Airport selection state
    var selectedAirports: [PreferredAirport] = []
    var isSavingAirports = false
    var airportSelectionError: String?

    private let appState: AppState
    private let authService: AuthServiceProtocol
    private let apiClient: APIClient

    init(appState: AppState, authService: AuthServiceProtocol = AuthService.shared, apiClient: APIClient = .shared) {
        self.appState = appState
        self.authService = authService
        self.apiClient = apiClient
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
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", Self.emailValidationRegex)
        return emailPredicate.evaluate(with: email)
    }

    // MARK: - Authentication

    private func signIn() async {
        isLoading = true
        serverError = nil

        do {
            let user = try await authService.signIn(email: email, password: password)
            isLoading = false

            // Success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Update AppState with user info (but don't mark authenticated yet)
            appState.currentUser = user
            appState.subscriptionTier = user.subscriptionTier

            // Check if user already has preferred airports
            if !user.preferredAirports.isEmpty {
                // User has airports - complete onboarding
                appState.isAuthenticated = true
                await registerForNotifications()
            } else {
                // New user - advance to airport selection
                currentStep = .airportSelection
            }
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
            let user = try await authService.signUp(email: email, password: password)
            isLoading = false

            // Success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            // Update AppState with user info (but don't mark authenticated yet)
            appState.currentUser = user
            appState.subscriptionTier = user.subscriptionTier

            // New signups always need to select airports
            currentStep = .airportSelection
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
            .invalidCredentials
        case .emailNotConfirmed:
            .emailNotConfirmed
        case .emailAlreadyExists:
            .emailAlreadyExists
        case .weakPassword:
            .weakPassword
        case .networkError:
            .network
        }
    }

    func nextStep() {
        switch currentStep {
        case .welcome:
            currentStep = .benefits
        case .benefits:
            currentStep = .auth
        case .auth:
            break // Auth success advances to airportSelection automatically
        case .airportSelection:
            break // Airport selection completion sets isAuthenticated
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
        case .airportSelection:
            currentStep = .auth
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

    // MARK: - Airport Selection

    func addAirport(_ airport: PreferredAirport) {
        selectedAirports.append(airport)
        normalizeWeights()
    }

    func removeAirport(at index: Int) {
        selectedAirports.remove(at: index)
        normalizeWeights()
    }

    func updateAirportWeight(at index: Int, weight: Double) {
        selectedAirports[index] = PreferredAirport(
            id: selectedAirports[index].id,
            iata: selectedAirports[index].iata,
            weight: weight
        )
    }

    var canAddAirport: Bool {
        let maxAirports = appState.subscriptionTier == .free ? 1 : 3
        return selectedAirports.count < maxAirports
    }

    var isWeightSumValid: Bool {
        let sum = selectedAirports.reduce(0.0) { $0 + $1.weight }
        return abs(sum - 1.0) < 0.001 // Allow small floating point error
    }

    var canCompleteSelection: Bool {
        !selectedAirports.isEmpty && isWeightSumValid
    }

    func completeAirportSelection() async {
        guard canCompleteSelection else { return }

        isSavingAirports = true
        airportSelectionError = nil

        do {
            try await apiClient.request(
                .updateUser(preferredAirports: selectedAirports),
                responseType: EmptyResponse.self
            )

            isSavingAirports = false

            // Update AppState with selected airports
            if var user = appState.currentUser {
                user.preferredAirports = selectedAirports
                appState.currentUser = user
            }

            // Complete onboarding
            appState.isAuthenticated = true
            await registerForNotifications()

            // Success haptic
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } catch {
            isSavingAirports = false
            airportSelectionError = "Failed to save airports. Please try again."
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }

    func skipAirportSelection() async {
        // Only Pro users can skip
        guard appState.subscriptionTier == .pro else { return }

        // Complete onboarding without airports
        appState.isAuthenticated = true
        await registerForNotifications()
    }

    private func normalizeWeights() {
        guard !selectedAirports.isEmpty else { return }

        if selectedAirports.count == 1 {
            // Single airport gets 100% weight
            selectedAirports[0] = PreferredAirport(
                id: selectedAirports[0].id,
                iata: selectedAirports[0].iata,
                weight: 1.0
            )
        } else {
            // Distribute weights equally
            let equalWeight = 1.0 / Double(selectedAirports.count)
            selectedAirports = selectedAirports.map { airport in
                PreferredAirport(id: airport.id, iata: airport.iata, weight: equalWeight)
            }
        }
    }
}

// MARK: - Empty Response

struct EmptyResponse: Codable {}

enum OnboardingStep {
    case welcome
    case benefits
    case auth
    case airportSelection
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
