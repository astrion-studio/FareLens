// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class AppState {
    var isAuthenticated = false
    var currentUser: User?
    var subscriptionTier: SubscriptionTier = .free
    var isLoading = true // Start as true to show loading view immediately
    var deepLinkDeal: FlightDeal?
    var isPresentingDeepLink = false

    private var notificationObserver: NSObjectProtocol?

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
        MainActor.assumeIsolated {
            if let notificationObserver {
                NotificationCenter.default.removeObserver(notificationObserver)
            }
        }
    }

    // Note: Services accessed directly via .shared to avoid actor isolation issues
    // This is safe because all access is from @MainActor context

    func initialize() async {
        isLoading = true
        defer { isLoading = false }

        // Check authentication status with timeout to prevent long delays
        do {
            let user = try await withTimeout(seconds: 2) {
                await AuthService.shared.getCurrentUser()
            }

            if let user {
                currentUser = user
                isAuthenticated = true

                // Load subscription status in background (don't block UI)
                Task {
                    subscriptionTier = await SubscriptionService.shared.getCurrentTier()
                }

                // Note: Push notification registration temporarily disabled until paid Apple Developer
                // account is set up (see issue #121). When re-enabled, uncomment:
                // await NotificationService.shared.requestAuthorization()
                // await NotificationService.shared.registerForRemoteNotifications()
            }
        } catch {
            // Timeout or error - show unauthenticated state
            // User can still try to sign in manually
            isAuthenticated = false
            currentUser = nil
        }
    }

    /// Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async -> T?) async throws -> T? {
        try await withThrowingTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }

            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }

            // Return first result (either operation or timeout)
            if let result = try await group.next() {
                group.cancelAll()
                return result
            }

            return nil
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
