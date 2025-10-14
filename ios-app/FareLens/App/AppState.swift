import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    var isAuthenticated = false
    var currentUser: User?
    var subscriptionTier: SubscriptionTier = .free
    var isLoading = false

    init() {}

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
    }
}
