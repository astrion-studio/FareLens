import XCTest
@testable import FareLens

final class SmartQueueServiceTests: XCTestCase {
    var sut: SmartQueueService!
    var testUser: User!

    override func setUp() async throws {
        try await super.setUp()
        sut = await MainActor.run { SmartQueueService() }
        testUser = createTestUser()
    }

    // MARK: - Test Smart Queue Formula

    // Smart queue calculates score correctly with watchlist boost and airport weight
    func testCalculateQueueScore_WithWatchlistAndAirport() async throws {
        // Arrange: Deal matches watchlist + preferred airport
        let deal = createTestDeal(
            origin: "LAX",
            destination: "JFK",
            dealScore: 85
        )

        // Act
        let score = await sut.calculateQueueScore(deal: deal, user: testUser)

        // Assert: 85 × (1 + 0.2) × (1 + 0.6) = 163.2
        XCTAssertEqual(score, 163.2, accuracy: 0.01)
    }

    // Smart queue calculates score correctly without watchlist boost
    func testCalculateQueueScore_NoWatchlist() async throws {
        // Arrange: Deal doesn't match watchlist
        let deal = createTestDeal(
            origin: "SFO",
            destination: "LON",
            dealScore: 90
        )

        // Act
        let score = await sut.calculateQueueScore(deal: deal, user: testUser)

        // Assert: 90 × (1 + 0) × (1 + 0) = 90.0
        XCTAssertEqual(score, 90.0, accuracy: 0.01)
    }

    // Smart queue applies airport weight correctly
    func testCalculateQueueScore_AirportWeightOnly() async throws {
        // Arrange: Deal from preferred airport but no watchlist match
        let deal = createTestDeal(
            origin: "LAX",
            destination: "LON",
            dealScore: 80
        )

        // Act
        let score = await sut.calculateQueueScore(deal: deal, user: testUser)

        // Assert: 80 × (1 + 0) × (1 + 0.6) = 128.0
        XCTAssertEqual(score, 128.0, accuracy: 0.01)
    }

    // MARK: - Test Ranking Algorithm

    // Smart queue ranks deals by score (highest first)
    func testRankDeals_ByScore() async throws {
        // Arrange
        let deal1 = createTestDeal(origin: "LAX", destination: "JFK", dealScore: 85) // 163.2
        let deal2 = createTestDeal(origin: "SFO", destination: "LON", dealScore: 90) // 90.0
        let deal3 = createTestDeal(origin: "LAX", destination: "PAR", dealScore: 80) // 128.0

        // Act
        let ranked = await sut.rankDeals([deal1, deal2, deal3], for: testUser)
        let rankedIDs = ranked.map(\.id)

        // Assert: Order should be deal1 (163.2), deal3 (128.0), deal2 (90.0)
        XCTAssertEqual(rankedIDs, [deal1.id, deal3.id, deal2.id])
    }

    // Smart queue applies tiebreaker by price when scores equal
    func testRankDeals_TiebreakerByPrice() async throws {
        // Arrange: Same score, different prices
        let deal1 = createTestDeal(
            origin: "SFO",
            destination: "LON",
            dealScore: 90,
            price: 550.0
        )
        let deal2 = createTestDeal(
            origin: "SFO",
            destination: "PAR",
            dealScore: 90,
            price: 480.0
        )

        // Act
        let ranked = await sut.rankDeals([deal1, deal2], for: testUser)
        let rankedIDs = ranked.map(\.id)

        // Assert: deal2 should be first (lower price)
        XCTAssertEqual(rankedIDs, [deal2.id, deal1.id])
    }

    // Smart queue applies tiebreaker by date when scores and prices equal
    func testRankDeals_TiebreakerByDate() async throws {
        // Arrange: Same score and price, different dates
        let deal1 = createTestDeal(
            origin: "SFO",
            destination: "LON",
            dealScore: 90,
            price: 500.0,
            departureDate: Date().addingTimeInterval(7 * 86400) // 7 days
        )
        let deal2 = createTestDeal(
            origin: "SFO",
            destination: "PAR",
            dealScore: 90,
            price: 500.0,
            departureDate: Date().addingTimeInterval(3 * 86400) // 3 days
        )

        // Act
        let ranked = await sut.rankDeals([deal1, deal2], for: testUser)
        let rankedIDs = ranked.map(\.id)

        // Assert: deal2 should be first (sooner departure)
        XCTAssertEqual(rankedIDs, [deal2.id, deal1.id])
    }

    // MARK: - Test Examples from ARCHITECTURE.md

    // Example 1: Watchlist priority
    func testExample1_WatchlistPriority() async throws {
        // Deal: LAX→NYC, $450, DealScore 85
        // Calculation: 85 × (1 + 0.2) × (1 + 0.6) = 163.2
        let score = SmartQueueService.example1()
        XCTAssertEqual(score, 163.2, accuracy: 0.01)
    }

    // Example 2: No watchlist match
    func testExample2_NoWatchlistMatch() async throws {
        // Deal: SFO→London, $380, DealScore 90
        // Calculation: 90 × (1 + 0) × (1 + 0) = 90.0
        let score = SmartQueueService.example2()
        XCTAssertEqual(score, 90.0, accuracy: 0.01)
    }

    // MARK: - Helper Methods

    private func createTestUser() -> User {
        User(
            id: UUID(),
            email: "test@example.com",
            createdAt: Date(),
            timezone: "America/Los_Angeles",
            subscriptionTier: .free,
            alertPreferences: .default,
            preferredAirports: [
                PreferredAirport(iata: "LAX", weight: 0.6),
                PreferredAirport(iata: "JFK", weight: 0.3),
                PreferredAirport(iata: "ORD", weight: 0.1)
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
        origin: String,
        destination: String,
        dealScore: Int,
        price: Double = 500.0,
        departureDate: Date = Date(),
        returnStops: Int? = 0
    ) -> FlightDeal {
        FlightDeal(
            id: UUID(),
            origin: origin,
            destination: destination,
            departureDate: departureDate,
            returnDate: departureDate.addingTimeInterval(7 * 86400),
            totalPrice: price,
            currency: "USD",
            dealScore: dealScore,
            discountPercent: 40,
            normalPrice: price * 1.67,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(24 * 3600),
            airline: "Test Airlines",
            stops: 0,
            returnStops: returnStops,
            deepLink: "https://example.com"
        )
    }
}
