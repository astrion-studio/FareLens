// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

/// Icon-only button (for toolbars and minimal UI)
struct FLIconButton: View {
    let icon: String
    let action: () -> Void
    var tintColor: Color = .brandBlue

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundColor(tintColor)
                .frame(width: Spacing.minTouchTarget, height: Spacing.minTouchTarget)
                .background(Color.cardBackground)
                .cornerRadius(CornerRadius.sm)
        }
    }
}
