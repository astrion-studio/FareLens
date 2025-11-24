// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import OSLog

/// Validates application configuration at startup
/// Ensures all required config values are present and valid before services initialize
enum ConfigValidator {
    private static let logger = Logger(
        subsystem: "com.astrionstudio.farelens",
        category: "ConfigValidator"
    )

    /// Configuration validation result
    enum ValidationResult {
        case valid
        case invalid(errors: [ConfigError])

        var isValid: Bool {
            if case .valid = self { return true }
            return false
        }

        var errors: [ConfigError] {
            if case let .invalid(errors) = self { return errors }
            return []
        }
    }

    /// Configuration error types
    enum ConfigError: LocalizedError {
        case missingValue(key: String)
        case invalidURL(key: String, value: String)
        case emptyValue(key: String)
        case placeholderValue(key: String, value: String)

        var errorDescription: String? {
            switch self {
            case let .missingValue(key):
                "\(key) is missing from configuration"
            case let .invalidURL(key, value):
                "\(key) has invalid URL format: '\(value)'"
            case let .emptyValue(key):
                "\(key) is empty"
            case let .placeholderValue(key, value):
                "\(key) contains placeholder value: '\(value)'"
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .placeholderValue:
                "Replace placeholder with actual value in ios-app/FareLens/Config/Secrets.xcconfig.local"
            default:
                "Check ios-app/FareLens/Config/Secrets.xcconfig.local file"
            }
        }
    }

    /// Validates all required configuration values
    /// Call this before initializing any services that depend on config
    /// - Note: Always performs validation, even in tests. This ensures services
    ///         that depend on valid config (like AuthService) can safely assume
    ///         validation occurred. Tests should provide valid test config.
    static func validate() -> ValidationResult {
        var errors: [ConfigError] = []

        // Validate Supabase URL
        let supabaseURL = validateURL(
            key: "SUPABASE_URL",
            value: Config.supabaseURL
        )
        if let error = supabaseURL {
            errors.append(error)
        }

        // Validate Supabase Publishable Key
        let supabaseKey = validateNonEmpty(
            key: "SUPABASE_PUBLISHABLE_KEY",
            value: Config.supabasePublishableKey
        )
        if let error = supabaseKey {
            errors.append(error)
        }

        // Validate Cloudflare Worker URL
        let workerURL = validateURL(
            key: "CLOUDFLARE_WORKER_URL",
            value: Config.cloudflareWorkerURL
        )
        if let error = workerURL {
            errors.append(error)
        }

        if errors.isEmpty {
            logger.info("✅ Configuration validation passed")
            return .valid
        } else {
            logger.error("❌ Configuration validation failed with \(errors.count) errors")
            errors.forEach { logger.error("  - \($0.localizedDescription)") }
            return .invalid(errors: errors)
        }
    }

    // MARK: - Private Validation Helpers

    private static func validateURL(key: String, value: String) -> ConfigError? {
        guard !value.isEmpty else {
            return .emptyValue(key: key)
        }

        // Check if it's a placeholder value from CI
        if value == "https://example.supabase.co" || value == "https://example.workers.dev" {
            return .placeholderValue(key: key, value: value)
        }

        // Validate URL format, ensure it has a host component, and uses https://
        guard let url = URL(string: value),
              let host = url.host,
              !host.isEmpty,
              url.scheme == "https" else {
            return .invalidURL(key: key, value: value)
        }

        return nil
    }

    private static func validateNonEmpty(key: String, value: String) -> ConfigError? {
        if value.isEmpty {
            return .emptyValue(key: key)
        }

        // Check for placeholder values
        if value == "public-anon-key" {
            return .placeholderValue(key: key, value: value)
        }

        return nil
    }
}
