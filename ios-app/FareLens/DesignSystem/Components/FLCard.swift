import SwiftUI

/// FareLens Card Component
/// Standard card container with optional liquid glass effect
struct FLCard<Content: View>: View {
    let content: Content
    let style: CardStyle

    init(style: CardStyle = .standard, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        content
            .padding(Spacing.cardPadding)
            .background(style.background)
            .cornerRadius(CornerRadius.md)
            .cardShadow()
    }

    enum CardStyle {
        case standard
        case glass
        case elevated

        @ViewBuilder
        var background: some View {
            switch self {
            case .standard:
                Color.cardBackground
            case .glass:
                Color.glassOverlay
                    .background(.ultraThinMaterial)
            case .elevated:
                Color.cardBackground
                    .floatingShadow()
            }
        }
    }
}

/// Deal card with price, route, and score
struct FLDealCard: View {
    let deal: FlightDeal

    var body: some View {
        FLCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header: Route + Score Badge
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("\(deal.origin) → \(deal.destination)")
                            .title3Style()
                            .foregroundColor(.textPrimary)

                        Text("\(deal.airline) • \(deal.stops == 0 ? "Nonstop" : "\(deal.stops) stop(s)")")
                            .footnoteStyle()
                    }

                    Spacer()

                    FLBadge(
                        text: "\(deal.dealScore)",
                        style: .score(deal.dealScore)
                    )
                }

                // Price
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    Text(deal.formattedPrice)
                        .displayStyle()
                        .foregroundColor(.brandBlue)

                    Text("\(deal.discountPercent)% off")
                        .captionStyle()
                        .foregroundColor(.success)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                        .background(Color.success.opacity(0.1))
                        .cornerRadius(CornerRadius.xs)
                }

                // Dates
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.footnote)
                        .foregroundColor(.textSecondary)

                    Text(deal.departureDate, style: .date)
                        .footnoteStyle()

                    Text("→")
                        .footnoteStyle()

                    Text(deal.returnDate, style: .date)
                        .footnoteStyle()

                    Spacer()

                    Text("\(deal.tripLength) days")
                        .captionStyle()
                }
            }
        }
    }
}

/// Compact list item card
struct FLListCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack {
            content
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundColor(.textTertiary)
        }
        .padding(Spacing.md)
        .background(Color.cardBackground)
        .cornerRadius(CornerRadius.sm)
    }
}

// MARK: - Preview

struct FLCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: Spacing.lg) {
            // Standard card
            FLCard {
                VStack(alignment: .leading) {
                    Text("Standard Card")
                        .title3Style()
                    Text("This is a standard card with shadow")
                        .bodyStyle()
                        .foregroundColor(.textSecondary)
                }
            }

            // Glass card
            FLCard(style: .glass) {
                VStack(alignment: .leading) {
                    Text("Glass Card")
                        .title3Style()
                    Text("This card has liquid glass effect")
                        .bodyStyle()
                        .foregroundColor(.textSecondary)
                }
            }

            // Deal card
            FLDealCard(deal: FlightDeal(
                id: UUID(),
                origin: "LAX",
                destination: "JFK",
                departureDate: Date(),
                returnDate: Date().addingTimeInterval(7 * 86400),
                totalPrice: 420.0,
                currency: "USD",
                dealScore: 85,
                discountPercent: 40,
                normalPrice: 700.0,
                createdAt: Date(),
                expiresAt: Date().addingTimeInterval(24 * 3600),
                airline: "United",
                stops: 0,
                returnStops: 1,
                deepLink: "https://example.com"
            ))
        }
        .padding()
        .background(Color.backgroundPrimary)
    }
}
