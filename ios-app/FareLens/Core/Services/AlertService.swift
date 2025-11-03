// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import OSLog

protocol AlertServiceProtocol {
    func processNewDeals(_ deals: [FlightDeal], for user: User) async throws -> [FlightDeal]
    func shouldSendAlert(for deal: FlightDeal, user: User) async -> Bool
    func getAlertsSentToday(for userId: UUID) async -> Int
}

actor AlertService: AlertServiceProtocol {
    static let shared = AlertService()

    private let smartQueueService: any SmartQueueServiceProtocol
    private let notificationService: any NotificationServiceProtocol
    private let persistenceService: any PersistenceServiceProtocol
    private let userDefaults: UserDefaults
    private let logger = Logger(subsystem: "com.farelens.app", category: "alerts")
    private let dateProvider: () -> Date

    private var alertsSentToday: [UUID: Int] = [:] // userId: count
    private var lastResetDate: [UUID: Date] = [:] // Per-user reset tracking
    private let deduplicationCache = DeduplicationCache()
    private var hasLoadedPersistedCounters = false

    init(
        smartQueueService: any SmartQueueServiceProtocol = SmartQueueService.shared,
        notificationService: any NotificationServiceProtocol = NotificationService.shared,
        persistenceService: any PersistenceServiceProtocol = PersistenceService.shared,
        userDefaults: UserDefaults = .standard,
        dateProvider: @escaping () -> Date = { Date() }
    ) {
        self.smartQueueService = smartQueueService
        self.notificationService = notificationService
        self.persistenceService = persistenceService
        self.userDefaults = userDefaults
        self.dateProvider = dateProvider
    }

    /// Process new deals and send alerts immediately (respecting caps and quiet hours)
    func processNewDeals(_ deals: [FlightDeal], for user: User) async throws -> [FlightDeal] {
        await ensureCountersLoaded()
        // Reset daily counter if needed
        await resetDailyCounterIfNeeded(for: user)

        // Filter deals based on user preferences
        var filteredDeals = deals.filter { deal in
            // Apply watchlist-only mode if enabled (Pro feature)
            if user.alertPreferences.watchlistOnlyMode {
                return user.watchlists.contains { $0.matches(deal) }
            }
            return true
        }

        // Rank all deals first
        let rankedDeals = await smartQueueService.rankDeals(filteredDeals, for: user)

        // Filter out deals that shouldn't be sent (quiet hours, duplicates)
        var sendableDeals: [RankedDeal] = []
        for rankedDeal in rankedDeals {
            if await shouldSendAlert(for: rankedDeal.deal, user: user) {
                sendableDeals.append(rankedDeal)
            }
        }

        // Now calculate remaining alerts and apply the cap
        let alertsSent = await getAlertsSentToday(for: user.id)
        let remainingAlerts = user.maxAlertsPerDay - alertsSent

        guard remainingAlerts > 0 else {
            return [] // User has reached daily cap
        }

        // Take only up to remaining alerts from sendable deals
        let dealsToAlert = Array(sendableDeals.prefix(remainingAlerts))

        // Send alerts and track sent deals
        var sentDeals: [FlightDeal] = []
        for rankedDeal in dealsToAlert {
            if await sendAlert(for: rankedDeal.deal, user: user) != nil {
                sentDeals.append(rankedDeal.deal)
            }
        }

        return sentDeals
    }

    /// Check if alert should be sent (quiet hours + deduplication)
    func shouldSendAlert(for deal: FlightDeal, user: User) async -> Bool {
        // Check quiet hours
        if await isQuietHours(for: user) {
            return false
        }

        // Check deduplication (12h window)
        let dedupeKey = "\(user.id.uuidString)-\(deal.id.uuidString)"
        if deduplicationCache.wasRecentlySent(key: dedupeKey, within: 12, now: dateProvider()) {
            return false
        }

        return true
    }

    // MARK: - Private Methods

    private func sendAlert(for deal: FlightDeal, user: User) async -> AlertHistory? {
        let sentAt = Date()
        // Send push notification
        await notificationService.sendDealAlert(deal: deal, userId: user.id)

        // Update counters
        let dedupeKey = "\(user.id.uuidString)-\(deal.id.uuidString)"
        deduplicationCache.markAlertSent(key: dedupeKey, date: dateProvider())

        await incrementAlertCounter(for: user.id)

        return AlertHistory(
            id: UUID(),
            deal: deal,
            sentAt: sentAt,
            wasClicked: false,
            expiresAt: deal.expiresAt
        )
    }

    private func isQuietHours(for user: User) async -> Bool {
        let timezone: TimeZone
        if let userTimezone = TimeZone(identifier: user.timezone) {
            timezone = userTimezone
        } else {
            logger.warning("Invalid timezone '\(user.timezone, privacy: .public)', falling back to device timezone")
            timezone = TimeZone.current
        }

        return user.alertPreferences.isQuietHour(at: dateProvider(), timezone: timezone)
    }

    private func resetDailyCounterIfNeeded(for user: User) async {
        let timezone: TimeZone
        if let userTimezone = TimeZone(identifier: user.timezone) {
            timezone = userTimezone
        } else {
            logger.warning("Invalid timezone '\(user.timezone, privacy: .public)', falling back to device timezone")
            timezone = TimeZone.current
        }

        var calendar = Calendar.current
        calendar.timeZone = timezone

        let now = dateProvider()
        let lastReset = lastResetDate[user.id] ?? Date.distantPast

        // Check if we've crossed midnight in user's timezone
        if !calendar.isDate(now, inSameDayAs: lastReset) {
            alertsSentToday[user.id] = 0
            lastResetDate[user.id] = now
            // Persist the reset state immediately so it survives app restarts
            await persistCounters()
        }
    }

    /// Get number of alerts sent today for a specific user
    func getAlertsSentToday(for userId: UUID) async -> Int {
        await ensureCountersLoaded()
        return alertsSentToday[userId] ?? 0
    }

    private func incrementAlertCounter(for userId: UUID) async {
        await ensureCountersLoaded()
        let current = alertsSentToday[userId] ?? 0
        alertsSentToday[userId] = current + 1
        await persistCounters()
    }

    // MARK: - Persistence

    private func ensureCountersLoaded() async {
        if hasLoadedPersistedCounters {
            return
        }

        await loadPersistedCounters()
        hasLoadedPersistedCounters = true
    }

    private func loadPersistedCounters() async {
        var restoredCounters: [UUID: Int] = [:]
        if let counterData = userDefaults.data(forKey: "alertCounters") {
            do {
                let decoded = try JSONDecoder().decode([String: Int].self, from: counterData)
                for (key, value) in decoded {
                    guard let uuid = UUID(uuidString: key) else {
                        logger.warning("Invalid UUID in alert counters: \(key, privacy: .public)")
                        continue
                    }
                    restoredCounters[uuid] = value
                }
            } catch {
                logger.error("Failed to decode alert counters: \(error.localizedDescription, privacy: .public)")
                userDefaults.removeObject(forKey: "alertCounters")
            }
        }

        var restoredResetDates: [UUID: Date] = [:]
        if let resetData = userDefaults.data(forKey: "lastResetDates") {
            do {
                let decoded = try JSONDecoder().decode([String: Date].self, from: resetData)
                for (key, value) in decoded {
                    guard let uuid = UUID(uuidString: key) else {
                        logger.warning("Invalid UUID in reset dates: \(key, privacy: .public)")
                        continue
                    }
                    restoredResetDates[uuid] = value
                }
            } catch {
                logger.error("Failed to decode reset dates: \(error.localizedDescription, privacy: .public)")
                userDefaults.removeObject(forKey: "lastResetDates")
            }
        }

        alertsSentToday = restoredCounters
        lastResetDate = restoredResetDates

        logger.info("Loaded persisted alert counters: \(self.alertsSentToday.count) users")
    }

    /// Reload persisted alert counters and reset dates (primarily for testing support).
    func refreshPersistedCounters() async {
        hasLoadedPersistedCounters = false
        await ensureCountersLoaded()
    }

    private func persistCounters() async {
        // Save alert counters
        var counterDict: [String: Int] = [:]
        for (key, value) in alertsSentToday {
            counterDict[key.uuidString] = value
        }

        do {
            let encoded = try JSONEncoder().encode(counterDict)
            userDefaults.set(encoded, forKey: "alertCounters")
        } catch {
            logger.error("Failed to encode alert counters: \(error.localizedDescription, privacy: .public)")
        }

        // Save last reset dates
        var resetDict: [String: Date] = [:]
        for (key, value) in lastResetDate {
            resetDict[key.uuidString] = value
        }

        do {
            let encoded = try JSONEncoder().encode(resetDict)
            userDefaults.set(encoded, forKey: "lastResetDates")
        } catch {
            logger.error("Failed to encode reset dates: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Deduplication Cache

private class DeduplicationCache {
    // Use a simple dictionary for reliable storage
    // Since AlertService is an actor, access to this dictionary is thread-safe
    private var cache: [String: Date] = [:]

    func markAlertSent(key: String, date: Date) {
        cache[key] = date
    }

    func wasRecentlySent(key: String, within hours: TimeInterval, now: Date) -> Bool {
        guard let lastSent = cache[key] else {
            return false
        }
        return now.timeIntervalSince(lastSent) < hours * 3600
    }
}
