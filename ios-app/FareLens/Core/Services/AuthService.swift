// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Combine
import Foundation
import OSLog
import Supabase

/// Supabase user profile data structure matching public.users table schema
private struct UserProfile: Codable {
    let id: UUID
    let email: String
    let subscriptionTier: String
    let timezone: String
    let createdAt: Date
    let alertEnabled: Bool
    let quietHoursEnabled: Bool
    let quietHoursStart: Int // INTEGER in DB (0-23)
    let quietHoursEnd: Int // INTEGER in DB (0-23)
    let watchlistOnlyMode: Bool
    let preferredAirports: [PreferredAirportData] // JSONB array in DB

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case subscriptionTier = "subscription_tier"
        case timezone
        case createdAt = "created_at"
        case alertEnabled = "alert_enabled"
        case quietHoursEnabled = "quiet_hours_enabled"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case watchlistOnlyMode = "watchlist_only_mode"
        case preferredAirports = "preferred_airports"
    }
}

/// Preferred airport data from Supabase JSONB
private struct PreferredAirportData: Codable {
    let id: UUID
    let iata: String
    let weight: Double
}

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
            // Authenticate with Supabase - returns Session directly in Supabase Swift SDK
            let session = try await supabaseClient.auth.signIn(
                email: email,
                password: password
            )

            // Convert Supabase user to app User model
            let user = try await convertSupabaseUser(session.user)

            // Store both access and refresh tokens for session persistence
            await tokenStore.saveTokens(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken
            )
            await apiClient.setAuthToken(session.accessToken)

            // Store user
            currentUser = user
            await persistenceService.saveUser(user)

            return user
        } catch let error as AuthError {
            throw error
        } catch let error as Supabase.AuthError {
            // Map Supabase AuthError to app errors for better UX
            // TODO: Replace with error code checking when available in Supabase Swift SDK
            // Current SDK doesn't expose structured error codes, so we use string matching
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("invalid") || errorMessage.contains("credentials") {
                throw AuthError.invalidCredentials
            }
            logger.error("Sign in failed: \(error.localizedDescription)")
            throw AuthError.networkError
        } catch {
            logger.error("An unexpected error occurred during sign in: \(error.localizedDescription)")
            throw AuthError.networkError
        }
    }

    /// Sign up with email and password
    func signUp(email: String, password: String) async throws -> User {
        // Note: Password validation is handled by Supabase server-side
        // No client-side validation to avoid code duplication and inconsistency

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
            let user = try await convertSupabaseUser(session.user)

            // Store both access and refresh tokens for session persistence
            await tokenStore.saveTokens(
                accessToken: session.accessToken,
                refreshToken: session.refreshToken
            )
            await apiClient.setAuthToken(session.accessToken)

            // Store user only after we have a valid session
            currentUser = user
            await persistenceService.saveUser(user)

            return user
        } catch let error as AuthError {
            throw error
        } catch let error as Supabase.AuthError {
            // Map Supabase AuthError to app errors for better UX
            let errorMessage = error.localizedDescription.lowercased()
            if errorMessage.contains("user already registered") || errorMessage.contains("already exists") {
                throw AuthError.emailAlreadyExists
            }
            logger.error("Supabase sign up failed: \(error.localizedDescription)")
            throw AuthError.networkError
        } catch {
            logger.error("An unexpected error occurred during sign up: \(error.localizedDescription)")
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
        await tokenStore.clearTokens()
        await apiClient.setAuthToken(nil)
        await persistenceService.clearUser()
    }

    /// Get current authenticated user
    func getCurrentUser() async -> User? {
        // Return cached user if available
        if let user = currentUser {
            return user
        }

        // Try to restore session from stored tokens
        if let tokens = await tokenStore.loadTokens() {
            do {
                // Restore the Supabase session using both access and refresh tokens
                // This allows the SDK to automatically refresh expired access tokens
                let session = try await supabaseClient.auth.setSession(
                    accessToken: tokens.accessToken,
                    refreshToken: tokens.refreshToken
                )

                // Convert to app User model
                let user = try await convertSupabaseUser(session.user)
                currentUser = user
                await persistenceService.saveUser(user)

                // If tokens were refreshed, save the new tokens
                if session.accessToken != tokens.accessToken {
                    await tokenStore.saveTokens(
                        accessToken: session.accessToken,
                        refreshToken: session.refreshToken
                    )
                }

                // Restore access token to API client
                await apiClient.setAuthToken(session.accessToken)

                return user
            } catch let error as Supabase.AuthError {
                // Only clear tokens if it's an authentication error (invalid/expired tokens)
                // Network errors should leave tokens intact for retry
                logger.error("Failed to restore session: \(error.localizedDescription)")

                // Clear tokens only for auth failures, not network errors
                let errorMessage = error.localizedDescription.lowercased()
                if errorMessage.contains("invalid") || errorMessage.contains("expired") || errorMessage
                    .contains("jwt")
                {
                    await tokenStore.clearTokens()
                    await apiClient.setAuthToken(nil)
                    await persistenceService.clearUser()
                    currentUser = nil
                }
                return nil
            } catch {
                // For non-auth errors (network, etc), log but keep tokens for retry
                logger.warning("Failed to restore session (non-auth error): \(error.localizedDescription)")
                return nil
            }
        }

        // No valid tokens - user is not authenticated
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
        await tokenStore.loadTokens()?.accessToken
    }

    // MARK: - Private Helpers

    /// Convert Supabase user to app User model
    private func convertSupabaseUser(_ supabaseUser: Supabase.User) async throws -> User {
        // Query user profile from public.users table
        do {
            let profile: UserProfile = try await supabaseClient
                .from("users")
                .select(
                    "id, email, subscription_tier, timezone, created_at, alert_enabled, quiet_hours_enabled, quiet_hours_start, quiet_hours_end, watchlist_only_mode, preferred_airports"
                )
                .eq("id", value: supabaseUser.id.uuidString)
                .single()
                .execute()
                .value

            // Convert to app User model with full preferences from DB
            let tier = SubscriptionTier(rawValue: profile.subscriptionTier) ?? .free

            // Build AlertPreferences from actual DB values
            let alertPrefs = AlertPreferences(
                enabled: profile.alertEnabled,
                quietHoursEnabled: profile.quietHoursEnabled,
                quietHoursStart: profile.quietHoursStart,
                quietHoursEnd: profile.quietHoursEnd,
                watchlistOnlyMode: profile.watchlistOnlyMode
            )

            // Convert JSONB array to PreferredAirport models
            let airports = profile.preferredAirports.map { data in
                PreferredAirport(id: data.id, iata: data.iata, weight: data.weight)
            }

            return User(
                id: profile.id,
                email: profile.email,
                createdAt: profile.createdAt,
                timezone: profile.timezone,
                subscriptionTier: tier,
                alertPreferences: alertPrefs,
                preferredAirports: airports,
                watchlists: [] // Watchlists loaded separately
            )
        } catch let error as PostgrestError {
            // Check if it's a "profile not found" error (common during signup)
            // PostgrestError uses code "PGRST116" for "not found" errors ("The result contains 0 rows")
            if error.code == "PGRST116" {
                logger.info("User profile not found (likely new signup), creating default profile")
                // Profile doesn't exist yet - return basic User from auth data
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
            // For other database errors (network, etc), throw to handle upstream
            logger.error("Database error fetching user profile: \(error.localizedDescription)")
            throw error
        } catch {
            // For unexpected errors, log and throw
            logger.error("Unexpected error fetching user profile: \(error.localizedDescription)")
            throw error
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
