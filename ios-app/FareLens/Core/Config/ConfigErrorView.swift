// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

/// Error view shown when app configuration is invalid
/// Provides clear guidance on how to fix configuration issues
struct ConfigErrorView: View {
    let errors: [ConfigValidator.ConfigError]

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Error Icon
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.error)
                        .padding(.top, Spacing.xxl)

                    // Title
                    VStack(spacing: Spacing.sm) {
                        Text("Configuration Error")
                            .title1Style()
                            .foregroundColor(.textPrimary)

                        Text("The app cannot start due to invalid configuration")
                            .bodyStyle()
                            .foregroundColor(.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Error List
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Issues Found:")
                            .headlineStyle()
                            .foregroundColor(.textPrimary)

                        ForEach(Array(errors.enumerated()), id: \.offset) { index, error in
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Text("\(index + 1).")
                                    .footnoteStyle()
                                    .foregroundColor(.textSecondary)

                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(error.localizedDescription)
                                        .bodyStyle()
                                        .foregroundColor(.textPrimary)

                                    if let suggestion = error.recoverySuggestion {
                                        Text(suggestion)
                                            .footnoteStyle()
                                            .foregroundColor(.textTertiary)
                                    }
                                }
                            }
                            .padding(Spacing.md)
                            .background(Color.cardBackground)
                            .cornerRadius(CornerRadius.md)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Help Section
                    InfoBox(
                        icon: "info.circle.fill",
                        text: """
                        Configuration values are loaded from:
                        ios-app/FareLens/Config/Secrets.xcconfig.local

                        Required values:
                        • SUPABASE_URL (valid HTTPS URL)
                        • SUPABASE_PUBLISHABLE_KEY (non-empty)
                        • CLOUDFLARE_WORKER_URL (valid HTTPS URL)

                        After fixing the configuration file, rebuild the app.
                        """
                    )

                    // Retry Button
                    FLButton(
                        title: "Retry",
                        style: .primary,
                        action: {
                            // Force app restart to reload config
                            exit(0)
                        }
                    )
                    .padding(.horizontal, Spacing.xl)

                    Spacer()
                }
                .padding(.horizontal, Spacing.screenHorizontal)
            }
        }
    }
}

// MARK: - Previews

#Preview("Single Error") {
    ConfigErrorView(
        errors: [
            .invalidURL(
                key: "SUPABASE_URL",
                value: "not-a-url",
                reason: "Cannot parse as URL. Must be complete URL like https://example.com"
            ),
        ]
    )
}

#Preview("Multiple Errors") {
    ConfigErrorView(
        errors: [
            .invalidURL(
                key: "SUPABASE_URL",
                value: "https://example.supabase.co",
                reason: "Contains placeholder value"
            ),
            .emptyValue(key: "SUPABASE_PUBLISHABLE_KEY"),
            .invalidURL(
                key: "CLOUDFLARE_WORKER_URL",
                value: "invalid",
                reason: "URL is incomplete or missing host. Must be like https://example.com"
            ),
        ]
    )
}
