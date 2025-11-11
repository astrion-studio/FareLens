// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation
import OSLog
import UIKit

// MARK: - Notification Observation Helper

/// Wrapper object that manages a NotificationCenter observation and removes it when deallocated.
///
/// We use this helper so that `AppState` doesn't need to access its observer token from `deinit`,
/// which is a nonisolated context. Accessing `@MainActor` isolated state from `deinit` triggers
/// Swift 6 actor-isolation diagnostics (the original cause of build failures for this file).
/// By encapsulating the observer cleanup inside this helper class, the removal happens safely on
/// deallocation without violating isolation rules.
private final class NotificationObservation {
    private weak var center: NotificationCenter?
    private var token: NSObjectProtocol?

    init(
        center: NotificationCenter = .default,
        name: NSNotification.Name,
        queue: OperationQueue? = .main,
        handler: @escaping (Notification) -> Void
    ) {
        self.center = center
        token = center.addObserver(forName: name, object: nil, queue: queue, using: handler)
    }

    deinit {
        if let token, let center {
            center.removeObserver(token)
        }
    }
}

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

    private let notificationObserver: NotificationObservation
    private let logger = Logger(subsystem: "com.astrionstudio.farelens", category: "AppState")

    init() {
        notificationObserver = NotificationObservation(
            name: NSNotification.Name("OpenDealDetail"),
            handler: { [weak self] notification in
                guard
                    let dealId = notification.userInfo?["dealId"] as? String
                else { return }
                let deepLink = notification.userInfo?["deepLink"] as? String
                Task { await self?.handleDealDeepLink(dealId: dealId, deepLink: deepLink) }
            }
        )
    }

    // Note: Services accessed directly via .shared to avoid actor isolation issues
    // This is safe because all access is from @MainActor context

    func initialize() async {
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
    /// If network error, keeps cached user and retries
    private func validateAuthInBackground() async {
        while true {
            // Note: getCurrentUser returns nil for BOTH network errors AND auth failures
            // We distinguish by checking if tokens were cleared by AuthService
            let hadTokensBefore = await AuthService.shared.hasValidTokens()
            let user = await AuthService.shared.getCurrentUser()
            let hasTokensAfter = await AuthService.shared.hasValidTokens()

            if let user {
                // Token valid - update user data (may have changed on server)
                currentUser = user
                isAuthenticated = true
                break
            } else if hadTokensBefore, !hasTokensAfter {
                // Tokens were cleared = confirmed auth failure (expired/invalid)
                // Sign out immediately
                logger.warning("Session expired/invalid - signing out")
                await signOut()
                break
            } else {
                // Tokens still exist = network error or timeout
                // Keep cached user and retry later
                logger.warning("Background auth validation failed (network error), keeping cached session")

                // Retry after 30 seconds
                try? await Task.sleep(nanoseconds: 30_000_000_000)
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
