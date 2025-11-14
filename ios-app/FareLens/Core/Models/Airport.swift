// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation

/// Airport model for search and display
struct Airport: Codable, Identifiable, Hashable {
    let iata: String
    let name: String
    let city: String
    let state: String
    let country: String

    var id: String { iata }

    /// Display text combining code, city, and name
    var displayText: String {
        let location = city.isEmpty ? state : city
        return location.isEmpty ? "\(iata) - \(country)" : "\(iata) - \(location), \(country)"
    }

    /// Full search text for filtering
    var searchText: String {
        "\(iata) \(city) \(state) \(name) \(country)".lowercased()
    }

    /// Display name for list rows
    var cityDisplay: String {
        if !city.isEmpty {
            "\(city), \(country)"
        } else if !state.isEmpty {
            "\(state), \(country)"
        } else {
            country
        }
    }
}

/// Service to load and search airports from bundled JSON
actor AirportService {
    static let shared = AirportService()

    private var airports: [Airport] = []
    private var isLoaded = false

    private init() {}

    /// Load airports from bundled JSON file
    func loadAirports() async throws {
        guard !isLoaded else { return }

        guard let url = Bundle.main.url(forResource: "airports", withExtension: "json") else {
            throw AirportServiceError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        airports = try JSONDecoder().decode([Airport].self, from: data)
        isLoaded = true
    }

    /// Search airports by query (matches IATA, city, name, or country)
    func search(query: String) async -> [Airport] {
        // Ensure airports are loaded
        if !isLoaded {
            try? await loadAirports()
        }

        // Return all if query is empty
        guard !query.isEmpty else {
            return airports
        }

        let lowercaseQuery = query.lowercased()

        // Prioritize IATA code matches, then city matches, then general matches
        let iataMatches = airports.filter { $0.iata.lowercased().starts(with: lowercaseQuery) }
        let cityMatches = airports.filter {
            !$0.iata.lowercased().starts(with: lowercaseQuery) &&
                $0.city.lowercased().starts(with: lowercaseQuery)
        }
        let otherMatches = airports.filter {
            !$0.iata.lowercased().starts(with: lowercaseQuery) &&
                !$0.city.lowercased().starts(with: lowercaseQuery) &&
                $0.searchText.contains(lowercaseQuery)
        }

        return iataMatches + cityMatches + otherMatches
    }

    /// Get airport by IATA code
    func getAirport(iata: String) async -> Airport? {
        // Ensure airports are loaded
        if !isLoaded {
            try? await loadAirports()
        }

        return airports.first { $0.iata.uppercased() == iata.uppercased() }
    }
}

enum AirportServiceError: Error {
    case fileNotFound
    case decodingError
}
