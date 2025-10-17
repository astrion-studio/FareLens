// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

/// FareLens Button Component
/// Consistent button styling across the app
struct FLButton: View {
    let title: String
    let style: ButtonStyle
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .headlineStyle()
                .foregroundColor(style.foregroundColor)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Spacing.buttonHorizontal)
                .padding(.vertical, Spacing.buttonVertical)
                .background(style.background)
                .cornerRadius(CornerRadius.sm)
        }
    }

    enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case ghost

        var background: some View {
            Group {
                switch self {
                case .primary:
                    LinearGradient.brand
                case .secondary:
                    Color.cardBackground
                case .destructive:
                    Color.error
                case .ghost:
                    Color.clear
                }
            }
        }

        var foregroundColor: Color {
            switch self {
            case .primary, .destructive:
                .white
            case .secondary:
                .brandBlue
            case .ghost:
                .brandBlue
            }
        }
    }
}

// MARK: - Preview

struct FLButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.lg) {
            FLButton(title: "Search Flights", style: .primary) {}
            FLButton(title: "View Details", style: .secondary) {}
            FLButton(title: "Delete", style: .destructive) {}
            FLButton(title: "Cancel", style: .ghost) {}

            Divider()

            HStack {
                FLCompactButton(icon: "arrow.up.arrow.down", title: "Sort") {}
                FLCompactButton(icon: "line.3.horizontal.decrease", title: "Filter") {}
            }

            HStack {
                FLIconButton(icon: "heart") {}
                FLIconButton(icon: "square.and.arrow.up") {}
                FLIconButton(icon: "bell") {}
            }
        }
        .padding()
        .background(Color.backgroundPrimary)
    }
}
