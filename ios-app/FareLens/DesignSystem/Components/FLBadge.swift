import SwiftUI

/// FareLens Badge Component
/// Pills and badges for status, scores, and tags
struct FLBadge: View {
    let text: String
    let style: BadgeStyle

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(style.foregroundColor)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(style.backgroundColor)
            .cornerRadius(CornerRadius.xs)
    }

    enum BadgeStyle {
        case score(Int)
        case hot
        case expiring
        case saved
        case custom(backgroundColor: Color, foregroundColor: Color)

        var backgroundColor: Color {
            switch self {
            case .score(let value):
                return scoreColor(value).opacity(0.15)
            case .hot:
                return Color.accentOrange.opacity(0.15)
            case .expiring:
                return Color.warning.opacity(0.15)
            case .saved:
                return Color.success.opacity(0.15)
            case .custom(let bg, _):
                return bg
            }
        }

        var foregroundColor: Color {
            switch self {
            case .score(let value):
                return scoreColor(value)
            case .hot:
                return Color.accentOrange
            case .expiring:
                return Color.warning
            case .saved:
                return Color.success
            case .custom(_, let fg):
                return fg
            }
        }

        private func scoreColor(_ score: Int) -> Color {
            switch score {
            case 90...100: return .scoreExcellent
            case 80..<90: return .scoreGreat
            case 70..<80: return .scoreGood
            default: return .scoreFair
            }
        }
    }
}

/// Outlined badge variant
struct FLOutlinedBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xs)
                    .stroke(color, lineWidth: 1)
            )
    }
}

/// Icon badge (notification count, etc)
struct FLIconBadge: View {
    let count: Int
    let color: Color

    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(minWidth: 16, minHeight: 16)
            .padding(.horizontal, 4)
            .background(color)
            .cornerRadius(CornerRadius.full)
    }
}

// MARK: - Preview

struct FLBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.lg) {
            // Score badges
            HStack(spacing: Spacing.sm) {
                FLBadge(text: "95", style: .score(95))
                FLBadge(text: "85", style: .score(85))
                FLBadge(text: "75", style: .score(75))
                FLBadge(text: "65", style: .score(65))
            }

            // Status badges
            HStack(spacing: Spacing.sm) {
                FLBadge(text: "Hot Deal", style: .hot)
                FLBadge(text: "Expiring Soon", style: .expiring)
                FLBadge(text: "Saved", style: .saved)
            }

            // Outlined badges
            HStack(spacing: Spacing.sm) {
                FLOutlinedBadge(text: "Nonstop", color: .brandBlue)
                FLOutlinedBadge(text: "1 stop", color: .textSecondary)
                FLOutlinedBadge(text: "Flexible dates", color: .success)
            }

            // Icon badges
            HStack(spacing: Spacing.xl) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.title2)
                        .foregroundColor(.brandBlue)
                    FLIconBadge(count: 3, color: .error)
                        .offset(x: 8, y: -8)
                }

                ZStack(alignment: .topTrailing) {
                    Image(systemName: "heart.fill")
                        .font(.title2)
                        .foregroundColor(.brandBlue)
                    FLIconBadge(count: 12, color: .success)
                        .offset(x: 8, y: -8)
                }
            }
        }
        .padding()
        .background(Color.backgroundPrimary)
    }
}
