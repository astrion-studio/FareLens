import StoreKit
import Foundation

protocol SubscriptionServiceProtocol {
    func getCurrentTier() async -> SubscriptionTier
    func purchaseSubscription() async throws -> Bool
    func restorePurchases() async throws -> Bool
    func checkTrialEligibility() async -> Bool
    func fetchProducts() async throws -> [Product]
    func purchase(product: Product) async throws -> Bool
}

actor SubscriptionService: SubscriptionServiceProtocol {
    static let shared = SubscriptionService()

    private let productID = "com.farelens.pro.monthly"
    private var currentEntitlement: SubscriptionTier = .free
    private var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    /// Get current subscription tier
    func getCurrentTier() async -> SubscriptionTier {
        await checkSubscriptionStatus()
        return currentEntitlement
    }

    /// Purchase Pro subscription with 14-day free trial
    func purchaseSubscription() async throws -> Bool {
        guard let product = try await loadProduct() else {
            throw SubscriptionError.productNotFound
        }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // Verify transaction
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            return false

        @unknown default:
            return false
        }
    }

    /// Restore previous purchases
    func restorePurchases() async throws -> Bool {
        try await AppStore.sync()
        await updateSubscriptionStatus()
        return currentEntitlement == .pro
    }

    /// Check if user is eligible for 14-day free trial
    func checkTrialEligibility() async -> Bool {
        // Check if user has ever subscribed before
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == productID {
                    return false // User has subscribed before
                }
            }
        }
        return true // Eligible for trial
    }

    // MARK: - Private Methods

    private func loadProduct() async throws -> Product? {
        let products = try await Product.products(for: [productID])
        return products.first
    }

    private func checkSubscriptionStatus() async {
        var validSubscription = false

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == productID {
                    validSubscription = true
                    break
                }
            }
        }

        currentEntitlement = validSubscription ? .pro : .free
    }

    private func updateSubscriptionStatus() async {
        await checkSubscriptionStatus()
    }

    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.updateSubscriptionStatus()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    /// Fetch available subscription products
    func fetchProducts() async throws -> [Product] {
        let productIDs = [
            "com.farelens.pro.monthly",
            "com.farelens.pro.annual"
        ]
        return try await Product.products(for: productIDs)
    }

    /// Purchase a specific product
    func purchase(product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updateSubscriptionStatus()
            return true
        case .userCancelled, .pending:
            return false
        @unknown default:
            return false
        }
    }
}

enum SubscriptionError: Error {
    case productNotFound
    case failedVerification
    case purchaseFailed
}
