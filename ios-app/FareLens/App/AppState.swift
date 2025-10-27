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
    var isLoading = false
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

    @MainActor
    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
    }

    // Note: Services accessed directly via .shared to avoid actor isolation issues
    // This is safe because all access is from @MainActor context

    func initialize() async {
        isLoading = true
        defer { isLoading = false }

        // Check authentication status
        if let user = await AuthService.shared.getCurrentUser() {
            currentUser = user
            isAuthenticated = true

            // Load subscription status
            subscriptionTier = await SubscriptionService.shared.getCurrentTier()

            // Request notification permissions
            await NotificationService.shared.requestAuthorization()

            // Register for remote notifications
            await NotificationService.shared.registerForRemoteNotifications()
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
