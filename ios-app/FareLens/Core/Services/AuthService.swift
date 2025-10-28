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
    private let persistenceService: PersistenceService
    private let tokenStore: AuthTokenStore
    private var currentUser: User?
    private let logger = Logger(subsystem: "com.astrionstudio.farelens", category: "AuthService")

    init(
        persistenceService: PersistenceService = .shared,
        tokenStore: AuthTokenStore = .shared
    ) {
        // Initialize Supabase client with configuration
        self.supabaseClient = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabasePublishableKey
        )
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

            // Store auth token (JWT)
            await tokenStore.saveToken(response.accessToken)

            // Store user
            currentUser = user
            await persistenceService.saveUser(user)

            return user
        } catch let error as AuthError {
            throw error
        } catch {
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

            // Convert Supabase user to app User model
            let user = try await convertSupabaseUser(response.user)

            // Store auth token (JWT) - handle optional session
            if let session = response.session {
                await tokenStore.saveToken(session.accessToken)
            }

            // Store user
            currentUser = user
            await persistenceService.saveUser(user)

            return user
        } catch let error as AuthError {
            throw error
        } catch {
            // Check if email already exists
            if error.localizedDescription.contains("already registered") {
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
        await persistenceService.clearUser()
    }

    /// Get current authenticated user
    func getCurrentUser() async -> User? {
        // Return cached user if available
        if let user = currentUser {
            return user
        }

        // Try to restore session from stored token
        if await tokenStore.loadToken() != nil {
            do {
                // Verify token is still valid with Supabase
                let session = try await supabaseClient.auth.session

                // Convert to app User model
                let user = try await convertSupabaseUser(session.user)
                currentUser = user
                await persistenceService.saveUser(user)
                return user
            } catch {
                // Token expired or invalid - clear everything
                await tokenStore.clearToken()
                await persistenceService.clearUser()
                currentUser = nil
                return nil
            }
        }

        // Try to load from persistence (fallback)
        if let storedUser = await persistenceService.loadUser() {
            currentUser = storedUser
            return storedUser
        }

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
