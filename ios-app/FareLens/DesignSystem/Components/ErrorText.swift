// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

/// Inline error message component for form field validation
/// Shows error icon + message in red, with fade-in animation
struct ErrorText: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundColor(.error)

            Text(message)
                .footnoteStyle()
                .foregroundColor(.error)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.md) {
        ErrorText(message: "Email is required")
        ErrorText(message: "Please enter a valid email address")
        ErrorText(message: "Password must be at least 8 characters")
    }
    .padding()
}
