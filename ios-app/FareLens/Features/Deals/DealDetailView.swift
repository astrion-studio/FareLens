// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

struct DealDetailView: View {
    let deal: FlightDeal
    @State private var viewModel: DealDetailViewModel
    @Environment(\.dismiss) var dismiss

    init(deal: FlightDeal) {
        self.deal = deal
        _viewModel = State(wrappedValue: DealDetailViewModel(deal: deal))
    }

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Hero Section
                    HeroSection(deal: deal, isSaved: viewModel.isSaved)

                    // Flight Details
                    VStack(spacing: Spacing.cardSpacing) {
                        // Route Info
                        RouteCard(deal: deal)

                        // Price Breakdown
                        PriceBreakdownCard(deal: deal)

                        // Deal Quality
                        DealQualityCard(deal: deal)

                        // Flight Details
                        FlightDetailsCard(deal: deal)

                        // Booking Info
                        BookingInfoCard()
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.lg)
                }
            }

            // Fixed Bottom CTA
            VStack {
                Spacer()

                VStack(spacing: Spacing.sm) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.brandBlue)
                    }

                    HStack(spacing: Spacing.md) {
                        // Save to Watchlist Button
                        Button(action: {
                            Task { await viewModel.toggleSave() }
                        }) {
                            Image(systemName: viewModel.isSaved ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundColor(viewModel.isSaved ? .error : .brandBlue)
                                .frame(width: 56, height: 56)
                                .background(Color.cardBackground)
                                .cornerRadius(CornerRadius.md)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        }

                        // Book Button
                        FLButton(title: "Book Flight", style: .primary) {
                            viewModel.openBookingURL()
                        }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                }
                .padding(.vertical, Spacing.md)
                .background(Color.backgroundPrimary)
                .shadow(color: .black.opacity(0.1), radius: 12, x: 0, y: -4)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.sharePressed()
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.brandBlue)
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = viewModel.errorMessage {
                Text(error)
            }
        }
    }
}

// MARK: - Hero Section

struct HeroSection: View {
    let deal: FlightDeal
    let isSaved: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Background Gradient
            LinearGradient(
                colors: [Color.brandBlue, Color.brandBlueLift],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 280)

            VStack(spacing: Spacing.lg) {
                // Route Display
                HStack(spacing: Spacing.xl) {
                    VStack(spacing: Spacing.xs) {
                        Text(deal.origin)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        Text(deal.originCity ?? deal.origin)
                            .footnoteStyle()
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Image(systemName: "airplane")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.6))
                        .rotationEffect(.degrees(90))

                    VStack(spacing: Spacing.xs) {
                        Text(deal.destination)
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                        Text(deal.destinationCity ?? deal.destination)
                            .footnoteStyle()
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.top, Spacing.xl)

                // Price Hero
                VStack(spacing: Spacing.xs) {
                    Text(deal.formattedPrice)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: Spacing.sm) {
                        Text("\(deal.discountPercent)% off")
                            .headlineStyle()
                            .foregroundColor(.white)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(CornerRadius.sm)

                        FLBadge(text: "\(deal.dealScore)", style: .score(deal.dealScore))
                    }
                }

                Spacer()
            }

            // Deal Score Badge (Top Right)
            if isSaved {
                Image(systemName: "heart.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(Spacing.md)
            }
        }
    }
}

// MARK: - Route Card

struct RouteCard: View {
    let deal: FlightDeal

    var body: some View {
        FLCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Route")
                    .title3Style()
                    .foregroundColor(.textPrimary)

                // Outbound
                FlightLegRow(
                    type: "Outbound",
                    origin: deal.origin,
                    destination: deal.destination,
                    date: deal.departureDate,
                    stops: deal.stops
                )

                Divider()

                // Return
                FlightLegRow(
                    type: "Return",
                    origin: deal.destination,
                    destination: deal.origin,
                    date: deal.returnDate,
                    stops: deal.returnStops ?? deal.stops
                )

                // Duration
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.textSecondary)
                    Text("Total Trip: \(deal.durationDays) days")
                        .bodyStyle()
                        .foregroundColor(.textSecondary)
                }
            }
        }
    }
}

struct FlightLegRow: View {
    let type: String
    let origin: String
    let destination: String
    let date: Date
    let stops: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(type)
                    .captionStyle()
                    .foregroundColor(.textSecondary)
                Text("\(origin) → \(destination)")
                    .bodyStyle()
                    .foregroundColor(.textPrimary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .bodyStyle()
                    .foregroundColor(.textPrimary)
                Text(stops == 0 ? "Nonstop" : "\(stops) stop(s)")
                    .captionStyle()
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

// MARK: - Price Breakdown Card

struct PriceBreakdownCard: View {
    let deal: FlightDeal

    var body: some View {
        FLCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Price Breakdown")
                    .title3Style()
                    .foregroundColor(.textPrimary)

                VStack(spacing: Spacing.sm) {
                    PriceRow(label: "Normal Price", value: deal.normalPrice, currency: deal.currency)
                    PriceRow(label: "Discount", value: -deal.discountAmount, currency: deal.currency, isDiscount: true)

                    Divider()

                    HStack {
                        Text("Your Price")
                            .headlineStyle()
                            .foregroundColor(.textPrimary)
                        Spacer()
                        Text(deal.formattedPrice)
                            .title2Style()
                            .foregroundColor(.brandBlue)
                    }
                }
            }
        }
    }
}

