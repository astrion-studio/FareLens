import XCTest
@testable import FareLens

final class DealsRepositoryTests: XCTestCase {
    var sut: DealsRepository!
    var mockAPIClient: MockAPIClient!
    var mockPersistence: MockPersistenceServiceForDeals!
    var mockSmartQueue: MockSmartQueueService!

    override func setUp() async throws {
        mockAPIClient = MockAPIClient()
        mockPersistence = MockPersistenceServiceForDeals()
        mockSmartQueue = MockSmartQueueService()
        sut = DealsRepository(
            apiClient: mockAPIClient,
            persistenceService: mockPersistence,
            smartQueueService: mockSmartQueue
        )
    }

    // MARK: - 20-Deal Algorithm Tests

    // Free tier shows all deals with score ≥80
    func test20DealAlgorithm_ShowsAllExcellentDeals() async throws {
        // Arrange: 15 deals with score ≥80
        let user = createTestUser(tier: .free)
        let deals = (0..<15).map { _ in createTestDeal(score: 85) }

        // Act
        let result = await sut.applySmartQueue(deals, for: user)

        // Assert: All 15 deals shown (less than 20)
        XCTAssertEqual(result.count, 15)
    }

    // Free tier removes lowest scores when >20 deals with score ≥80
    func test20DealAlgorithm_RemovesLowestWhenOver20() async throws {
        // Arrange: 25 deals with score ≥80
        let user = createTestUser(tier: .free)
        let deals = (0..<25).map { i in
            createTestDeal(score: 80 + i) // Scores 80-104
        }

        // Act
        let result = await sut.applySmartQueue(deals, for: user)

        // Assert: Only 20 deals shown (highest scores kept)
        XCTAssertEqual(result.count, 20)
    }

    // Free tier backfills with score ≥70 when <20 deals with score ≥80
    func test20DealAlgorithm_BackfillsWithGoodDeals() async throws {
        // Arrange: 10 excellent (≥80) + 15 good (≥70) deals
        let user = createTestUser(tier: .free)
        var deals: [FlightDeal] = []
        deals.append(contentsOf: (0..<10).map { _ in createTestDeal(score: 85) })
        deals.append(contentsOf: (0..<15).map { _ in createTestDeal(score: 75) })

        // Act
        let result = await sut.applySmartQueue(deals, for: user)

        // Assert: 20 deals shown (10 excellent + 10 backfilled good)
        XCTAssertEqual(result.count, 20)
    }

    // Pro tier sees all deals regardless of score
    func testProTier_SeesAllDeals() async throws {
        // Arrange: 50 deals with varying scores
        let user = createTestUser(tier: .pro)
        let deals = (0..<50).map { i in createTestDeal(score: 60 + i % 40) }

        // Act
        let result = await sut.applySmartQueue(deals, for: user)

        // Assert: All 50 deals shown
        XCTAssertEqual(result.count, 50)
    }

    // MARK: - Cache Tests

    // Deals fetched from cache when valid
    func testCacheFetch_WhenValid() async throws {
        // Arrange: Cache is valid with realistic test data
        mockPersistence.isCacheValidFlag = true
        let testDeal = createTestDeal()
        mockPersistence.cachedDeals = [testDeal]

        // Act
        let deals = try await sut.fetchDeals(forceRefresh: false)

        // Assert: Deals from cache, no API call
        XCTAssertEqual(deals.count, 1)
        XCTAssertEqual(deals.first?.id, testDeal.id)
        XCTAssertEqual(deals.first?.origin, "LAX")
        XCTAssertEqual(mockAPIClient.requestCount, 0)
    }

    // Deals fetched from API when cache invalid
    func testAPIFetch_WhenCacheInvalid() async throws {
        // Arrange: Cache is invalid, mock will return test deals
        mockPersistence.isCacheValidFlag = false
        let testDeals = [createTestDeal(), createTestDeal(score: 90)]
        mockAPIClient.mockDeals = testDeals

        // Act
        let deals = try await sut.fetchDeals(forceRefresh: false)

        // Assert: API called and deals returned
        XCTAssertEqual(mockAPIClient.requestCount, 1)
        XCTAssertEqual(deals.count, 2)
        XCTAssertEqual(deals.first?.origin, "LAX")
    }

    // Force refresh ignores cache
    func testForceRefresh_IgnoresCache() async throws {
        // Arrange: Cache is valid but force refresh requested
        mockPersistence.isCacheValidFlag = true
        mockPersistence.cachedDeals = [createTestDeal()]
        let freshDeals = [createTestDeal(score: 95)]
        mockAPIClient.mockDeals = freshDeals

        // Act
        let deals = try await sut.fetchDeals(forceRefresh: true)

        // Assert: API called despite valid cache, fresh deals returned
        XCTAssertEqual(mockAPIClient.requestCount, 1)
        XCTAssertEqual(deals.count, 1)
        XCTAssertEqual(deals.first?.dealScore, 95)
    }

    // MARK: - Concurrency Tests

