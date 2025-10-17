// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

/// Compact button with icon and optional title (for toolbars and compact spaces)
struct FLCompactButton: View {
    let icon: String
    let title: String?
    let action: () -> Void

    init(icon: String, title: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.footnote)

                if let title {
                    Text(title)
                        .footnoteStyle()
                }
            }
            .foregroundColor(.brandBlue)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(Color.cardBackground)
            .cornerRadius(CornerRadius.sm)
        }
    }
}
