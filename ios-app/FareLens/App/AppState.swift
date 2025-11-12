// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation
import OSLog
import UIKit

/// Error thrown when an async operation exceeds its timeout
private struct TimeoutError: Error {}

@Observable
@MainActor
final class AppState {
    var isAuthenticated = false
    var currentUser: User?
    var subscriptionTier: SubscriptionTier = .free
    var isLoading = true // Start as true to show loading view immediately
    var deepLinkDeal: FlightDeal?
    var isPresentingDeepLink = false

    private nonisolated(unsafe) var notificationObserver: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.astrionstudio.farelens", category: "AppState")
    @MainActor
    private var isInitializing = false

    init() {
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("OpenDealDetail"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let dealId = notification.userInfo?["dealId"] as? String
            else { return }
            let deepLink = notification.userInfo?["deepLink"] as? String
            Task { await self?.handleDealDeepLink(dealId: dealId, deepLink: deepLink) }
        }
    }

    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }

    // Note: Services accessed directly via .shared to avoid actor isolation issues
    // This is safe because all access is from @MainActor context

    func initialize() async {
        // Prevent concurrent initialization
        guard !isInitializing else {
            logger.warning("initialize() called while already initializing - ignoring")
            return
        }
        isInitializing = true
        defer { isInitializing = false }

        // OPTIMIZATION: Load cached user immediately (no network) for instant app launch
        // Then validate auth in background without blocking UI

        // Phase 1: INSTANT - Load cached auth state (< 100ms)
        if let cachedUser = await PersistenceService.shared.loadUser(),
           await AuthService.shared.primeSessionFromCache(using: cachedUser)
        {
            // Optimistically show as authenticated (API client already has JWT)
            currentUser = cachedUser
            isAuthenticated = true
            isLoading = false

            // Phase 2: BACKGROUND - Validate token (non-blocking)
            Task {
                await validateAuthInBackground()
            }
        } else {
            // No cached user - show onboarding immediately
            isAuthenticated = false
            currentUser = nil
            isLoading = false
        }

        // Load subscription status in background (don't block)
        Task {
            subscriptionTier = await SubscriptionService.shared.getCurrentTier()
        }
    }

    /// Validates auth session in background without blocking UI
    /// If token expired, signs out gracefully
    /// If network error, keeps cached user and retries with exponential backoff
    private func validateAuthInBackground() async {
        let maxRetries = 10
        var retryCount = 0
        var backoffSeconds: UInt64 = 30
        let maxBackoffSeconds: UInt64 = 240 // Cap at 4 minutes
        let backoffMultiplier: UInt64 = 2 // Exponential growth factor

        while retryCount < maxRetries {
            // Check if task was cancelled (e.g., app force-quit)
            if Task.isCancelled {
                logger.info("Background auth validation cancelled")
                break
            }

            // Note: getCurrentUser returns nil for BOTH network errors AND auth failures
            // We distinguish by checking if tokens were cleared by AuthService
            let hadTokensBefore = await AuthService.shared.hasValidTokens()
            let user = await AuthService.shared.getCurrentUser()
            let hasTokensAfter = await AuthService.shared.hasValidTokens()

            if let user {
                // Token valid - update user data (may have changed on server)
                currentUser = user
                isAuthenticated = true
                logger.info("Background auth validation succeeded")
                break
            } else if hadTokensBefore, !hasTokensAfter {
                // Tokens were cleared = confirmed auth failure (expired/invalid)
                // Sign out immediately
                logger.warning("Session expired/invalid - signing out")
                await signOut()
                break
            } else {
                // Tokens still exist = network error or timeout
                retryCount += 1

                if retryCount >= maxRetries {
                    // Max retries reached - keep cached user and stop retrying
                    logger
                        .warning(
                            "Background auth validation failed after \(maxRetries) attempts (total ~28min), keeping cached session"
                        )
                    break
                }

                // Add randomized jitter to prevent synchronized retries across multiple devices
                let jitter = Double.random(in: 0.8...1.2) // ±20% jitter
                let delayWithJitter = UInt64(Double(backoffSeconds) * jitter)

                // Retry with exponential backoff (30s, 60s, 120s, 240s, capped at 240s)
                logger
                    .warning(
                        "Background auth validation failed (network error), retry \(retryCount)/\(maxRetries) in ~\(backoffSeconds)s"
                    )
                try? await Task.sleep(
                    for: .nanoseconds(Int64(delayWithJitter * 1_000_000_000)),
                    tolerance: .seconds(5) // Allow iOS to batch with other timers for power efficiency
                )

                // Check cancellation after sleep
                if Task.isCancelled {
                    logger.info("Background auth validation cancelled during backoff")
                    break
                }

                // Exponential backoff, capped at 4 minutes
                backoffSeconds = min(backoffSeconds * backoffMultiplier, maxBackoffSeconds)
            }
        }
    }

    /// Helper function to add timeout to async operations
    /// Throws TimeoutError if operation exceeds the specified timeout
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T?) async throws -> T? {
        // Guard against invalid timeout values to avoid undefined behaviour in Task.sleep
        guard seconds.isFinite, seconds > 0 else {
            throw TimeoutError()
        }

        // Convert seconds to nanoseconds while clamping to the maximum supported range
        let maxSeconds = Double(UInt64.max) / 1_000_000_000
        let boundedSeconds = min(seconds, maxSeconds)
        let rawNanoseconds = boundedSeconds * 1_000_000_000
        let timeoutNanoseconds = max(UInt64(rawNanoseconds), 1)

        return try await withThrowingTaskGroup(of: T?.self) { group -> T? in
            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw TimeoutError()
            }

            group.addTask {
                await operation()
            }

            defer {
                group.cancelAll()
            }

            guard let firstCompleted = try await group.next() else {
                // All tasks completed without producing a value
                return nil
            }

            return firstCompleted
        }
    }

    func signOut() async {
        await AuthService.shared.signOut()
        isAuthenticated = false
        currentUser = nil
        subscriptionTier = .free
        deepLinkDeal = nil
        isPresentingDeepLink = false
    }

    func dismissDeepLink() {
        deepLinkDeal = nil
        isPresentingDeepLink = false
    }

    private func handleDealDeepLink(dealId: String, deepLink: String?) async {
        do {
            let deal = try await DealsRepository.shared.fetchDealDetail(dealId: dealId)
            deepLinkDeal = deal
            isPresentingDeepLink = true
        } catch {
            // Fallback to provided deep link if detailed fetch fails
            if let deepLink, let url = URL(string: deepLink) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
        }
    }
}