    /// Test concurrent access to DealsRepository actor is properly serialized
    /// Fixes Issue #12: Verifies actor isolation prevents race conditions
    func testConcurrentFetchDeals_SerializedProperly() async throws {
        // Arrange: Mock returns test deals
        mockPersistence.isCacheValidFlag = false
        let testDeals = [createTestDeal()]
        mockAPIClient.mockDeals = testDeals

        // Act: Call fetchDeals concurrently from multiple tasks
        async let result1 = sut.fetchDeals(forceRefresh: false)
        async let result2 = sut.fetchDeals(forceRefresh: false)
        async let result3 = sut.fetchDeals(forceRefresh: false)

        let (deals1, deals2, deals3) = try await (result1, result2, result3)

        // Assert: All calls completed successfully (no crashes or data corruption)
        XCTAssertEqual(deals1.count, 1)
        XCTAssertEqual(deals2.count, 1)
        XCTAssertEqual(deals3.count, 1)
        // Each concurrent call should have incremented the request count
        XCTAssertEqual(mockAPIClient.requestCount, 3)
    }

    /// Test concurrent cache operations don't corrupt state
    /// Fixes Issue #12: Verifies cache consistency under concurrent access
    func testConcurrentCacheAccess_RemainsConsistent() async throws {
        // Arrange: Cache starts invalid
        mockPersistence.isCacheValidFlag = false
        let deal1 = createTestDeal(score: 80)
        let deal2 = createTestDeal(score: 90)
        mockAPIClient.mockDeals = [deal1, deal2]

        // Act: Concurrent reads and cache validity checks
        async let fetch1 = sut.fetchDeals(forceRefresh: false)
        async let fetch2 = sut.fetchDeals(forceRefresh: true)

        let (result1, result2) = try await (fetch1, fetch2)

        // Assert: Both calls got correct data, no race conditions
        XCTAssertEqual(result1.count, 2)
        XCTAssertEqual(result2.count, 2)
        // Verify cache was updated correctly by checking persistence
        let cached = await mockPersistence.loadDeals(origin: nil)
        XCTAssertEqual(cached.count, 2)
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
            watchlists: []
        )
    }

    private func createTestDeal(score: Int = 85) -> FlightDeal {
        FlightDeal(
            id: UUID(),
            origin: "LAX",
            destination: "JFK",
            departureDate: Date(),
            returnDate: Date().addingTimeInterval(7 * 86400),
            totalPrice: 500.0,
            currency: "USD",
            dealScore: score,
            discountPercent: 40,
            normalPrice: 833.0,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(24 * 3600),
            airline: "Test Airlines",
            stops: 0,
            returnStops: 0,
            deepLink: "https://example.com"
        )
    }
}

// MARK: - Mock API Client

/// Mock API client with configurable responses for testing
/// Fixes Issues #3, #5, #6, #10: Realistic data, configurable responses, safe casting, JSON decoding simulation
class MockAPIClient: APIClientProtocol {
    var requestCount = 0
    var mockDeals: [FlightDeal] = []
    var shouldThrowError: APIError?

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestCount += 1

        // Allow test to configure error responses
        if let error = shouldThrowError {
            throw error
        }

        // Simulate JSON decoding process like real APIClient
        // Fixes Issue #10: Tests now catch JSON decoding issues
        if T.self == DealsResponse.self {
            let response = DealsResponse(deals: mockDeals)

            // Simulate encoding/decoding round-trip to catch issues
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.keyEncodingStrategy = .convertToSnakeCase

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            do {
                let data = try encoder.encode(response)
                let decodedResponse = try decoder.decode(DealsResponse.self, from: data)

                guard let result = decodedResponse as? T else {
                    throw APIError.invalidResponse
                }
                return result
            } catch {
                // Catch encoding/decoding errors that would occur with real API
                throw APIError.decodingError(error)
            }
        }

        throw APIError.invalidResponse
    }

    func requestNoResponse(_ endpoint: APIEndpoint) async throws {
        requestCount += 1

        if let error = shouldThrowError {
            throw error
        }
    }
}

// MARK: - Mock Persistence Service

/// Mock persistence service for testing deals repository
/// Fixes Issue #11: Consistent cache key logic documented
class MockPersistenceServiceForDeals: PersistenceServiceProtocol {
    var isCacheValidFlag: Bool = false
    var cachedDealsByOrigin: [String: [FlightDeal]] = [:]

    /// Generate cache key for origin (uppercase IATA code or "__ALL__" for all deals)
    private func key(for origin: String?) -> String {
        origin?.uppercased() ?? "__ALL__"
    }

    var cachedDeals: [FlightDeal] {
        get { cachedDealsByOrigin[key(for: nil)] ?? [] }
        set { cachedDealsByOrigin[key(for: nil)] = newValue }
    }

    func saveUser(_ user: User) async {}
    func loadUser() async -> User? { nil }
    func clearUser() async {}

    func saveDeals(_ deals: [FlightDeal], origin: String?) async {
        cachedDealsByOrigin[key(for: origin)] = deals
    }

    func loadDeals(origin: String?) async -> [FlightDeal] {
        cachedDealsByOrigin[key(for: origin)] ?? []
    }

    func clearDeals() async {}
    func isCacheValid(for origin: String?) async -> Bool { isCacheValidFlag }
    func saveAlerts(_ alerts: [AlertHistory]) async {}
    func loadAlerts() async -> [AlertHistory] { [] }
    func isAlertCacheValid() async -> Bool { false }
    func clearAllData() async {}
}
