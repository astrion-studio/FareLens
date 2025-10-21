// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Observation
import SwiftUI

struct CreateWatchlistView: View {
    @Bindable var viewModel: WatchlistsViewModel
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var origin = ""
    @State private var destination = ""
    @State private var isFlexibleDestination = false
    @State private var hasDateRange = false
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(30 * 86400) // 30 days
    @State private var hasMaxPrice = false
    @State private var maxPrice: Double = 500

    var isFormValid: Bool {
        !name.isEmpty && !origin.isEmpty && (!destination.isEmpty || isFlexibleDestination)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Name Section
                        FormSection(title: "Name") {
                            TextField("e.g., LAX to NYC Summer", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Route Section
                        FormSection(title: "Route") {
                            VStack(spacing: Spacing.md) {
                                // Origin
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    Text("From")
                                        .footnoteStyle()
                                    TextField("Airport code (e.g., LAX)", text: $origin)
                                        .textFieldStyle(.roundedBorder)
                                        .autocapitalization(.allCharacters)
                                }

                                // Destination
                                VStack(alignment: .leading, spacing: Spacing.sm) {
                                    Text("To")
                                        .footnoteStyle()

                                    if isFlexibleDestination {
                                        HStack {
                                            Text("Anywhere")
                                                .bodyStyle()
                                                .foregroundColor(.textSecondary)
                                            Spacer()
                                            Button("Change") {
                                                isFlexibleDestination = false
                                            }
                                            .font(.footnote)
                                            .foregroundColor(.brandBlue)
                                        }
                                        .padding()
                                        .background(Color.cardBackground)
                                        .cornerRadius(CornerRadius.sm)
                                    } else {
                                        HStack(spacing: Spacing.sm) {
                                            TextField("Airport code (e.g., JFK)", text: $destination)
                                                .textFieldStyle(.roundedBorder)
                                                .autocapitalization(.allCharacters)

                                            Button(action: {
                                                destination = ""
                                                isFlexibleDestination = true
                                            }) {
                                                Text("Any")
                                                    .font(.footnote)
                                                    .foregroundColor(.brandBlue)
                                                    .padding(.horizontal, Spacing.md)
                                                    .padding(.vertical, Spacing.sm)
                                                    .background(Color.cardBackground)
                                                    .cornerRadius(CornerRadius.sm)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Optional Filters
                        FormSection(title: "Optional Filters") {
                            VStack(spacing: Spacing.md) {
                                // Date Range Toggle
                                Toggle("Specific date range", isOn: $hasDateRange)
                                    .tint(.brandBlue)

                                if hasDateRange {
                                    VStack(alignment: .leading, spacing: Spacing.sm) {
                                        DatePicker("Start date", selection: $startDate, displayedComponents: .date)
                                            .datePickerStyle(.compact)

                                        DatePicker("End date", selection: $endDate, displayedComponents: .date)
                                            .datePickerStyle(.compact)
                                    }
                                    .padding(.leading, Spacing.lg)
                                }

                                Divider()

                                // Max Price Toggle
                                Toggle("Maximum price", isOn: $hasMaxPrice)
                                    .tint(.brandBlue)

                                if hasMaxPrice {
                                    VStack(alignment: .leading, spacing: Spacing.sm) {
                                        HStack {
                                            Text("$\(Int(maxPrice))")
                                                .headlineStyle()
                                                .foregroundColor(.brandBlue)
                                            Spacer()
                                        }

                                        Slider(value: $maxPrice, in: 100...2000, step: 50)
                                            .tint(.brandBlue)

                                        HStack {
                                            Text("$100")
                                                .captionStyle()
                                            Spacer()
                                            Text("$2,000")
                                                .captionStyle()
                                        }
                                    }
                                    .padding(.leading, Spacing.lg)
                                }
                            }
                        }

                        // Info Box
                        InfoBox(
                            icon: "lightbulb.fill",
                            text: "You'll get alerts when deals match all your criteria. More filters = fewer alerts but better matches."
                        )
                    }
                    .padding(Spacing.screenHorizontal)
                }
            }
            .navigationTitle("New Watchlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWatchlist()
                    }
                    .foregroundColor(isFormValid ? .brandBlue : .textTertiary)
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func saveWatchlist() {
        let watchlist = Watchlist(
            userId: viewModel.userId,
            name: name,
            origin: origin.uppercased(),
            destination: isFlexibleDestination ? "ANY" : destination.uppercased(),
            dateRange: hasDateRange ? DateRange(start: startDate, end: endDate) : nil,
            maxPrice: hasMaxPrice ? maxPrice : nil
        )

        Task {
            await viewModel.createWatchlist(watchlist)
            dismiss()
        }
    }
}

// MARK: - Form Section

struct FormSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text(title)
                .title3Style()
                .foregroundColor(.textPrimary)

            content
        }
    }
}
