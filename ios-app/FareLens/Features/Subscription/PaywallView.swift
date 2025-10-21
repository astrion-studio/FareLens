// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Observation
import StoreKit
import SwiftUI
import UIKit

struct PaywallView: View {
    @State private var viewModel = PaywallViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                // Background Gradient
                LinearGradient(
                    colors: [Color.brandBlue, Color.brandBlueLift],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Header
                        VStack(spacing: Spacing.md) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.warning)
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)

                            Text("Upgrade to Pro")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)

                            Text("Get more alerts, unlimited watchlists,\nand priority access to the best deals")
                                .bodyStyle()
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Spacing.xl)
                        .padding(.bottom, Spacing.lg)

                        // Feature Comparison
                        VStack(spacing: Spacing.md) {
                            ComparisonRow(
                                feature: "Flight deal alerts",
                                free: "3 per day",
                                pro: "6 per day",
                                proHighlight: true
                            )

                            ComparisonRow(
                                feature: "Watchlists",
                                free: "1 watchlist",
                                pro: "Unlimited",
                                proHighlight: true
                            )

                            ComparisonRow(
                                feature: "Preferred airports",
                                free: "1 airport",
                                pro: "3 airports",
                                proHighlight: true
                            )

                            ComparisonRow(
                                feature: "Watchlist-only mode",
                                free: "—",
                                pro: "✓",
                                proHighlight: true
                            )

                            ComparisonRow(
                                feature: "Custom alert times",
                                free: "✓",
                                pro: "✓",
                                proHighlight: false
                            )

                            ComparisonRow(
                                feature: "Deal history",
                                free: "✓",
                                pro: "✓",
                                proHighlight: false
                            )

                            ComparisonRow(
                                feature: "Price drop alerts",
                                free: "✓",
                                pro: "✓",
                                proHighlight: false
                            )
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)

                        // Pricing Card
                        if !viewModel.products.isEmpty {
                            VStack(spacing: Spacing.md) {
                                ForEach(viewModel.products, id: \.id) { product in
                                    PricingCard(
                                        product: product,
                                        isSelected: viewModel.selectedProduct?.id == product.id,
                                        onSelect: {
                                            viewModel.selectedProduct = product
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, Spacing.screenHorizontal)
                        }

                        // Trial Notice
                        InfoBox(
                            icon: "calendar.badge.clock",
                            text: "14-day free trial, then \(viewModel.selectedProduct?.displayPrice ?? "$4.99/month"). Cancel anytime.",
                            backgroundColor: Color.white.opacity(0.15),
                            foregroundColor: .white
                        )
                        .padding(.horizontal, Spacing.screenHorizontal)

                        // CTA Button
                        VStack(spacing: Spacing.md) {
                            FLButton(
                                title: viewModel.isLoading ? "Processing..." : "Start Free Trial",
                                style: .primary
                            ) {
                                Task {
                                    await viewModel.purchase()
                                }
                            }
                            .disabled(viewModel.isLoading || viewModel.selectedProduct == nil)
                            .padding(.horizontal, Spacing.screenHorizontal)

                            Button(action: {
                                Task {
                                    await viewModel.restore()
                                }
                            }) {
                                Text("Restore Purchase")
                                    .footnoteStyle()
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }

                        // Fine Print
                        VStack(spacing: Spacing.sm) {
                            Text("Auto-renewable subscription")
                                .captionStyle()
                                .foregroundColor(.white.opacity(0.6))

                            HStack(spacing: Spacing.lg) {
                                Button(action: { viewModel.openTerms() }) {
                                    Text("Terms")
                                        .captionStyle()
                                        .foregroundColor(.white.opacity(0.6))
                                        .underline()
                                }

                                Button(action: { viewModel.openPrivacy() }) {
                                    Text("Privacy")
                                        .captionStyle()
                                        .foregroundColor(.white.opacity(0.6))
                                        .underline()
                                }
                            }
                        }
                        .padding(.bottom, Spacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.8))
                            .font(.title3)
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
            .alert("Success", isPresented: $viewModel.showingSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Welcome to FareLens Pro! 🎉")
            }
        }
        .task {
            await viewModel.loadProducts()
        }
    }
}

// MARK: - Comparison Row

struct ComparisonRow: View {
    let feature: String
    let free: String
    let pro: String
    let proHighlight: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Feature Name
            Text(feature)
                .bodyStyle()
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Free Tier
            Text(free)
                .footnoteStyle()
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 80, alignment: .center)
                .padding(.vertical, Spacing.xs)
                .background(Color.white.opacity(0.1))
                .cornerRadius(CornerRadius.xs)

            // Pro Tier
            Text(pro)
                .footnoteStyle()
                .foregroundColor(proHighlight ? .warning : .white)
                .fontWeight(proHighlight ? .bold : .regular)
                .frame(width: 80, alignment: .center)
                .padding(.vertical, Spacing.xs)
                .background(proHighlight ? Color.warning.opacity(0.2) : Color.white.opacity(0.1))
                .cornerRadius(CornerRadius.xs)
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Pricing Card

struct PricingCard: View {
    let product: Product
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(product.displayName)
                        .headlineStyle()
                        .foregroundColor(.white)

                    Text(product.description)
                        .footnoteStyle()
                        .foregroundColor(.white.opacity(0.8))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    Text(product.displayPrice)
                        .title3Style()
                        .foregroundColor(.white)

                    if let savings = product.savingsText {
                        Text(savings)
                            .captionStyle()
                            .foregroundColor(.success)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, 2)
                            .background(Color.success.opacity(0.2))
                            .cornerRadius(CornerRadius.xs)
                    }
                }

                // Selection Indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .warning : .white.opacity(0.4))
                    .font(.title2)
            }
            .padding(Spacing.md)
            .background(isSelected ? Color.white.opacity(0.2) : Color.white.opacity(0.1))
            .cornerRadius(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(isSelected ? Color.warning : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Model

@Observable
@MainActor
final class PaywallViewModel {
    var products: [Product] = []
    var selectedProduct: Product?
    var isLoading = false
    var showingError = false
    var showingSuccess = false
    var errorMessage: String?

    private let subscriptionService: SubscriptionServiceProtocol

    init(subscriptionService: SubscriptionServiceProtocol = SubscriptionService.shared) {
        self.subscriptionService = subscriptionService
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await subscriptionService.fetchProducts()

            // Auto-select monthly by default
            if let monthly = products.first(where: { $0.id == "com.farelens.pro.monthly" }) {
                selectedProduct = monthly
            } else if let first = products.first {
                selectedProduct = first
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            showingError = true
        }
    }

    func purchase() async {
        guard let product = selectedProduct else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let success = try await subscriptionService.purchase(product: product)
            if success {
                showingSuccess = true
            } else {
                errorMessage = "Purchase was cancelled or failed"
                showingError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await subscriptionService.restorePurchases()
            showingSuccess = true
        } catch {
            errorMessage = "No previous purchases found"
            showingError = true
        }
    }

    func openTerms() {
        if let url = URL(string: "https://farelens.com/terms") {
            UIApplication.shared.open(url)
        }
    }

    func openPrivacy() {
        if let url = URL(string: "https://farelens.com/privacy") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Product Extensions

extension Product {
    var savingsText: String? {
        switch id {
        case "com.farelens.pro.annual":
            "Save 20%"
        default:
            nil
        }
    }
}
