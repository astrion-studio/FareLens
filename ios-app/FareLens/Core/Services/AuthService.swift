// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Combine
import Foundation
import OSLog
import Supabase

protocol AuthServiceProtocol {
    func signIn(email: String, password: String) async throws -> User
    func signUp(email: String, password: String) async throws -> User
    func signOut() async
    func getCurrentUser() async -> User?
    func resetPassword(email: String) async throws
}

actor AuthService: AuthServiceProtocol {
    static let shared = AuthService()

    private let supabaseClient: SupabaseClient
    private let apiClient: APIClient
    private let persistenceService: PersistenceService
    private let tokenStore: AuthTokenStore
    private var currentUser: User?
    private let logger = Logger(subsystem: "com.astrionstudio.farelens", category: "AuthService")

    init(
        apiClient: APIClient = .shared,
        persistenceService: PersistenceService = .shared,
        tokenStore: AuthTokenStore = .shared
    ) {
        // Initialize Supabase client with configuration
        guard let url = URL(string: Config.supabaseURL) else {
            fatalError("Invalid SUPABASE_URL configuration: \(Config.supabaseURL)")
        }

        self.supabaseClient = SupabaseClient(
            supabaseURL: url,
            supabaseKey: Config.supabasePublishableKey
        )
        self.apiClient = apiClient
        self.persistenceService = persistenceService
        self.tokenStore = tokenStore
    }

    /// Sign in with email and password
    func signIn(email: String, password: String) async throws -> User {
        do {
            // Authenticate with Supabase
            let response = try await supabaseClient.auth.signIn(
                email: email,
                password: password
            )

            // Convert Supabase user to app User model
            let user = try await convertSupabaseUser(response.user)

            // Store auth token (JWT) and forward to API client
            let token = response.accessToken
            await tokenStore.saveToken(token)
            await apiClient.setAuthToken(token)

            // Store user
            currentUser = user
            await persistenceService.saveUser(user)

            return user
        } catch let error as AuthError {
            throw error
        } catch {
            // Map Supabase errors to app errors
            logger.error("Sign in failed: \(error.localizedDescription)")

            // Check for invalid credentials (400 status from Supabase)
            if let urlError = error as? URLError, urlError.code.rawValue == 400 {
                throw AuthError.invalidCredentials
            }

            throw AuthError.networkError
        }
    }

    /// Sign up with email and password
    func signUp(email: String, password: String) async throws -> User {
        // Validate password strength
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }

        do {
            // Create account with Supabase
            let response = try await supabaseClient.auth.signUp(
                email: email,
                password: password
            )

            // Note: With email confirmation enabled, response.user exists but user
            // needs to confirm email before they can fully access the app
            // The trigger in Supabase will auto-create the user profile

            // Check if session is available (may be nil if email confirmation required)
            guard let session = response.session else {
                // Email confirmation required - don't persist user yet
                throw AuthError.emailNotConfirmed
            }

            // Convert Supabase user to app User model
            let user = try await convertSupabaseUser(response.user)

            // Store auth token (JWT) and forward to API client
            await tokenStore.saveToken(session.accessToken)
            await apiClient.setAuthToken(session.accessToken)

            // Store user only after we have a valid session
            currentUser = user
            await persistenceService.saveUser(user)

            return user
        } catch let error as AuthError {
            throw error
        } catch {
            // Map Supabase errors to app errors
            logger.error("Sign up failed: \(error.localizedDescription)")

            // Check if email already exists - look for user already registered message
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("user already registered") || errorMessage.contains("already exists") {
                throw AuthError.emailAlreadyExists
            }

            throw AuthError.networkError
        }
    }

    /// Sign out current user
    func signOut() async {
        do {
            try await supabaseClient.auth.signOut()
        } catch {
            // Log error but don't throw - always clear local state
            logger.error("Sign out error: \(error.localizedDescription)")
        }

        currentUser = nil
        await tokenStore.clearToken()
        await apiClient.setAuthToken(nil)
        await persistenceService.clearUser()
    }

    /// Get current authenticated user
    func getCurrentUser() async -> User? {
        // Return cached user if available
        if let user = currentUser {
            return user
        }

        // Try to restore session from stored token
        if let token = await tokenStore.loadToken() {
            do {
                // Verify token is still valid with Supabase
                let session = try await supabaseClient.auth.session

                // Convert to app User model
                let user = try await convertSupabaseUser(session.user)
                currentUser = user
                await persistenceService.saveUser(user)

                // Restore token to API client
                await apiClient.setAuthToken(token)

                return user
            } catch {
                // Token expired or invalid - clear everything
                await tokenStore.clearToken()
                await apiClient.setAuthToken(nil)
                await persistenceService.clearUser()
                currentUser = nil
                return nil
            }
        }

        // No valid token - user is not authenticated
        return nil
    }

    /// Reset password via email
    func resetPassword(email: String) async throws {
        do {
            try await supabaseClient.auth.resetPasswordForEmail(email)
        } catch {
            throw AuthError.networkError
        }
    }

    /// Get current auth token (JWT)
    func getAuthToken() async -> String? {
        await tokenStore.loadToken()
    }

    // MARK: - Private Helpers

    /// Convert Supabase user to app User model
    private func convertSupabaseUser(_ supabaseUser: Supabase.User) async throws -> User {
        // Query user profile from public.users table
        do {
            struct UserProfile: Codable {
                let id: UUID
                let email: String
                let subscriptionTier: String
                let timezone: String
                let createdAt: Date

                enum CodingKeys: String, CodingKey {
                    case id
                    case email
                    case subscriptionTier = "subscription_tier"
                    case timezone
                    case createdAt = "created_at"
                }
            }

            let profile: UserProfile = try await supabaseClient
                .from("users")
                .select()
                .eq("id", value: supabaseUser.id.uuidString)
                .single()
                .execute()
                .value

            // Convert to app User model
            let tier = SubscriptionTier(rawValue: profile.subscriptionTier) ?? .free
            return User(
                id: profile.id,
                email: profile.email,
                createdAt: profile.createdAt,
                timezone: profile.timezone,
                subscriptionTier: tier,
                alertPreferences: .default,
                preferredAirports: [],
                watchlists: []
            )
        } catch {
            // If profile doesn't exist yet (e.g., during signup before trigger runs),
            // create a basic User with data from Supabase Auth
            return User(
                id: supabaseUser.id,
                email: supabaseUser.email ?? "",
                createdAt: supabaseUser.createdAt,
                timezone: TimeZone.current.identifier,
                subscriptionTier: .free,
                alertPreferences: .default,
                preferredAirports: [],
                watchlists: []
            )
        }
    }
}

enum AuthError: Error, LocalizedError {
    case invalidCredentials
    case userNotFound
    case emailAlreadyExists
    case weakPassword
    case networkError
    case emailNotConfirmed

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
        case .emailNotConfirmed:
            "Please confirm your email address before signing in"
        }
    }
}
