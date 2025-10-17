// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import OSLog

protocol PersistenceServiceProtocol {
    func saveUser(_ user: User) async
    func loadUser() async -> User?
    func clearUser() async
    func saveDeals(_ deals: [FlightDeal]) async
    func loadDeals() async -> [FlightDeal]
    func clearDeals() async
    func isCacheValid() async -> Bool
    func clearAllData() async
}

actor PersistenceService: PersistenceServiceProtocol {
    static let shared = PersistenceService()

    private let userDefaults = UserDefaults.standard
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.farelens.app", category: "persistence")

    private enum Keys {
        static let currentUser = "current_user"
        static let cachedDeals = "cached_deals"
        static let lastRefresh = "last_refresh"
    }

    // MARK: - User Persistence

    func saveUser(_ user: User) async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(user)
            userDefaults.set(data, forKey: Keys.currentUser)
            logger.info("User saved successfully: \(user.id.uuidString, privacy: .public)")
        } catch {
            logger.error("Failed to save user: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadUser() async -> User? {
        guard let data = userDefaults.data(forKey: Keys.currentUser) else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let user = try decoder.decode(User.self, from: data)
            logger.info("User loaded successfully: \(user.id.uuidString, privacy: .public)")
            return user
        } catch {
            logger.error("Failed to load user: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    func clearUser() async {
        userDefaults.removeObject(forKey: Keys.currentUser)
    }

    // MARK: - Deals Cache

    func saveDeals(_ deals: [FlightDeal]) async {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(deals)
            userDefaults.set(data, forKey: Keys.cachedDeals)
            userDefaults.set(Date(), forKey: Keys.lastRefresh)
            logger.info("Saved \(deals.count) deals to cache")
        } catch {
            logger.error("Failed to save deals: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadDeals() async -> [FlightDeal] {
        guard let data = userDefaults.data(forKey: Keys.cachedDeals) else {
            return []
        }

        // Check if cache is expired (5 minutes per ARCHITECTURE.md line 335)
        if let lastRefresh = userDefaults.object(forKey: Keys.lastRefresh) as? Date {
            let cacheAge = Date().timeIntervalSince(lastRefresh)
            if cacheAge > 5 * 60 { // 5 minutes
                return [] // Cache expired
            }
        }

        do {
            let decoder = JSONDecoder()
            let deals = try decoder.decode([FlightDeal].self, from: data)
            logger.info("Loaded \(deals.count) deals from cache")
            return deals
        } catch {
            logger.error("Failed to load deals: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func clearDeals() async {
        userDefaults.removeObject(forKey: Keys.cachedDeals)
        userDefaults.removeObject(forKey: Keys.lastRefresh)
    }

    // MARK: - Cache Management

    func isCacheValid() async -> Bool {
        guard let lastRefresh = userDefaults.object(forKey: Keys.lastRefresh) as? Date else {
            return false
        }

        let cacheAge = Date().timeIntervalSince(lastRefresh)
        return cacheAge < 5 * 60 // 5 minutes per ARCHITECTURE.md line 335
    }

    func clearAllData() async {
        await clearUser()
        await clearDeals()
    }
}
