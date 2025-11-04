// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation

/// Configuration values loaded from Secrets.xcconfig at build time
/// These values are embedded during compilation and never hardcoded in source
enum Config {
    /// Supabase project URL
    static let supabaseURL: String = value(for: "SUPABASE_URL")

    /// Supabase publishable (anon) key - safe to use in client-side code
    static let supabasePublishableKey: String = value(for: "SUPABASE_PUBLISHABLE_KEY")

    /// Cloudflare Worker API URL (deployed endpoint)
    static let cloudflareWorkerURL: String = value(for: "CLOUDFLARE_WORKER_URL")

    // MARK: - Private Helpers

    /// Retrieves and validates a configuration value from Info.plist
    /// - Parameter key: The configuration key to retrieve
    /// - Returns: The configuration value
    /// - Note: Crashes with a descriptive error if the key is missing or empty
    private static func value(for key: String) -> String {
        guard let value = Bundle.main.infoDictionary?[key] as? String, !value.isEmpty else {
            fatalError("\(key) not found in Info.plist. Check Secrets.xcconfig configuration.")
        }
        return value
    }
}
