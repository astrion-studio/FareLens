// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

@testable import FareLens
import XCTest

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    var sut: OnboardingViewModel!
    var mockAppState: AppState!
    var mockAuthService: MockAuthService!

    override func setUp() async throws {
        try await super.setUp()
        mockAppState = AppState()
        mockAuthService = MockAuthService()
        sut = OnboardingViewModel(appState: mockAppState, authService: mockAuthService)
    }

    override func tearDown() async throws {
        sut = nil
        mockAppState = nil
        mockAuthService = nil
        try await super.tearDown()
    }

    // MARK: - Email Validation Tests

    func testValidateEmailFormat_WithValidEmail_ClearsError() {
        // Arrange
        sut.email = "test@example.com"
        sut.emailError = .invalidFormat

        // Act
        sut.validateEmailFormat()

        // Assert
        XCTAssertNil(sut.emailError, "Valid email should clear error")
    }

    func testValidateEmailFormat_WithInvalidEmail_SetsError() {
        // Arrange
        sut.email = "invalid-email"

        // Act
        sut.validateEmailFormat()

        // Assert
        XCTAssertEqual(sut.emailError, .invalidFormat, "Invalid email should set format error")
    }

    func testValidateEmailFormat_WithEmptyEmail_DoesNotSetError() {
        // Arrange
        sut.email = ""

        // Act
        sut.validateEmailFormat()

        // Assert
        XCTAssertNil(sut.emailError, "Empty email on blur should not show error")
    }

    // MARK: - Form Validation Tests

    func testValidateAndSubmit_WithEmptyFields_ShowsBothErrors() async {
        // Arrange
        sut.email = ""
        sut.password = ""

        // Act
        await sut.validateAndSubmit(isSignUp: false)

        // Assert
        XCTAssertEqual(sut.emailError, .empty, "Empty email should show empty error")
        XCTAssertEqual(sut.passwordError, .empty, "Empty password should show empty error")
    }

    func testValidateAndSubmit_WithInvalidEmailAndShortPassword_ShowsBothErrors() async {
        // Arrange
        sut.email = "invalid"
        sut.password = "short"

        // Act
        await sut.validateAndSubmit(isSignUp: false)

        // Assert
        XCTAssertEqual(sut.emailError, .invalidFormat, "Invalid email should show format error")
        XCTAssertEqual(sut.passwordError, .tooShort, "Short password should show too short error")
    }

    func testValidateAndSubmit_WithValidEmail_ClearsEmailError() async {
        // Arrange
        sut.email = "test@example.com"
        sut.password = ""
        sut.emailError = .invalidFormat

        // Act
        await sut.validateAndSubmit(isSignUp: false)

        // Assert
        XCTAssertNil(sut.emailError, "Valid email should not have error")
        XCTAssertEqual(sut.passwordError, .empty, "Empty password should show error")
    }

    // MARK: - Form State Tests

    func testIsFormValid_WithValidCredentials_ReturnsTrue() {
        // Arrange
        sut.email = "test@example.com"
        sut.password = "password123"

        // Assert
        XCTAssertTrue(sut.isFormValid, "Form should be valid with proper email and password")
    }

    func testIsFormValid_WithInvalidEmail_ReturnsFalse() {
        // Arrange
        sut.email = "invalid"
        sut.password = "password123"

        // Assert
        XCTAssertFalse(sut.isFormValid, "Form should be invalid with malformed email")
    }

    func testIsFormValid_WithShortPassword_ReturnsFalse() {
        // Arrange
        sut.email = "test@example.com"
        sut.password = "short"

        // Assert
        XCTAssertFalse(sut.isFormValid, "Form should be invalid with password < 8 characters")
    }

    func testIsFormValid_WithEmptyFields_ReturnsFalse() {
        // Arrange
        sut.email = ""
        sut.password = ""

        // Assert
        XCTAssertFalse(sut.isFormValid, "Form should be invalid with empty fields")
    }

    // MARK: - Error Clearing Tests

    func testClearErrors_RemovesAllErrors() {
        // Arrange
        sut.emailError = .invalidFormat
        sut.passwordError = .tooShort
        sut.serverError = .network

        // Act
        sut.clearErrors()

        // Assert
        XCTAssertNil(sut.emailError, "Email error should be cleared")
        XCTAssertNil(sut.passwordError, "Password error should be cleared")
        XCTAssertNil(sut.serverError, "Server error should be cleared")
    }

    // MARK: - Onboarding Flow Tests

    func testNextStep_FromWelcome_GoesToBenefits() {
        // Arrange
        sut.currentStep = .welcome

        // Act
        sut.nextStep()

        // Assert
        XCTAssertEqual(sut.currentStep, .benefits, "Should transition to benefits")
    }

    func testNextStep_FromBenefits_GoesToAuth() {
        // Arrange
        sut.currentStep = .benefits

        // Act
        sut.nextStep()

        // Assert
        XCTAssertEqual(sut.currentStep, .auth, "Should transition to auth")
    }

    func testPreviousStep_FromAuth_GoesToBenefits() {
        // Arrange
        sut.currentStep = .auth

        // Act
        sut.previousStep()

        // Assert
        XCTAssertEqual(sut.currentStep, .benefits, "Should go back to benefits")
    }

    func testPreviousStep_FromBenefits_GoesToWelcome() {
        // Arrange
        sut.currentStep = .benefits

        // Act
        sut.previousStep()

        // Assert
        XCTAssertEqual(sut.currentStep, .welcome, "Should go back to welcome")
    }

    // MARK: - Edge Cases

    func testValidateEmailFormat_WithSpecialCharacters_ValidatesCorrectly() {
        // Arrange
        sut.email = "user+tag@example.co.uk"

        // Act
        sut.validateEmailFormat()

        // Assert
        XCTAssertNil(sut.emailError, "Valid email with + and subdomain should pass")
    }

    func testValidateAndSubmit_WithExactly8CharPassword_Passes() async {
        // Arrange
        sut.email = "test@example.com"
        sut.password = "12345678"

        // Act
        await sut.validateAndSubmit(isSignUp: false)

        // Assert
        XCTAssertNil(sut.passwordError, "Password with exactly 8 characters should pass")
    }

    // MARK: - Helper Methods

    private func makeSampleUser() -> User {
        User(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            email: "test@example.com",
            createdAt: Date(timeIntervalSince1970: 1672531200), // 2023-01-01 00:00:00 UTC
            timezone: "UTC",
            subscriptionTier: .free,
            alertPreferences: .default,
            preferredAirports: [],
            watchlists: []
        )
    }
}

