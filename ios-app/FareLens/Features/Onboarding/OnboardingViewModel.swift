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

    init() {}

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
            _ = try await AuthService.shared.signIn(email: email, password: password)
            isLoading = false
            // Navigation handled by AppState
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
            _ = try await AuthService.shared.signUp(email: email, password: password)
            isLoading = false
            // Navigation handled by AppState
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
}

enum OnboardingStep {
    case welcome
    case benefits
    case auth
}
