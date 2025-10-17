// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Combine
import Foundation

protocol AuthServiceProtocol {
    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String) async throws -> User
    func signOut() async
    func getCurrentUser() async -> User?
    func resetPassword(email: String) async throws
}

actor AuthService: AuthServiceProtocol {
    static let shared = AuthService()

    private let apiClient: APIClient
    private let persistenceService: PersistenceService
    private var currentUser: User?
    private var authToken: String?

    init(
        apiClient: APIClient = .shared,
        persistenceService: PersistenceService = .shared
    ) {
        self.apiClient = apiClient
        self.persistenceService = persistenceService
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> User {
        // This is a simplified implementation - in production, integrate with Supabase Auth
        // For now, mock the authentication flow

        let endpoint = APIEndpoint(
            path: "/auth/signin",
            method: .post,
            body: [
                "email": email,
                "password": password,
            ]
        )

        struct SignInResponse: Codable {
            let user: User
            let token: String
        }

        let response: SignInResponse = try await apiClient.request(endpoint)

        // Store auth token
        authToken = response.token
        await apiClient.setAuthToken(response.token)

        // Store user
        currentUser = response.user
        await persistenceService.saveUser(response.user)

        return response.user
    }

    /// Sign up with email and password
    func signUp(email: String, password: String) async throws -> User {
        let endpoint = APIEndpoint(
            path: "/auth/signup",
            method: .post,
            body: [
                "email": email,
                "password": password,
            ]
        )

        struct SignUpResponse: Codable {
            let user: User
            let token: String
        }

        let response: SignUpResponse = try await apiClient.request(endpoint)

        // Store auth token
        authToken = response.token
        await apiClient.setAuthToken(response.token)

        // Store user
        currentUser = response.user
        await persistenceService.saveUser(response.user)

        return response.user
    }

    /// Sign out current user
    func signOut() async {
        authToken = nil
        currentUser = nil
        await apiClient.setAuthToken(nil)
        await persistenceService.clearUser()
    }

    /// Get current authenticated user
    func getCurrentUser() async -> User? {
        if let user = currentUser {
            return user
        }

        // Try to load from persistence
        if let storedUser = await persistenceService.loadUser() {
            currentUser = storedUser
            return storedUser
        }

        return nil
    }

    /// Reset password via email
    func resetPassword(email: String) async throws {
        let endpoint = APIEndpoint(
            path: "/auth/reset-password",
            method: .post,
            body: [
                "email": email,
            ]
        )

        try await apiClient.requestNoResponse(endpoint)
    }

    /// Get current auth token
    func getAuthToken() -> String? {
        authToken
    }
}

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case userNotFound
    case emailAlreadyExists
    case weakPassword
    case networkError

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid email or password"
        case .userNotFound:
            "User not found"
        case .emailAlreadyExists:
            "An account with this email already exists"
        case .weakPassword:
            "Password must be at least 8 characters"
        case .networkError:
            "Network error. Please try again."
        }
    }
}
