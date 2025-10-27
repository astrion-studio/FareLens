// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import OSLog

protocol PersistenceServiceProtocol {
    func saveUser(_ user: User) async
    func loadUser() async -> User?
    func clearUser() async
    func saveDeals(_ deals: [FlightDeal], origin: String?) async
    func loadDeals(origin: String?) async -> [FlightDeal]
    func clearDeals() async
    func isCacheValid(for origin: String?) async -> Bool
    func clearAllData() async
}

actor PersistenceService: PersistenceServiceProtocol {
    static let shared = PersistenceService()

    private let userDefaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.farelens.app", category: "persistence")

    private struct DealsCacheEntry: Codable {
        let deals: [FlightDeal]
        let lastRefresh: Date
    }

    private typealias DealsCacheStore = [String: DealsCacheEntry]

    private enum Keys {
        static let currentUser = "current_user"
        static let cachedDeals = "cached_deals"
        static let lastRefresh = "last_refresh"
        static let cachedAlerts = "cached_alerts"
        static let alertsLastRefresh = "alerts_last_refresh"
    }

    private let cacheTTL: TimeInterval = 5 * 60 // 5 minutes per ARCHITECTURE.md line 335

    private func cacheKey(for origin: String?) -> String {
        guard let origin = origin?.trimmingCharacters(in: .whitespacesAndNewlines), !origin.isEmpty else {
            return "__all__"
        }
        return origin.uppercased()
    }

    private func loadDealsStore() -> DealsCacheStore {
        guard let data = userDefaults.data(forKey: Keys.cachedDeals) else {
            return [:]
        }

        let decoder = JSONDecoder()
        if let store = try? decoder.decode(DealsCacheStore.self, from: data) {
            return store
        }

        // Legacy format fallback: cached array without origin separation
        if let legacyDeals = try? decoder.decode([FlightDeal].self, from: data) {
            let lastRefresh = (userDefaults.object(forKey: Keys.lastRefresh) as? Date) ?? .distantPast
            let entry = DealsCacheEntry(deals: legacyDeals, lastRefresh: lastRefresh)
            let store: DealsCacheStore = [cacheKey(for: nil): entry]

            if let upgradedData = try? JSONEncoder().encode(store) {
                userDefaults.set(upgradedData, forKey: Keys.cachedDeals)
            }

            return store
        }

        logger.error("Failed to decode deals cache store")
        return [:]
    }

    private func saveDealsStore(_ store: DealsCacheStore) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(store)
            userDefaults.set(data, forKey: Keys.cachedDeals)
        } catch {
            logger.error("Failed to encode deals cache store: \(error.localizedDescription, privacy: .public)")
        }
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

    func saveDeals(_ deals: [FlightDeal], origin: String? = nil) async {
        var store = loadDealsStore()
        store[cacheKey(for: origin)] = DealsCacheEntry(deals: deals, lastRefresh: Date())
        saveDealsStore(store)
        logger.info("Saved \(deals.count) deals to cache for origin: \(origin ?? "all", privacy: .public)")
    }

    func loadDeals(origin: String? = nil) async -> [FlightDeal] {
        var store = loadDealsStore()
        let key = cacheKey(for: origin)

        guard let entry = store[key] else {
            return []
        }

        let cacheAge = Date().timeIntervalSince(entry.lastRefresh)
        if cacheAge > cacheTTL {
            store.removeValue(forKey: key)
            saveDealsStore(store)
            return []
        }

        logger.info("Loaded \(entry.deals.count) deals from cache for origin: \(origin ?? "all", privacy: .public)")
        return entry.deals
    }

    func clearDeals() async {
        userDefaults.removeObject(forKey: Keys.cachedDeals)
        userDefaults.removeObject(forKey: Keys.lastRefresh)
    }

    // MARK: - Cache Management

    func isCacheValid(for origin: String? = nil) async -> Bool {
        let store = loadDealsStore()
        guard let entry = store[cacheKey(for: origin)] else {
            return false
        }

        let cacheAge = Date().timeIntervalSince(entry.lastRefresh)
        return cacheAge < cacheTTL
    }

    // MARK: - Alert History Persistence

    func saveAlerts(_ alerts: [AlertHistory]) async {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(alerts)
            userDefaults.set(data, forKey: Keys.cachedAlerts)
            userDefaults.set(Date(), forKey: Keys.alertsLastRefresh)
            logger.info("Saved \(alerts.count) alerts to cache")
        } catch {
            logger.error("Failed to save alerts: \(error.localizedDescription, privacy: .public)")
        }
    }

    func loadAlerts() async -> [AlertHistory] {
        guard let data = userDefaults.data(forKey: Keys.cachedAlerts) else {
            return []
        }

        if let lastRefresh = userDefaults.object(forKey: Keys.alertsLastRefresh) as? Date {
            let cacheAge = Date().timeIntervalSince(lastRefresh)
            if cacheAge > 5 * 60 {
                return [] // Cache expired
            }
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let alerts = try decoder.decode([AlertHistory].self, from: data)
            logger.info("Loaded \(alerts.count) alerts from cache")
            return alerts
        } catch {
            logger.error("Failed to load alerts: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func clearAlerts() async {
        userDefaults.removeObject(forKey: Keys.cachedAlerts)
        userDefaults.removeObject(forKey: Keys.alertsLastRefresh)
    }

    func isAlertCacheValid() async -> Bool {
        guard let lastRefresh = userDefaults.object(forKey: Keys.alertsLastRefresh) as? Date else {
            return false
        }

        let cacheAge = Date().timeIntervalSince(lastRefresh)
        return cacheAge < 5 * 60
    }

    func clearAllData() async {
        await clearUser()
        await clearDeals()
        await clearAlerts()
    }
}
