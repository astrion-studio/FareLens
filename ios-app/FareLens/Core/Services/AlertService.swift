import Foundation
import OSLog

protocol AlertServiceProtocol {
    func processNewDeals(_ deals: [FlightDeal], for user: User) async throws -> [FlightDeal]
    func shouldSendAlert(for deal: FlightDeal, user: User) async -> Bool
    func getAlertsSentToday(for userId: UUID) async -> Int
}

actor AlertService: AlertServiceProtocol {
    static let shared = AlertService()

    private let smartQueueService: SmartQueueService
    private let notificationService: NotificationService
    private let persistenceService: PersistenceService
    private let logger = Logger(subsystem: "com.farelens.app", category: "alerts")
    private let userDefaults = UserDefaults.standard

    private var alertsSentToday: [UUID: Int] = [:] // userId: count
    private var lastResetDate: [UUID: Date] = [:] // Per-user reset tracking
    private let deduplicationCache = DeduplicationCache()

    init(
        smartQueueService: SmartQueueService = .shared,
        notificationService: NotificationService = .shared,
        persistenceService: PersistenceService = .shared
    ) {
        self.smartQueueService = smartQueueService
        self.notificationService = notificationService
        self.persistenceService = persistenceService

        // Load persisted counters on init
        Task { await loadPersistedCounters() }
    }

    /// Process new deals and send alerts immediately (respecting caps and quiet hours)
    func processNewDeals(_ deals: [FlightDeal], for user: User) async throws -> [FlightDeal] {
        // Reset daily counter if needed
        await resetDailyCounterIfNeeded(for: user)

        // Check if user has reached daily alert cap
        let alertsSent = await getAlertsSentToday(for: user.id)
        let remainingAlerts = user.maxAlertsPerDay - alertsSent

        guard remainingAlerts > 0 else {
            return [] // User has reached daily cap
        }

        // Filter deals based on user preferences
        var filteredDeals = deals.filter { deal in
            // Apply watchlist-only mode if enabled (Pro feature)
            if user.alertPreferences.watchlistOnlyMode {
                return user.watchlists.contains { $0.matches(deal) }
            }
            return true
        }

        // Rank deals using smart queue algorithm
        let rankedDeals = await smartQueueService.rankDeals(filteredDeals, for: user)

        // Take only up to remaining alerts
        let dealsToAlert = Array(rankedDeals.prefix(remainingAlerts))

        // Send alerts (respecting quiet hours and deduplication)
        var sentDeals: [FlightDeal] = []
        for rankedDeal in dealsToAlert {
            if await shouldSendAlert(for: rankedDeal.deal, user: user) {
                await sendAlert(for: rankedDeal.deal, user: user)
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
        if deduplicationCache.wasRecentlySent(key: dedupeKey, within: 12) {
            return false
        }

        return true
    }

    // MARK: - Private Methods

    private func sendAlert(for deal: FlightDeal, user: User) async {
        // Send push notification
        await notificationService.sendDealAlert(deal: deal, userId: user.id)

        // Update counters
        let dedupeKey = "\(user.id.uuidString)-\(deal.id.uuidString)"
        deduplicationCache.markAlertSent(key: dedupeKey, date: Date())

        await incrementAlertCounter(for: user.id)
    }

    private func isQuietHours(for user: User) async -> Bool {
        let timezone: TimeZone
        if let userTimezone = TimeZone(identifier: user.timezone) {
            timezone = userTimezone
        } else {
            logger.warning("Invalid timezone '\(user.timezone, privacy: .public)', falling back to device timezone")
            timezone = TimeZone.current
        }

        return user.alertPreferences.isQuietHour(at: Date(), timezone: timezone)
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

        let now = Date()
        let lastReset = lastResetDate[user.id] ?? Date.distantPast

        // Check if we've crossed midnight in user's timezone
        if !calendar.isDate(now, inSameDayAs: lastReset) {
            alertsSentToday[user.id] = 0
            lastResetDate[user.id] = now
        }
    }

    /// Get number of alerts sent today for a specific user
    func getAlertsSentToday(for userId: UUID) async -> Int {
        alertsSentToday[userId] ?? 0
    }

    private func incrementAlertCounter(for userId: UUID) async {
        let current = alertsSentToday[userId] ?? 0
        alertsSentToday[userId] = current + 1
        await persistCounters()
    }

    // MARK: - Persistence

    private func loadPersistedCounters() async {
        // Load alert counters
        if let counterData = userDefaults.data(forKey: "alertCounters"),
           let decoded = try? JSONDecoder().decode([String: Int].self, from: counterData) {
            alertsSentToday = decoded.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else {
                    logger.warning("Invalid UUID in alert counters: \(key, privacy: .public)")
                    return nil
                }
                return (uuid, value)
            }.reduce(into: [:]) { $0[$1.0] = $1.1 }
        }

        // Load last reset dates
        if let resetData = userDefaults.data(forKey: "lastResetDates"),
           let decoded = try? JSONDecoder().decode([String: Date].self, from: resetData) {
            lastResetDate = decoded.compactMap { key, value in
                guard let uuid = UUID(uuidString: key) else {
                    logger.warning("Invalid UUID in reset dates: \(key, privacy: .public)")
                    return nil
                }
                return (uuid, value)
            }.reduce(into: [:]) { $0[$1.0] = $1.1 }
        }

        logger.info("Loaded persisted alert counters: \(self.alertsSentToday.count) users")
    }

    private func persistCounters() async {
        // Save alert counters
        let counterDict = Dictionary(uniqueKeysWithValues: alertsSentToday.map { ($0.key.uuidString, $0.value) })
        if let encoded = try? JSONEncoder().encode(counterDict) {
            userDefaults.set(encoded, forKey: "alertCounters")
        }

        // Save last reset dates
        let resetDict = Dictionary(uniqueKeysWithValues: lastResetDate.map { ($0.key.uuidString, $0.value) })
        if let encoded = try? JSONEncoder().encode(resetDict) {
            userDefaults.set(encoded, forKey: "lastResetDates")
        }
    }
}

// MARK: - Deduplication Cache

private class DeduplicationCache {
    private let cache = NSCache<NSString, NSDate>()

    init() {
        cache.countLimit = 10000 // Max 10k entries
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB
    }

    func markAlertSent(key: String, date: Date) {
        cache.setObject(date as NSDate, forKey: key as NSString)
    }

    func wasRecentlySent(key: String, within hours: TimeInterval) -> Bool {
        guard let lastSent = cache.object(forKey: key as NSString) as Date? else {
            return false
        }
        return Date().timeIntervalSince(lastSent) < hours * 3600
    }
}
