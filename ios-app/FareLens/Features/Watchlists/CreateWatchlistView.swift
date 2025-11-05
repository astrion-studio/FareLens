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
        !name.isEmpty &&
            isValidAirportCode(origin) &&
            (isFlexibleDestination || isValidAirportCode(destination)) &&
            (!hasDateRange || isDateRangeValid)
    }

    private func isValidAirportCode(_ code: String) -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespaces)
        let isIATA = trimmed.count == 3
        let isICAO = trimmed.count == 4
        let isLettersOnly = trimmed.allSatisfy(\.isLetter)
        return (isIATA || isICAO) && isLettersOnly
    }

    private var isDateRangeValid: Bool {
        guard hasDateRange else { return true }

        // End date must be after start date
        let isChronological = endDate > startDate

        // Start date should be today or in the future
        let isStartDateValid = Calendar.current.startOfDay(for: startDate) >=
            Calendar.current.startOfDay(for: Date())

        // Reasonable max range (e.g., 1 year)
        let daysBetween = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let isReasonableRange = daysBetween <= 365

        return isChronological && isStartDateValid && isReasonableRange
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
                                        DatePicker(
                                            "Start date",
                                            selection: $startDate,
                                            in: Date()...,
                                            displayedComponents: .date
                                        )
                                        .datePickerStyle(.compact)

                                        DatePicker(
                                            "End date",
                                            selection: $endDate,
                                            in: startDate...,
                                            displayedComponents: .date
                                        )
                                        .datePickerStyle(.compact)

                                        if !isDateRangeValid {
                                            Text("End date must be after start date and within 1 year")
                                                .captionStyle()
                                                .foregroundColor(.error)
                                        }
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

                                        Slider(value: $maxPrice, in: 100...6000, step: 50)
                                            .tint(.brandBlue)
                                            .accessibilityLabel("Maximum Price")
                                            .accessibilityValue(maxPrice.formatted(.currency(code: "USD")))

                                        HStack {
                                            Text("$100")
                                                .captionStyle()
                                            Spacer()
                                            Text("$6,000")
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
                    .foregroundColor(isFormValid && !viewModel.isCreating ? .brandBlue : .textTertiary)
                    .disabled(!isFormValid || viewModel.isCreating)
                }
            }
            .alert("Couldn't Save Watchlist", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
        }
    }

    private func saveWatchlist() {
        let watchlist = Watchlist(
            userId: viewModel.userId,
            name: name,
            origin: origin.trimmingCharacters(in: .whitespaces).uppercased(),
            destination: isFlexibleDestination ? "ANY" : destination.trimmingCharacters(in: .whitespaces).uppercased(),
            dateRange: hasDateRange ? DateRange(start: startDate, end: endDate) : nil,
            maxPrice: hasMaxPrice ? maxPrice : nil
        )

        Task {
            let success = await viewModel.createWatchlist(watchlist)
            if success {
                dismiss()
            }
            // If failure, errorMessage is set and alert shows automatically
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
