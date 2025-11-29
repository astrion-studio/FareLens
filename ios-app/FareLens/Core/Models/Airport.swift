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

    /// Search airports with 5-tier ranking algorithm
    /// Tier 1: Exact IATA match
    /// Tier 2: IATA prefix match
    /// Tier 3: City prefix match
    /// Tier 4: Contains in name or city
    /// Tier 5: Fuzzy match (Levenshtein distance ≤ 2)
    func search(query: String) async -> [Airport] {
        // Ensure airports are loaded
        if !isLoaded {
            try? await loadAirports()
        }

        // Minimum query length for performance
        guard query.count >= 2 else {
            return []
        }

        let lowercaseQuery = query.lowercased()
        var results: [(airport: Airport, tier: Int)] = []

        // Single pass through airports with tier assignment
        for airport in airports {
            let iata = airport.iata.lowercased()
            let name = airport.name.lowercased()
            let city = airport.city.lowercased()

            // Assign tier based on first match (tiers are mutually exclusive)
            let tier: Int? = {
                // Tier 1: Exact IATA match
                if iata == lowercaseQuery {
                    return 1
                }
                // Tier 2: IATA prefix match
                if iata.hasPrefix(lowercaseQuery) {
                    return 2
                }
                // Tier 3: City prefix match
                if city.hasPrefix(lowercaseQuery) {
                    return 3
                }
                // Tier 4: Contains in name or city
                if name.contains(lowercaseQuery) || city.contains(lowercaseQuery) {
                    return 4
                }
                // Tier 5: Fuzzy match (Levenshtein distance ≤ 2)
                if levenshteinDistance(city, lowercaseQuery) <= 2 {
                    return 5
                }
                return nil
            }()

            if let tier = tier {
                results.append((airport, tier))
            }
        }

        // Sort by tier (lower is better), then alphabetically by city
        return results
            .sorted { lhs, rhs in
                if lhs.tier == rhs.tier {
                    return lhs.airport.city < rhs.airport.city
                }
                return lhs.tier < rhs.tier
            }
            .prefix(10) // Limit to 10 results for mobile UX
            .map { $0.airport }
    }

    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: s2Array.count + 1), count: s1Array.count + 1)

        for i in 0...s1Array.count {
            matrix[i][0] = i
        }
        for j in 0...s2Array.count {
            matrix[0][j] = j
        }

        for i in 1...s1Array.count {
            for j in 1...s2Array.count {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = Swift.min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[s1Array.count][s2Array.count]
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
