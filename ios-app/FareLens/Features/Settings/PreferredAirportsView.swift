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
                                onWeightChange: { newWeight in
                                    viewModel.updateAirportWeight(at: index, weight: newWeight)
                                },
                                onDelete: {
                                    viewModel.removePreferredAirport(at: index)
                                }
                            )
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { viewModel.removePreferredAirport(at: $0) }
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
                            if !viewModel.isWeightSumValid {
                                Text("Weights must sum to 1.0")
                                    .footnoteStyle()
                                    .foregroundColor(.error)
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

                        FLButton(title: "Save Changes", style: .primary) {
                            Task {
                                await viewModel.updatePreferredAirports()
                            }
                        }
                        .disabled(!viewModel.isWeightSumValid)
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
    let onWeightChange: (Double) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(airport.iata)
                        .title3Style()
                        .foregroundColor(.textPrimary)

                    Text("Weight: \(Int(weight * 100))%")
                        .footnoteStyle()
                }

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.error)
                        .font(.headline)
                }
            }

            // Weight Slider
            VStack(spacing: Spacing.xs) {
                Slider(value: Binding(
                    get: { weight },
                    set: { onWeightChange($0) }
                ), in: 0.0...1.0, step: 0.1)
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

    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        Text("Airport Code")
                            .title3Style()
                            .foregroundColor(.textPrimary)

                        TextField("e.g., LAX, JFK, ORD", text: $airportCode)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.allCharacters)
                            .font(.body)
                    }

                    InfoBox(
                        icon: "lightbulb.fill",
                        text: "Enter the 3-letter IATA code for your preferred departure airport"
                    )

                    Spacer()
                }
                .padding(Spacing.screenHorizontal)
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

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd()
                        dismiss()
                    }
                    .foregroundColor(airportCode.count == 3 ? .brandBlue : .textTertiary)
                    .disabled(airportCode.count != 3)
                }
            }
        }
    }
}
