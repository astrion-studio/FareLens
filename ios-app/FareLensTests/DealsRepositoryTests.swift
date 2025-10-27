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
        // Arrange: Cache is valid
        mockPersistence.isCacheValidFlag = true
        mockPersistence.cachedDeals = [createTestDeal()]

        // Act
        let deals = try await sut.fetchDeals(forceRefresh: false)

        // Assert: Deals from cache
        XCTAssertEqual(deals.count, 1)
        XCTAssertEqual(mockAPIClient.requestCount, 0) // No API call
    }

    // Deals fetched from API when cache invalid
    func testAPIFetch_WhenCacheInvalid() async throws {
        // Arrange: Cache is invalid
        mockPersistence.isCacheValidFlag = false

        // Act
        _ = try await sut.fetchDeals(forceRefresh: false)

        // Assert: API called
        XCTAssertEqual(mockAPIClient.requestCount, 1)
    }

    // Force refresh ignores cache
    func testForceRefresh_IgnoresCache() async throws {
        // Arrange: Cache is valid but force refresh
        mockPersistence.isCacheValidFlag = true
        mockPersistence.cachedDeals = [createTestDeal()]

        // Act
        _ = try await sut.fetchDeals(forceRefresh: true)

        // Assert: API called despite valid cache
        XCTAssertEqual(mockAPIClient.requestCount, 1)
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
            deepLink: "https://example.com"
        )
    }
}

// MARK: - Mock API Client

class MockAPIClient: APIClientProtocol {
    var requestCount = 0

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestCount += 1

        // Return mock response
        if T.self == DealsResponse.self {
            let response = DealsResponse(deals: [])
            return response as! T
        }

        throw APIError.invalidResponse
    }

    func requestNoResponse(_ endpoint: APIEndpoint) async throws {
        requestCount += 1
    }
}

struct DealsResponse: Codable {
    let deals: [FlightDeal]
}

// MockPersistenceService for testing (already defined in AlertServiceTests)
class MockPersistenceServiceForDeals: PersistenceServiceProtocol {
    var isCacheValidFlag: Bool = false
    var cachedDealsByOrigin: [String: [FlightDeal]] = [:]

    private func key(for origin: String?) -> String {
        origin?.uppercased() ?? "__ALL__"
    }

    var cachedDeals: [FlightDeal] {
        get { cachedDealsByOrigin[key(for: nil)] ?? [] }
        set { cachedDealsByOrigin[key(for: nil)] = newValue }
    }

    func saveUser(_ user: User) async {}
    func loadUser() async -> User? { return nil }
    func clearUser() async {}
    func saveDeals(_ deals: [FlightDeal], origin: String?) async {
        cachedDealsByOrigin[key(for: origin)] = deals
    }
    func loadDeals(origin: String?) async -> [FlightDeal] {
        cachedDealsByOrigin[key(for: origin)] ?? []
    }
    func clearDeals() async {}
    func isCacheValid(for origin: String?) async -> Bool { isCacheValidFlag }
    func clearAllData() async {}
}