// MARK: - Mock Auth Service

final class MockAuthService: AuthServiceProtocol {
    var signInCalledWith: (email: String, password: String)?
    var signUpCalledWith: (email: String, password: String)?
    var resetPasswordCalledWith: String?

    var signInResult: Result<User, Error> = .success(
        User(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            email: "test@example.com",
            createdAt: Date(timeIntervalSince1970: 1672531200),
            timezone: "UTC",
            subscriptionTier: .free,
            alertPreferences: .default,
            preferredAirports: [],
            watchlists: []
        )
    )
    var signUpResult: Result<User, Error> = .success(
        User(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            email: "test@example.com",
            createdAt: Date(timeIntervalSince1970: 1672531200),
            timezone: "UTC",
            subscriptionTier: .free,
            alertPreferences: .default,
            preferredAirports: [],
            watchlists: []
        )
    )
    var resetPasswordResult: Result<Void, Error> = .success(())

    func signIn(email: String, password: String) async throws -> User {
        signInCalledWith = (email, password)
        return try signInResult.get()
    }

    func signUp(email: String, password: String) async throws -> User {
        signUpCalledWith = (email, password)
        return try signUpResult.get()
    }

    func resetPassword(email: String) async throws {
        resetPasswordCalledWith = email
        try resetPasswordResult.get()
    }

    func refreshSession() async throws -> User {
        fatalError("refreshSession not implemented in mock")
    }

    func signOut() async throws {
        fatalError("signOut not implemented in mock")
    }
}
