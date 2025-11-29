// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

/// Validation message component for form feedback
/// Purpose-built for inline validation with proper animations and accessibility
struct ValidationMessage: View {
    let message: String
    let severity: Severity

    enum Severity {
        case error
        case warning
        case info

        var icon: String {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .error: return .error
            case .warning: return .warning
            case .info: return .brandBlue
            }
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: severity.icon)
                .font(.caption)
                .foregroundColor(severity.color)

            Text(message)
                .footnoteStyle()
                .foregroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(severity.color.opacity(0.1))
        .cornerRadius(CornerRadius.sm)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(severity == .error ? "Error" : severity == .warning ? "Warning" : "Information"): \(message)")
    }
}

// MARK: - Preview

struct ValidationMessage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.lg) {
            ValidationMessage(
                message: "Current total: 0.8 - Add 0.2 more to reach 1.0",
                severity: .error
            )

            ValidationMessage(
                message: "Almost there! Current total: 0.95",
                severity: .warning
            )

            ValidationMessage(
                message: "Weights are valid and ready to save",
                severity: .info
            )
        }
        .padding()
        .background(Color.backgroundPrimary)
    }
}
