// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Observation
import SwiftUI

struct PreferredAirportsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showingAddAirport = false
    @State private var newAirportCode = ""

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                if !viewModel.preferredAirports.isEmpty {
                    List {
                        ForEach(Array(viewModel.preferredAirports.enumerated()), id: \.element.id) { index, airport in
                            AirportWeightRow(
                                airport: airport,
                                weight: airport.weight,
                                isProUser: viewModel.user.isProUser,
                                onWeightChange: { newWeight in
                                    viewModel.updateAirportWeight(at: index, weight: newWeight)
                                },
                                onDelete: {
                                    viewModel.removePreferredAirport(at: index)
                                },
                                onUpgradeTap: {
                                    viewModel.showingUpgradeSheet = true
                                }
                            )
                        }
                        .onDelete { indexSet in
                            // Remove in reverse order to prevent index shifting crashes
                            indexSet.sorted().reversed().forEach { viewModel.removePreferredAirport(at: $0) }
                        }

                        // Weight Sum Validation
                        Section {
                            HStack {
                                Text("Total Weight")
                                    .bodyStyle()
                                Spacer()
                                Text(String(format: "%.1f", viewModel.preferredAirports.totalWeight))
                                    .headlineStyle()
                                    .foregroundColor(viewModel.isWeightSumValid ? .success : .error)
                            }
                        } footer: {
                            if !viewModel.user.isProUser {
                                Text("Upgrade to Pro to add up to 3 airports with custom weights to prioritize your preferred departure locations")
                                    .footnoteStyle()
                                    .foregroundColor(.textSecondary)
                            } else if !viewModel.isWeightSumValid {
                                Text("Weights must sum to 1.0")
                                    .footnoteStyle()
                                    .foregroundColor(.error)
                            } else {
                                Text("Distribute weights across airports to prioritize deals from your preferred locations")
                                    .footnoteStyle()
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                } else {
                    EmptyAirportsView {
                        showingAddAirport = true
                    }
                }

                // Save Button
                if !viewModel.preferredAirports.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .footnoteStyle()
                                .foregroundColor(.error)
                        }

                        Group {
                            if viewModel.isSaving {
                                // Loading state
                                HStack(spacing: Spacing.sm) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Saving...")
                                        .headlineStyle()
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.buttonVertical)
                                .background(Color.brandBlue)
                                .cornerRadius(CornerRadius.md)
                            } else if viewModel.showSaveSuccess {
                                // Success state
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.title3)
                                    Text("Saved")
                                        .headlineStyle()
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.buttonVertical)
                                .background(Color.success)
                                .cornerRadius(CornerRadius.md)
                            } else {
                                // Normal state
                                FLButton(title: "Save Changes", style: .primary) {
                                    Task {
                                        await viewModel.updatePreferredAirports()
                                    }
                                }
                                .disabled(!viewModel.isWeightSumValid)
                            }
                        }
                        .padding(.horizontal, Spacing.screenHorizontal)
                    }
                    .padding(.vertical, Spacing.md)
                    .background(Color.cardBackground)
                }
            }
        }
        .navigationTitle("Preferred Airports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if viewModel.canAddPreferredAirport {
                        showingAddAirport = true
                    } else {
                        viewModel.showingUpgradeSheet = true
                    }
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.brandBlue)
                }
            }
        }
        .sheet(isPresented: $showingAddAirport) {
            AddAirportSheet(
                airportCode: $newAirportCode,
                onAdd: {
                    addAirport()
                }
            )
        }
    }

    private func addAirport() {
        guard !newAirportCode.isEmpty else { return }

        let weight = viewModel.preferredAirports.isEmpty ? 1.0 : 0.0
        let airport = PreferredAirport(iata: newAirportCode.uppercased(), weight: weight)
        viewModel.addPreferredAirport(airport)
        newAirportCode = ""
        showingAddAirport = false
    }
}

// MARK: - Airport Weight Row

struct AirportWeightRow: View {
    let airport: PreferredAirport
    let weight: Double
    let isProUser: Bool
    let onWeightChange: (Double) -> Void
    let onDelete: () -> Void
    let onUpgradeTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack(spacing: Spacing.xs) {
                        Text(airport.iata)
                            .title3Style()
                            .foregroundColor(.textPrimary)

                        if !isProUser {
                            FLBadge(text: "Pro", style: .custom(
                                backgroundColor: Color.warning.opacity(0.15),
                                foregroundColor: .warning
                            ))
                        }
                    }

