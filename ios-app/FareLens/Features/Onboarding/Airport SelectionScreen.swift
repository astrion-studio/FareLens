// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Observation
import SwiftUI

struct AirportSelectionScreen: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showingAddAirport = false

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: Spacing.md) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.brandBlue)
                        .padding(.top, Spacing.xl * 2)

                    Text("Select Your Home Airport")
                        .title1Style()
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)

                    Text(viewModel.appState.subscriptionTier == .free ?
                        "Choose your preferred departure airport" :
                        "Choose up to 3 airports with custom weights")
                        .bodyStyle()
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Spacing.screenHorizontal)

                Spacer(minLength: Spacing.xl)

                // Selected Airports List
                if !viewModel.selectedAirports.isEmpty {
                    ScrollView {
                        VStack(spacing: Spacing.md) {
                            ForEach(Array(viewModel.selectedAirports.enumerated()), id: \.element.id) { index, airport in
                                OnboardingAirportRow(
                                    airport: airport,
                                    canRemove: viewModel.appState.subscriptionTier == .pro || viewModel.selectedAirports.count > 1,
                                    showWeight: viewModel.appState.subscriptionTier == .pro && viewModel.selectedAirports.count > 1,
                                    onRemove: {
                                        viewModel.removeAirport(at: index)
                                    },
                                    onWeightChange: { newWeight in
                                        viewModel.updateAirportWeight(at: index, weight: newWeight)
                                    }
                                )
                            }

                            // Weight validation feedback
                            if viewModel.appState.subscriptionTier == .pro && viewModel.selectedAirports.count > 1 {
                                HStack {
                                    Text("Total Weight:")
                                        .bodyStyle()
                                        .foregroundColor(.textSecondary)
                                    Spacer()
                                    Text(String(format: "%.0f%%", viewModel.selectedAirports.reduce(0.0) { $0 + $1.weight } * 100))
                                        .headlineStyle()
                                        .foregroundColor(viewModel.isWeightSumValid ? .success : .error)
                                }
                                .padding()
                                .background(Color.cardBackground)
                                .cornerRadius(CornerRadius.md)

                                if !viewModel.isWeightSumValid {
                                    Text("Weights must sum to 100%")
                                        .footnoteStyle()
                                        .foregroundColor(.error)
                                }
                            }

                            // Add Airport Button
                            if viewModel.canAddAirport {
                                Button(action: {
                                    showingAddAirport = true
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title3)
                                        Text("Add Airport")
                                            .headlineStyle()
                                    }
                                    .foregroundColor(.brandBlue)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.brandBlue.opacity(0.1))
                                    .cornerRadius(CornerRadius.md)
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                    }
                } else {
                    // Empty State
                    VStack(spacing: Spacing.xl) {
                        Spacer()

                        Image(systemName: "airplane")
                            .font(.system(size: 64))
                            .foregroundColor(.textTertiary)

                        Text("No airport selected yet")
                            .title3Style()
                            .foregroundColor(.textSecondary)

                        FLButton(title: "Select Airport", style: .primary) {
                            showingAddAirport = true
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)

                        Spacer()
                    }
                }

                Spacer()

                // Error Message
                if let error = viewModel.airportSelectionError {
                    Text(error)
                        .footnoteStyle()
                        .foregroundColor(.error)
                        .padding(.horizontal, Spacing.screenHorizontal)
                }

                // Action Buttons
                VStack(spacing: Spacing.md) {
                    // Continue Button
                    Group {
                        if viewModel.isSavingAirports {
                            ProgressView()
                                .tint(.brandBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.buttonVertical)
                        } else {
                            FLButton(
                                title: "Continue",
                                style: .primary
                            ) {
                                Task {
                                    await viewModel.completeAirportSelection()
                                }
                            }
                            .disabled(!viewModel.canCompleteSelection)
                            .opacity(viewModel.canCompleteSelection ? 1.0 : 0.5)
                        }
                    }

                    // Skip Button (Pro only)
                    if viewModel.appState.subscriptionTier == .pro {
                        Button(action: {
                            Task {
                                await viewModel.skipAirportSelection()
                            }
                        }) {
                            Text("Skip for now")
                                .headlineStyle()
                                .foregroundColor(.brandBlue)
                        }
                    }
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.bottom, Spacing.xl)
            }
        }
        .sheet(isPresented: $showingAddAirport) {
            OnboardingAirportSearchSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Airport Row

struct OnboardingAirportRow: View {
    let airport: PreferredAirport
    let canRemove: Bool
    let showWeight: Bool
    let onRemove: () -> Void
    let onWeightChange: (Double) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(airport.iata)
                        .title2Style()
                        .foregroundColor(.textPrimary)

                    if showWeight {
                        Text("Weight: \(Int(airport.weight * 100))%")
                            .footnoteStyle()
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                if canRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.error)
                            .font(.title2)
                    }
                }
            }

            // Weight Slider (Pro tier with multiple airports)
            if showWeight {
                VStack(spacing: Spacing.xs) {
                    Slider(
                        value: Binding(
                            get: { airport.weight },
                            set: { onWeightChange($0) }
                        ),
                        in: 0.0...1.0,
                        step: 0.1
                    )
                    .tint(.brandBlue)

                    HStack {
                        Text("0%")
                            .captionStyle()
                        Spacer()
                        Text("100%")
                            .captionStyle()
                    }
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(CornerRadius.md)
    }
}

// MARK: - Airport Search Sheet

struct OnboardingAirportSearchSheet: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var viewModel: OnboardingViewModel

    @State private var searchQuery = ""
    @State private var searchResults: [Airport] = []
    @State private var isSearching = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search field
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        TextField("Search by city or code (e.g., LAX, Los Angeles)", text: $searchQuery)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .onChange(of: searchQuery) { _, newValue in
                                Task {
                                    await performSearch(newValue)
                                }
                            }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.md)

                    Divider()

                    // Search results
                    if isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if searchResults.isEmpty {
                        OnboardingEmptySearchView()
                    } else {
                        List {
                            ForEach(searchResults) { airport in
                                Button(action: {
                                    let newAirport = PreferredAirport(
                                        iata: airport.iata,
                                        weight: viewModel.selectedAirports.isEmpty ? 1.0 : 0.0
                                    )
                                    viewModel.addAirport(newAirport)
                                    dismiss()
                                }) {
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        Text(airport.iata)
                                            .headlineStyle()
                                            .foregroundColor(.textPrimary)

                                        Text(airport.cityDisplay)
                                            .bodyStyle()
                                            .foregroundColor(.textSecondary)

                                        Text(airport.name)
                                            .footnoteStyle()
                                            .foregroundColor(.textTertiary)
                                            .lineLimit(1)
                                    }
                                    .padding(.vertical, Spacing.xs)
                                }
                                .listRowBackground(Color.cardBackground)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Select Airport")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }
            }
        }
    }

    private func performSearch(_ query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            return
        }

        isSearching = true
        searchResults = await AirportService.shared.search(query: query)
        isSearching = false
    }
}

// MARK: - Empty Search View

struct OnboardingEmptySearchView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text("Start typing to search")
                    .title3Style()
                    .foregroundColor(.textPrimary)

                Text("Enter at least 2 characters\n(e.g., \"LAX\", \"Los Angeles\")")
                    .bodyStyle()
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, Spacing.screenHorizontal)
    }
}
