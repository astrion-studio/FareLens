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

    /// Search airports using 5-tier ranking algorithm with fuzzy matching
    /// - Parameter query: Search query (min 2 characters for results)
    /// - Returns: Up to 10 ranked results based on relevance
    func search(query: String) async -> [Airport] {
        // Ensure airports are loaded
        if !isLoaded {
            try? await loadAirports()
        }

        // Return empty if query is too short (UX optimization)
        guard query.count >= 2 else {
            return []
        }

        let lowercaseQuery = query.lowercased()
        var results: [(airport: Airport, tier: Int)] = []

        // TIER 1: Exact IATA code match (highest priority)
        let exactIATAMatches = airports.filter { $0.iata.lowercased() == lowercaseQuery }
        results.append(contentsOf: exactIATAMatches.map { ($0, 1) })

        // TIER 2: IATA starts with query
        let iataStartsMatches = airports.filter {
            $0.iata.lowercased().starts(with: lowercaseQuery) &&
                $0.iata.lowercased() != lowercaseQuery // Exclude tier 1
        }
        results.append(contentsOf: iataStartsMatches.map { ($0, 2) })

        // TIER 3: City starts with query
        let cityStartsMatches = airports.filter {
            !$0.iata.lowercased().starts(with: lowercaseQuery) && // Exclude tier 1 & 2
                $0.city.lowercased().starts(with: lowercaseQuery)
        }
        results.append(contentsOf: cityStartsMatches.map { ($0, 3) })

        // TIER 4: City or name contains query
        let containsMatches = airports.filter {
            !$0.iata.lowercased().starts(with: lowercaseQuery) && // Exclude tier 1 & 2
                !$0.city.lowercased().starts(with: lowercaseQuery) && // Exclude tier 3
                ($0.city.lowercased().contains(lowercaseQuery) ||
                    $0.name.lowercased().contains(lowercaseQuery))
        }
        results.append(contentsOf: containsMatches.map { ($0, 4) })

        // TIER 5: Fuzzy match (Levenshtein distance ≤ 2 for city, ≤ 3 for name)
        let alreadyMatched = Set(results.map { $0.airport.iata })
        let fuzzyMatches = airports.filter { airport in
            guard !alreadyMatched.contains(airport.iata) else { return false }

            let cityDistance = levenshteinDistance(lowercaseQuery, airport.city.lowercased())
            let nameDistance = levenshteinDistance(lowercaseQuery, airport.name.lowercased())

            return cityDistance <= 2 || nameDistance <= 3
        }
        results.append(contentsOf: fuzzyMatches.map { ($0, 5) })

        // Sort by tier (lower = better), then alphabetically by city
        let sortedResults = results.sorted { lhs, rhs in
            if lhs.tier != rhs.tier {
                return lhs.tier < rhs.tier
            }
            return lhs.airport.city < rhs.airport.city
        }

        // Limit to 10 results (mobile best practice)
        return Array(sortedResults.prefix(10).map { $0.airport })
    }

    /// Calculate Levenshtein distance between two strings (edit distance)
    /// Used for fuzzy matching typos like "san fransisco" → "san francisco"
    private func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let lhsArray = Array(lhs)
        let rhsArray = Array(rhs)
        let lhsCount = lhsArray.count
        let rhsCount = rhsArray.count

        // Early exit for empty strings
        if lhsCount == 0 { return rhsCount }
        if rhsCount == 0 { return lhsCount }

        // Create distance matrix
        var matrix = [[Int]](repeating: [Int](repeating: 0, count: rhsCount + 1), count: lhsCount + 1)

        // Initialize first column and row
        for i in 0...lhsCount { matrix[i][0] = i }
        for j in 0...rhsCount { matrix[0][j] = j }

        // Fill matrix
        for i in 1...lhsCount {
            for j in 1...rhsCount {
                let cost = lhsArray[i - 1] == rhsArray[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1, // deletion
                    matrix[i][j - 1] + 1, // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[lhsCount][rhsCount]
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
