// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

/// Screen-level error banner for server/network errors
/// Shows error icon, message, and optional action button
struct ErrorBanner: View {
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
                .foregroundColor(.error)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(message)
                    .bodyStyle()
                    .foregroundColor(.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle {
                    Button(action: { action?() }) {
                        Text(actionTitle)
                            .footnoteStyle()
                            .foregroundColor(.brandBlue)
                    }
                }
            }

            Spacer()
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.error.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.error.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, Spacing.screenHorizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

#Preview {
    VStack(spacing: Spacing.lg) {
        ErrorBanner(
            message: "Unable to connect. Please check your internet connection and try again.",
            actionTitle: "Try Again"
        ) {
            // Retry action
        }

        ErrorBanner(
            message: "An account with this email already exists. Try signing in instead.",
            actionTitle: "Go to Sign In"
        ) {
            // Switch to sign in action
        }

        ErrorBanner(
            message: "The email or password you entered is incorrect. Please try again."
        )
    }
    .padding()
    .background(Color.backgroundPrimary)
}
