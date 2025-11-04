// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

/// Real-time password requirements checklist
/// Shows green checkmarks as requirements are met
struct PasswordRequirements: View {
    let password: String

    private var hasMinLength: Bool {
        password.count >= 8
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            RequirementRow(met: hasMinLength, text: "At least 8 characters")
            // Add more requirements here as Supabase rules evolve
        }
        .padding(.top, Spacing.xs)
    }
}

struct RequirementRow: View {
    let met: Bool
    let text: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundColor(met ? .success : .textTertiary)

            Text(text)
                .footnoteStyle()
                .foregroundColor(met ? .success : .textSecondary)
        }
        .animation(.spring(response: 0.3), value: met)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(met ? "Met" : "Not met"): \(text)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Password")
                .bodyStyle()
                .foregroundColor(.textSecondary)

            SecureField("••••••••", text: .constant("pass"))
                .textFieldStyle(.roundedBorder)

            PasswordRequirements(password: "pass")
        }

        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Password")
                .bodyStyle()
                .foregroundColor(.textSecondary)

            SecureField("••••••••", text: .constant("password123"))
                .textFieldStyle(.roundedBorder)

            PasswordRequirements(password: "password123")
        }
    }
    .padding()
    .background(Color.backgroundPrimary)
}
