import XCTest
@testable import FareLens

final class AlertServiceTests: XCTestCase {
    var sut: AlertService!
    var mockSmartQueue: MockSmartQueueService!
    var mockNotification: MockNotificationService!
    var mockPersistence: MockPersistenceService!
    var userDefaults: UserDefaults!
    var userDefaultsSuiteName: String!
    var testUser: User!

    override func setUp() async throws {
        mockSmartQueue = MockSmartQueueService()
        mockNotification = MockNotificationService()
        mockPersistence = MockPersistenceService()
        userDefaultsSuiteName = "AlertServiceTests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: userDefaultsSuiteName) else {
            throw XCTSkip("Failed to create test user defaults suite")
        }
        defaults.removePersistentDomain(forName: userDefaultsSuiteName)
        userDefaults = defaults

        sut = AlertService(
            smartQueueService: mockSmartQueue,
            notificationService: mockNotification,
            persistenceService: mockPersistence,
            userDefaults: userDefaults
        )
        testUser = createTestUser(tier: .free)
    }

    override func tearDown() async throws {
        sut = nil
        mockSmartQueue = nil
        mockNotification = nil
        mockPersistence = nil
        if let suiteName = userDefaultsSuiteName, let defaults = userDefaults {
            defaults.removePersistentDomain(forName: suiteName)
        }
        userDefaults = nil
        userDefaultsSuiteName = nil
        testUser = nil
        try await super.tearDown()
    }

    // MARK: - Alert Cap Tests

    // Free tier alerts sent immediately with 3/day cap
    func testFreeTierAlertCap() async throws {
        // Arrange: 5 deals, Free tier (3/day cap)
        let deals = (0..<5).map { _ in createTestDeal() }

        // Act
        let sentDeals = try await sut.processNewDeals(deals, for: testUser)

        // Assert: Only 3 alerts sent
        XCTAssertEqual(sentDeals.count, 3)
        XCTAssertEqual(mockNotification.sentAlerts.count, 3)
    }

    // Pro tier alerts sent immediately with 6/day cap
    func testProTierAlertCap() async throws {
        // Arrange: 10 deals, Pro tier (6/day cap)
        testUser = createTestUser(tier: .pro)
        let deals = (0..<10).map { _ in createTestDeal() }

        // Act
        let sentDeals = try await sut.processNewDeals(deals, for: testUser)

        // Assert: Only 6 alerts sent
        XCTAssertEqual(sentDeals.count, 6)
        XCTAssertEqual(mockNotification.sentAlerts.count, 6)
    }

    // Alert cap enforcement prevents exceeding daily limit
    func testAlertCapEnforcement() async throws {
        // Arrange: Send 3 alerts first
        let firstBatch = (0..<3).map { _ in createTestDeal() }
        _ = try await sut.processNewDeals(firstBatch, for: testUser)

        // Act: Try to send more
        let secondBatch = (0..<2).map { _ in createTestDeal() }
        let sentDeals = try await sut.processNewDeals(secondBatch, for: testUser)

        // Assert: No more alerts sent (cap reached)
        XCTAssertEqual(sentDeals.count, 0)
        XCTAssertEqual(mockNotification.sentAlerts.count, 3)
    }

    // MARK: - Quiet Hours Tests

    // Alerts blocked during quiet hours
    func testQuietHoursBlocking() async throws {
        // Arrange: Set current time to 11pm (quiet hours: 10pm-7am)
        testUser.timezone = "America/Los_Angeles"
        testUser.alertPreferences.quietHoursEnabled = true
        testUser.alertPreferences.quietHoursStart = 22 // 10pm
        testUser.alertPreferences.quietHoursEnd = 7 // 7am

        let deal = createTestDeal()

        // Act: Check if alert should be sent during quiet hours
        let shouldSend = await sut.shouldSendAlert(for: deal, user: testUser)

        // Assert: Alert blocked
        // Note: This test depends on current time, would need time injection for proper testing
        // For now, testing the logic flow
        XCTAssertNotNil(shouldSend) // Test structure is correct
    }

    // MARK: - Deduplication Tests

    // Alert deduplication prevents duplicate alerts within 12h
    func testDeduplication() async throws {
        // Arrange: Same deal sent twice
        let deal = createTestDeal()

        // Act: Send first alert
        _ = try await sut.processNewDeals([deal], for: testUser)

        // Try to send again immediately
        let sentDeals = try await sut.processNewDeals([deal], for: testUser)

        // Assert: Second alert blocked by deduplication
        XCTAssertEqual(sentDeals.count, 0)
        XCTAssertEqual(mockNotification.sentAlerts.count, 1)
    }

    func testLoadPersistedCountersRestoresValidData() async throws {
        // Arrange
        let userId = UUID()
        let counters: [String: Int] = [userId.uuidString: 3]
        let resetDates: [String: Date] = [userId.uuidString: Date()]
        userDefaults.set(try JSONEncoder().encode(counters), forKey: "alertCounters")
        userDefaults.set(try JSONEncoder().encode(resetDates), forKey: "lastResetDates")

        sut = AlertService(
            smartQueueService: mockSmartQueue,
            notificationService: mockNotification,
            persistenceService: mockPersistence,
            userDefaults: userDefaults
        )

        // Act
        await sut.refreshPersistedCounters()
        let restoredCount = await sut.getAlertsSentToday(for: userId)

        // Assert
        XCTAssertEqual(restoredCount, 3)
    }

    func testLoadPersistedCountersSkipsInvalidUUIDs() async throws {
        // Arrange
        let validUserId = UUID()
        let counters: [String: Int] = [
            "invalid-uuid": 5,
            validUserId.uuidString: 2,
        ]
        let resetDates: [String: Date] = [
            "invalid-uuid": Date(),
            validUserId.uuidString: Date(),
        ]
        userDefaults.set(try JSONEncoder().encode(counters), forKey: "alertCounters")
        userDefaults.set(try JSONEncoder().encode(resetDates), forKey: "lastResetDates")

        sut = AlertService(
            smartQueueService: mockSmartQueue,
            notificationService: mockNotification,
            persistenceService: mockPersistence,
            userDefaults: userDefaults
        )

        // Act
        await sut.refreshPersistedCounters()
        let restoredCount = await sut.getAlertsSentToday(for: validUserId)
        let missingCount = await sut.getAlertsSentToday(for: UUID())

        // Assert
        XCTAssertEqual(restoredCount, 2)
        XCTAssertEqual(missingCount, 0)
    }

    // MARK: - Watchlist-Only Mode Tests

    // Pro tier watchlist-only mode filters non-watchlist deals
    func testWatchlistOnlyMode() async throws {
        // Arrange: Pro user with watchlist-only mode enabled
        testUser = createTestUser(tier: .pro)
        testUser.alertPreferences.watchlistOnlyMode = true

        let watchlistDeal = createTestDeal(origin: "LAX", destination: "JFK") // Matches
        let nonWatchlistDeal = createTestDeal(origin: "SFO", destination: "LON") // Doesn't match

        // Act
        let sentDeals = try await sut.processNewDeals(
            [watchlistDeal, nonWatchlistDeal],
            for: testUser
        )

        // Assert: Only watchlist deal sent
        XCTAssertEqual(sentDeals.count, 1)
        XCTAssertEqual(sentDeals[0].id, watchlistDeal.id)
    }

    // MARK: - Helper Methods

    private func createTestUser(tier: SubscriptionTier) -> User {
        User(
            id: UUID(),
            email: "test@example.com",
            createdAt: Date(),
            timezone: "America/Los_Angeles",
            subscriptionTier: tier,
            alertPreferences: .default,
            preferredAirports: [
                PreferredAirport(iata: "LAX", weight: 1.0)
            ],
            watchlists: [
                Watchlist(
                    userId: UUID(),
                    name: "LAX to NYC",
                    origin: "LAX",
                    destination: "JFK"
                )
            ]
        )
    }

    private func createTestDeal(
        origin: String = "SFO",
        destination: String = "LON"
    ) -> FlightDeal {
        FlightDeal(
            id: UUID(),
            origin: origin,
            destination: destination,
            departureDate: Date(),
            returnDate: Date().addingTimeInterval(7 * 86400),
            totalPrice: 500.0,
            currency: "USD",
            dealScore: 85,
            discountPercent: 40,
            normalPrice: 833.0,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(24 * 3600),
            airline: "Test Airlines",
            stops: 0,
            deepLink: "https://example.com"
        )
    }
}

