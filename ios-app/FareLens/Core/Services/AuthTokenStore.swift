// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import OSLog
import Security

/// Secure storage for authentication tokens per ARCHITECTURE.md security guidelines.
actor AuthTokenStore {
    static let shared = AuthTokenStore()

    private let service = "com.farelens.app.auth"
    private let accessTokenAccount = "user_jwt"
    private let refreshTokenAccount = "user_refresh_token"
    private let logger = Logger(subsystem: "com.farelens.app", category: "auth")

    func saveTokens(accessToken: String, refreshToken: String) {
        saveToken(accessToken, account: accessTokenAccount)
        saveToken(refreshToken, account: refreshTokenAccount)
    }

    func loadTokens() -> (accessToken: String, refreshToken: String)? {
        // Try to load both tokens
        let accessToken = loadToken(account: accessTokenAccount)
        let refreshToken = loadToken(account: refreshTokenAccount)

        // If both exist, return them
        if let access = accessToken, let refresh = refreshToken {
            return (access, refresh)
        }

        // Migration path: If only access token exists (legacy user_jwt), use it for both
        // This handles upgrades from previous builds that only stored user_jwt
        if let legacyToken = accessToken, refreshToken == nil {
            logger.info("Migrating legacy auth token: using access token as refresh token")
            // Save the legacy token as refresh token too (one-time migration)
            saveToken(legacyToken, account: refreshTokenAccount)
            return (legacyToken, legacyToken)
        }

        // No tokens found or partial tokens without legacy access token
        return nil
    }

    func clearTokens() {
        clearToken(account: accessTokenAccount)
        clearToken(account: refreshTokenAccount)
    }

    // MARK: - Single Token Methods (should be phased out)

    @available(*, deprecated, message: "Use saveTokens(accessToken:refreshToken:) instead")
    func saveToken(_ token: String) {
        saveToken(token, account: accessTokenAccount)
    }

    @available(*, deprecated, message: "Use loadTokens() instead")
    func loadToken() -> String? {
        loadToken(account: accessTokenAccount)
    }

    @available(*, deprecated, message: "Use clearTokens() instead")
    func clearToken() {
        clearToken(account: accessTokenAccount)
    }

    // MARK: - Private helpers

    private func saveToken(_ token: String, account: String) {
        guard let data = token.data(using: .utf8) else {
            logger.error("Failed to encode auth token for storage")
            return
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        SecItemDelete(baseQuery as CFDictionary)

        var insertQuery = baseQuery
        insertQuery[kSecValueData as String] = data
        insertQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let status = SecItemAdd(insertQuery as CFDictionary, nil)

        if status != errSecSuccess {
            logger.error("Failed to save auth token to Keychain (account: \(account)): \(status)")
        } else {
            logger.info("Auth token saved to Keychain (account: \(account))")
        }
    }

    private func loadToken(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            if status != errSecItemNotFound {
                logger.error("Failed to load auth token from Keychain (account: \(account)): \(status)")
            }
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func clearToken(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecSuccess || status == errSecItemNotFound {
            logger.info("Auth token cleared from Keychain (account: \(account))")
        } else {
            logger.error("Failed to clear auth token from Keychain (account: \(account)): \(status)")
        }
    }
}
