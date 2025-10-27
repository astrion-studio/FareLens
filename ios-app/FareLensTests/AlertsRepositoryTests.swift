import XCTest
@testable import FareLens

final class AlertsRepositoryTests: XCTestCase {
    var mockAPI: MockAlertsAPIClient!
    var mockPersistence: MockAlertsPersistenceService!
    var sut: AlertsRepository!

    override func setUp() async throws {
        mockAPI = MockAlertsAPIClient()
        mockPersistence = MockAlertsPersistenceService()
        sut = AlertsRepository(
            apiClient: mockAPI,
            persistenceService: mockPersistence
        )
    }

    override func tearDown() async throws {
        mockAPI = nil
        mockPersistence = nil
        sut = nil
    }

    func testFetchAlertHistory_UsesAPIAndCachesResult() async throws {
        // Arrange
        let deal = sampleDeal()
        let alert = TestAlertHistory(
            id: UUID(),
            sentAt: Date(),
            openedAt: nil,
            clickedThrough: false,
            expiresAt: deal.expiresAt,
            deal: TestDealPayload(from: deal)
        )
        let response = TestAlertHistoryResponse(alerts: [alert])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        mockAPI.nextData = try encoder.encode(response)

        // Act
        let history = try await sut.fetchAlertHistory(forceRefresh: true)

        // Assert
        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.deal.origin, deal.origin)
        let cached = await mockPersistence.savedAlerts
        XCTAssertEqual(cached.count, 1)
        let apiCalls = await mockAPI.requestCount
        XCTAssertEqual(apiCalls, 1)
    }

    func testFetchAlertHistory_ReturnsCachedWhenValid() async throws {
        // Arrange
        let cachedAlert = AlertHistory(
            id: UUID(),
            deal: sampleDeal(),
            sentAt: Date(),
            wasClicked: false,
            expiresAt: nil
        )
        await mockPersistence.setCachedAlerts([cachedAlert], valid: true)

        // Act
        let history = try await sut.fetchAlertHistory()

        // Assert
        XCTAssertEqual(history.count, 1)
        let apiCalls = await mockAPI.requestCount
        XCTAssertEqual(apiCalls, 0)
    }

    // MARK: - Helpers

    private func sampleDeal() -> FlightDeal {
        FlightDeal(
            id: UUID(),
            origin: "LAX",
            destination: "JFK",
            departureDate: Date(),
            returnDate: Date().addingTimeInterval(4 * 86_400),
            totalPrice: 420,
            currency: "USD",
            dealScore: 92,
            discountPercent: 35,
            normalPrice: 646,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(6 * 3600),
            airline: "Delta",
            stops: 0,
            returnStops: 0,
            deepLink: "https://example.com"
        )
    }
}

// MARK: - Test Doubles

actor MockAlertsAPIClient: APIClientProtocol {
    var nextData: Data?
    private(set) var requestCount = 0

    func request<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
        requestCount += 1
        guard let data = nextData else {
            throw APIError.invalidResponse
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(T.self, from: data)
    }

    func requestNoResponse(_ endpoint: APIEndpoint) async throws {
        requestCount += 1
    }
}

actor MockAlertsPersistenceService: PersistenceServiceProtocol {
    private(set) var savedAlerts: [AlertHistory] = []
    private var cachedAlerts: [AlertHistory] = []
    private var cacheValid = false

    func setCachedAlerts(_ alerts: [AlertHistory], valid: Bool) {
        cachedAlerts = alerts
        cacheValid = valid
    }

    func saveUser(_ user: User) async {}
    func loadUser() async -> User? { nil }
    func clearUser() async {}
    func saveDeals(_ deals: [FlightDeal], origin: String?) async {}
    func loadDeals(origin: String?) async -> [FlightDeal] { [] }
    func clearDeals() async {}
    func isCacheValid(for origin: String?) async -> Bool { false }

    func saveAlerts(_ alerts: [AlertHistory]) async {
        savedAlerts = alerts
        cachedAlerts = alerts
        cacheValid = true
    }

    func loadAlerts() async -> [AlertHistory] {
        cachedAlerts
    }

    func clearAlerts() async {
        savedAlerts = []
        cachedAlerts = []
        cacheValid = false
    }

    func isAlertCacheValid() async -> Bool {
        cacheValid
    }

    func clearAllData() async {
        await clearAlerts()
    }
}

private struct TestAlertHistoryResponse: Codable {
    let alerts: [TestAlertHistory]
}

private struct TestAlertHistory: Codable {
    let id: UUID
    let sentAt: Date
    let openedAt: Date?
    let clickedThrough: Bool
    let expiresAt: Date?
    let deal: TestDealPayload
}

private struct TestDealPayload: Codable {
    let id: UUID
    let origin: String
    let destination: String
    let departureDate: Date
    let returnDate: Date
    let totalPrice: Double
    let currency: String
    let dealScore: Int
    let discountPercent: Int
    let normalPrice: Double
    let createdAt: Date
    let expiresAt: Date
    let airline: String
    let stops: Int
    let returnStops: Int?
    let deepLink: String

    init(from deal: FlightDeal) {
        id = deal.id
        origin = deal.origin
        destination = deal.destination
        departureDate = deal.departureDate
        returnDate = deal.returnDate
        totalPrice = deal.totalPrice
        currency = deal.currency
        dealScore = deal.dealScore
        discountPercent = deal.discountPercent
        normalPrice = deal.normalPrice
        createdAt = deal.createdAt
        expiresAt = deal.expiresAt
        airline = deal.airline
        stops = deal.stops
        returnStops = deal.returnStops
        deepLink = deal.deepLink
    }
}
