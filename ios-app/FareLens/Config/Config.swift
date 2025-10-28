// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation

/// Configuration values loaded from Secrets.xcconfig at build time
/// These values are embedded during compilation and never hardcoded in source
enum Config {
    /// Supabase project URL
    static let supabaseURL: String = {
        guard let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String, !url.isEmpty else {
            fatalError("SUPABASE_URL not found in Info.plist. Check Secrets.xcconfig configuration.")
        }
        return url
    }()

    /// Supabase publishable (anon) key - safe to use in client-side code
    static let supabasePublishableKey: String = {
        guard let key = Bundle.main.infoDictionary?["SUPABASE_PUBLISHABLE_KEY"] as? String, !key.isEmpty else {
            fatalError("SUPABASE_PUBLISHABLE_KEY not found in Info.plist. Check Secrets.xcconfig configuration.")
        }
        return key
    }()

    /// Cloudflare Worker API URL (deployed endpoint)
    static let cloudflareWorkerURL: String = {
        guard let url = Bundle.main.infoDictionary?["CLOUDFLARE_WORKER_URL"] as? String, !url.isEmpty else {
            fatalError("CLOUDFLARE_WORKER_URL not found in Info.plist. Check Secrets.xcconfig configuration.")
        }
        return url
    }()
}
