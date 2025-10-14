import SwiftUI

/// Informational box with icon and text (for tips, warnings, etc.)
struct InfoBox: View {
    let icon: String
    let text: String
    var backgroundColor: Color = Color.brandBlue.opacity(0.1)
    var foregroundColor: Color = .textPrimary

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(foregroundColor.opacity(0.8))
                .font(.title3)

            Text(text)
                .bodyStyle()
                .foregroundColor(foregroundColor)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .background(backgroundColor)
        .cornerRadius(CornerRadius.md)
    }
}
