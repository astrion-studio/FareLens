// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

@testable import FareLens
import XCTest

final class SavedDealsRepositoryTests: XCTestCase {
    var userDefaults: UserDefaults!
    var sut: SavedDealsRepository!

    override func setUp() async throws {
        userDefaults = UserDefaults(suiteName: "SavedDealsRepositoryTests")
        userDefaults.removePersistentDomain(forName: "SavedDealsRepositoryTests")
        sut = SavedDealsRepository(userDefaults: userDefaults, storageKey: "saved_deals_test")
    }

    override func tearDown() async throws {
        userDefaults.removePersistentDomain(forName: "SavedDealsRepositoryTests")
        userDefaults = nil
        sut = nil
    }

    func testSaveDealPersists() async throws {
        let deal = sampleDeal()

        try await sut.saveDeal(deal)

        let saved = await sut.allSavedDeals()
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.id, deal.id)
        let isSaved = await sut.isDealSaved(deal.id)
        XCTAssertTrue(isSaved)
    }

    func testRemoveDealClearsStorage() async throws {
        let deal = sampleDeal()
        try await sut.saveDeal(deal)

        try await sut.removeDeal(deal.id)

        let saved = await sut.allSavedDeals()
        XCTAssertTrue(saved.isEmpty)
        let isSaved = await sut.isDealSaved(deal.id)
        XCTAssertFalse(isSaved)
    }

    // MARK: - Helpers

    private func sampleDeal() -> FlightDeal {
        FlightDeal(
            id: UUID(),
            origin: "SFO",
            destination: "CDG",
            departureDate: Date(),
            returnDate: Date().addingTimeInterval(7 * 86400),
            totalPrice: 780,
            currency: "USD",
            dealScore: 88,
            discountPercent: 28,
            normalPrice: 1083,
            createdAt: Date(),
            expiresAt: Date().addingTimeInterval(12 * 3600),
            airline: "Air France",
            stops: 0,
            returnStops: 0,
            deepLink: "https://example.com"
        )
    }
}