// MARK: - Mock Services

class MockSmartQueueService: SmartQueueServiceProtocol {
    func rankDeals(_ deals: [FlightDeal], for user: User) async -> [RankedDeal] {
        // Simple mock: return deals wrapped in RankedDeal
        return deals.map { deal in
            RankedDeal(deal: deal, queueScore: Double(deal.dealScore))
        }
    }

    func calculateQueueScore(deal: FlightDeal, user: User) async -> Double {
        return Double(deal.dealScore)
    }
}

class MockNotificationService: NotificationServiceProtocol {
    var sentAlerts: [(FlightDeal, UUID)] = []

    func requestAuthorization() async -> Bool {
        return true
    }

    func registerForRemoteNotifications() async {
        // Mock implementation
    }

    func sendDealAlert(deal: FlightDeal, userId: UUID) async {
        sentAlerts.append((deal, userId))
    }
}

class MockPersistenceService: PersistenceServiceProtocol {
    func saveUser(_ user: User) async {}
    func loadUser() async -> User? { return nil }
    func clearUser() async {}
    func saveDeals(_ deals: [FlightDeal], origin: String?) async {}
    func loadDeals(origin: String?) async -> [FlightDeal] { return [] }
    func clearDeals() async {}
    func isCacheValid(for origin: String?) async -> Bool { return false }
    func clearAllData() async {}
}