                    Text("Weight: \(Int(weight * 100))%")
                        .footnoteStyle()
                        .foregroundColor(isProUser ? .textSecondary : .textTertiary)
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.error)
                        .font(.headline)
                }
                .accessibilityLabel("Delete airport")
            }

            // Weight Slider - Disabled for Free tier with lock icon
            VStack(spacing: Spacing.xs) {
                HStack(spacing: Spacing.sm) {
                    if !isProUser {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.textTertiary)
                            .font(.caption)
                    }

                    Slider(value: Binding(
                        get: { weight },
                        set: { onWeightChange($0) }
                    ), in: 0.0...1.0, step: 0.1)
                        .tint(isProUser ? .brandBlue : .textTertiary.opacity(0.3))
                        .disabled(!isProUser)
                        .accessibilityLabel("Airport weight")
                        .accessibilityValue("\(Int(weight * 100)) percent")
                        .accessibilityHint(isProUser ? "Adjust to change priority" : "Upgrade to Pro to customize weights")
                }

                HStack {
                    Text("0%")
                        .captionStyle()
                        .foregroundColor(isProUser ? .textSecondary : .textTertiary)
                    Spacer()
                    Text("100%")
                        .captionStyle()
                        .foregroundColor(isProUser ? .textSecondary : .textTertiary)
                }
            }

            // Upgrade CTA for Free users
            if !isProUser {
                Button(action: onUpgradeTap) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "star.fill")
                            .font(.caption)
                        Text("Upgrade to customize weights")
                            .footnoteStyle()
                    }
                    .foregroundColor(.warning)
                }
                .accessibilityLabel("Upgrade to Pro")
                .accessibilityHint("Unlock custom airport weights with Pro subscription")
            }
        }
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Empty State

struct EmptyAirportsView: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "airplane.circle")
                .font(.system(size: 64))
                .foregroundColor(.brandBlue.opacity(0.5))

            VStack(spacing: Spacing.sm) {
                Text("No preferred airports")
                    .title2Style()
                    .foregroundColor(.textPrimary)

                Text("Add airports to prioritize deals\nfrom your favorite departure locations")
                    .bodyStyle()
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            FLButton(title: "Add Airport", style: .primary, action: onAdd)
                .padding(.horizontal, Spacing.xl)

            // Info Box
            InfoBox(
                icon: "info.circle.fill",
                text: "Free: 1 airport (100% weight)\nPro: Up to 3 airports with custom weights"
            )
            .padding(.horizontal, Spacing.screenHorizontal)
        }
        .padding(Spacing.screenHorizontal)
    }
}

// MARK: - Add Airport Sheet

struct AddAirportSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var airportCode: String
    let onAdd: () -> Void

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
                        Text("Search Airports")
                            .title3Style()
                            .foregroundColor(.textPrimary)

                        TextField("Search by city or code (e.g., Los Angeles, LAX)", text: $searchQuery)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .font(.body)
                            .onChange(of: searchQuery) { _, newValue in
                                Task {
                                    await performSearch(newValue)
                                }
                            }
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.vertical, Spacing.md)

                    Divider()

                    // Search results list
                    if isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if searchResults.isEmpty, !searchQuery.isEmpty {
                        EmptySearchView()
                    } else {
                        List {
                            ForEach(searchResults) { airport in
                                Button(action: {
                                    airportCode = airport.iata
                                    onAdd()
                                    dismiss()
                                }) {
                                    VStack(alignment: .leading, spacing: Spacing.xs) {
                                        HStack {
                                            Text(airport.iata)
                                                .headlineStyle()
                                                .foregroundColor(.textPrimary)

                                            Spacer()

                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(.brandBlue)
                                        }

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
            .navigationTitle("Add Airport")
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
        .task {
            await loadInitialAirports()
        }
    }

    private func loadInitialAirports() async {
        isSearching = true
        searchResults = await AirportService.shared.search(query: "")
        isSearching = false
    }

    private func performSearch(_ query: String) async {
        isSearching = true
        searchResults = await AirportService.shared.search(query: query)
        isSearching = false
    }
}

// MARK: - Empty Search View

struct EmptySearchView: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.textTertiary)

            VStack(spacing: Spacing.xs) {
                Text("No airports found")
                    .title3Style()
                    .foregroundColor(.textPrimary)

                Text("Try searching by city or airport code")
                    .bodyStyle()
                    .foregroundColor(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