struct PriceRow: View {
    let label: String
    let value: Double
    let currency: String
    var isDiscount: Bool = false

    var body: some View {
        HStack {
            Text(label)
                .bodyStyle()
                .foregroundColor(.textSecondary)
            Spacer()
            Text(formatPrice(value, currency: currency))
                .bodyStyle()
                .foregroundColor(isDiscount ? .success : .textPrimary)
        }
    }

    private func formatPrice(_ amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}

// MARK: - Deal Quality Card

struct DealQualityCard: View {
    let deal: FlightDeal

    var body: some View {
        FLCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Text("Deal Quality")
                        .title3Style()
                        .foregroundColor(.textPrimary)
                    Spacer()
                    FLBadge(text: "\(deal.dealScore)", style: .score(deal.dealScore))
                }

                Text(deal.dealQualityDescription)
                    .bodyStyle()
                    .foregroundColor(.textSecondary)

                // Quality Indicator
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(index < deal.qualityStars ? Color.scoreColor(for: deal.dealScore) : Color
                                .textTertiary)
                            .frame(width: 12, height: 12)
                    }
                }
            }
        }
    }
}

// MARK: - Flight Details Card

struct FlightDetailsCard: View {
    let deal: FlightDeal

    var body: some View {
        FLCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("Flight Details")
                    .title3Style()
                    .foregroundColor(.textPrimary)

                DetailRow(icon: "airplane", label: "Airline", value: deal.airline)
                DetailRow(
                    icon: "calendar",
                    label: "Departure",
                    value: deal.departureDate.formatted(date: .long, time: .omitted)
                )
                DetailRow(
                    icon: "calendar.badge.clock",
                    label: "Return",
                    value: deal.returnDate.formatted(date: .long, time: .omitted)
                )
                DetailRow(icon: "clock", label: "Duration", value: "\(deal.durationDays) days")
                DetailRow(icon: "person.fill", label: "Passengers", value: "1 adult")
                DetailRow(icon: "bag.fill", label: "Baggage", value: deal.includedBaggage ?? "See airline policy")
            }
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(.brandBlue)
                .frame(width: 24)

            Text(label)
                .bodyStyle()
                .foregroundColor(.textSecondary)

            Spacer()

            Text(value)
                .bodyStyle()
                .foregroundColor(.textPrimary)
        }
    }
}

// MARK: - Booking Info Card

struct BookingInfoCard: View {
    var body: some View {
        FLCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.brandBlue)
                    Text("About This Deal")
                        .title3Style()
                        .foregroundColor(.textPrimary)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    BulletPoint(text: "Price includes all taxes and fees")
                    BulletPoint(text: "Book directly with the airline")
                    BulletPoint(text: "Prices may change - book soon!")
                    BulletPoint(text: "Check airline baggage policies")
                }
            }
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("•")
                .bodyStyle()
                .foregroundColor(.textSecondary)
            Text(text)
                .bodyStyle()
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Extensions

extension FlightDeal {
    var durationDays: Int {
        let components = Calendar.current.dateComponents([.day], from: departureDate, to: returnDate)
        // Return 0 if date components calculation fails (e.g., invalid date range)
        return components.day ?? 0
    }

    var normalPrice: Double {
        totalPrice / (1.0 - Double(discountPercent) / 100.0)
    }

    var discountAmount: Double {
        normalPrice - totalPrice
    }

    var dealQualityDescription: String {
        switch dealScore {
        case 90...100:
            "Exceptional deal! This is one of the best prices we've ever seen for this route."
        case 80..<90:
            "Excellent deal! This is significantly below the average price."
        case 70..<80:
            "Great deal! A solid discount on the typical fare."
        case 60..<70:
            "Good deal. Better than average pricing."
        default:
            "Fair price for this route."
        }
    }

    var qualityStars: Int {
        switch dealScore {
        case 90...100: 5
        case 80..<90: 4
        case 70..<80: 3
        case 60..<70: 2
        default: 1
        }
    }

    var originCity: String? {
        // TODO: Map IATA to city names
        nil
    }

    var destinationCity: String? {
        // TODO: Map IATA to city names
        nil
    }

    var includedBaggage: String? {
        // TODO: Get from API
        nil
    }

    var bookingURL: String {
        // TODO: Get from API
        "https://www.google.com/flights?q=\(origin)+to+\(destination)"
    }
}

extension Color {
    static func scoreColor(for score: Int) -> Color {
        switch score {
        case 90...100:
            .scoreExcellent
        case 80..<90:
            .scoreGreat
        case 70..<80:
            .scoreGood
        default:
            .scoreFair
        }
    }
}
