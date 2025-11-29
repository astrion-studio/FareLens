// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Observation
import SwiftUI

// MARK: - Validation Message (Inline - TODO: Refactor to DesignSystem)

/// Validation message component for form feedback
private struct ValidationMessage: View {
    let message: String
    let severity: Severity

    enum Severity {
        case error
        case warning
        case info

        var icon: String {
            switch self {
            case .error: return "exclamationmark.triangle.fill"
            case .warning: return "exclamationmark.circle.fill"
            case .info: return "info.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .error: return .error
            case .warning: return .warning
            case .info: return .brandBlue
            }
        }
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: severity.icon)
                .font(.caption)
                .foregroundColor(severity.color)

            Text(message)
                .footnoteStyle()
                .foregroundColor(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(severity.color.opacity(0.1))
        .cornerRadius(CornerRadius.sm)
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(severity == .error ? "Error" : severity == .warning ? "Warning" : "Information"): \(message)")
    }
}

// MARK: - Animation Extensions (Inline - TODO: Refactor to DesignSystem)

private extension Animation {
    static let uiSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let uiStandard = Animation.spring(response: 0.4, dampingFraction: 0.75)
    static let uiSmooth = Animation.spring(response: 0.5, dampingFraction: 0.8)
}

struct PreferredAirportsView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var showingAddAirport = false
    @State private var newAirportCode = ""
    @State private var airportToDelete: PreferredAirport?
    @State private var deleteIndex: Int?

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
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    airportToDelete = airport
                                    deleteIndex = index
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
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

                            // Inline validation message with actionable guidance
                            if !viewModel.isWeightSumValid && viewModel.user.isProUser {
                                let total = viewModel.preferredAirports.totalWeight
                                let diff = abs(1.0 - total)
                                let action = total < 1.0 ? "Add" : "Reduce by"

                                ValidationMessage(
                                    message: "Current total: \(String(format: "%.1f", total)) - \(action) \(String(format: "%.1f", diff)) to reach 1.0",
                                    severity: .error
                                )
                                .padding(.horizontal, -Spacing.md) // Compensate for cell padding
                                .padding(.top, Spacing.xs)
                                .onAppear {
                                    let generator = UINotificationFeedbackGenerator()
                                    generator.notificationOccurred(.warning)
                                }
                            }
                        } footer: {
                            if !viewModel.user.isProUser {
                                Text("Upgrade to Pro to add up to 3 airports with custom weights to prioritize your preferred departure locations")
                                    .footnoteStyle()
                                    .foregroundColor(.textSecondary)
                            } else if viewModel.isWeightSumValid {
                                Text("Distribute weights across airports to prioritize deals from your preferred locations")
                                    .footnoteStyle()
                                    .foregroundColor(.textSecondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .animation(.uiSnappy, value: viewModel.isWeightSumValid)
                } else {
                    EmptyAirportsView {
                        showingAddAirport = true
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))
                }
                .animation(.uiSmooth, value: viewModel.preferredAirports.isEmpty)

                // Save Button
                if !viewModel.preferredAirports.isEmpty {
                    VStack(spacing: Spacing.sm) {
                        // Error recovery with retry and dismiss
                        if let error = viewModel.errorMessage {
                            ErrorBanner(
                                message: error,
                                actionTitle: "Try Again",
                                action: {
                                    Task {
                                        await viewModel.retryLastOperation()
                                    }
                                },
                                onDismiss: {
                                    viewModel.dismissError()
                                }
                            )
                            .animation(.uiStandard, value: viewModel.errorMessage != nil)
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
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .scale(scale: 1.05).combined(with: .opacity)
                                ))
                            } else if viewModel.showSaveSuccess {
                                // Success state with checkmark animation
                                HStack(spacing: Spacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.white)
                                        .font(.title3)
                                        .symbolEffect(.bounce, value: viewModel.showSaveSuccess)
                                    Text("Saved")
                                        .headlineStyle()
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Spacing.buttonVertical)
                                .background(Color.success)
                                .cornerRadius(CornerRadius.md)
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .scale(scale: 0.95).combined(with: .opacity)
                                ))
                            } else {
                                // Normal state with accessibility enhancements
                                VStack(spacing: Spacing.sm) {
                                    FLButton(title: "Save Changes", style: .primary) {
                                        Task {
                                            await viewModel.updatePreferredAirports()
                                        }
                                    }
                                    .disabled(!viewModel.isWeightSumValid)
                                    .opacity(viewModel.isWeightSumValid ? 1.0 : 0.6)
                                    .scaleEffect(viewModel.isWeightSumValid ? 1.0 : 0.98)
                                    .accessibilityHint(viewModel.isWeightSumValid ?
                                        "Saves your airport preferences" :
                                        "Weights must sum to 1.0 before saving")
                                    .transition(.scale(scale: 0.95).combined(with: .opacity))

                                    // Helper text for disabled state
                                    if !viewModel.isWeightSumValid {
                                        HStack(spacing: Spacing.xs) {
                                            Image(systemName: "info.circle.fill")
                                                .font(.caption)
                                                .foregroundColor(.textSecondary)
                                            Text("Adjust weights to total 1.0 to enable saving")
                                                .footnoteStyle()
                                                .foregroundColor(.textSecondary)
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .animation(.uiSnappy, value: viewModel.isWeightSumValid)
                            }
                        }
                        .animation(.uiStandard, value: viewModel.isSaving)
                        .animation(.uiStandard, value: viewModel.showSaveSuccess)
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
        .confirmationDialog(
            "Delete Airport",
            isPresented: Binding(
                get: { airportToDelete != nil },
                set: { if !$0 { airportToDelete = nil; deleteIndex = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete \(airportToDelete?.iata ?? "")", role: .destructive) {
                if let index = deleteIndex {
                    // Haptic feedback before deletion
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)

                    viewModel.removePreferredAirport(at: index)

                    // VoiceOver announcement
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "\(airportToDelete?.iata ?? "Airport") deleted"
                    )
                }
                airportToDelete = nil
                deleteIndex = nil
            }

            Button("Cancel", role: .cancel) {
                airportToDelete = nil
                deleteIndex = nil
            }
        } message: {
            if let airport = airportToDelete {
                Text("Remove \(airport.iata) from your preferred airports? This action cannot be undone.")
            }
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

    private let selectionFeedback = UISelectionFeedbackGenerator()

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
                        set: { newWeight in
                            // Light haptic feedback on value change (Pro users only)
                            if isProUser, newWeight != weight {
                                selectionFeedback.selectionChanged()
                            }
                            onWeightChange(newWeight)
                        }
                    ), in: 0.0...1.0, step: 0.1)
                        .tint(isProUser ? .brandBlue : .textTertiary.opacity(0.3))
                        .disabled(!isProUser)
                        .accessibilityLabel("Airport weight")
                        .accessibilityValue("\(Int(weight * 100)) percent")
                        .accessibilityHint(isProUser ? "Adjust to change priority" : "Upgrade to Pro to customize weights")
                        .onAppear {
                            selectionFeedback.prepare()
                        }
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
    @State private var searchTask: Task<Void, Never>?

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
                                // Cancel previous search task
                                searchTask?.cancel()

                                // Create new debounced search task
                                searchTask = Task {
                                    // Debounce: wait 300ms before searching
                                    try? await Task.sleep(for: .milliseconds(300))

                                    // Check if task was cancelled during sleep
                                    guard !Task.isCancelled else { return }

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
                                            HighlightedText(text: airport.iata, query: searchQuery)
                                                .headlineStyle()

                                            Spacer()

                                            Image(systemName: "plus.circle.fill")
                                                .foregroundColor(.brandBlue)
                                        }

                                        HighlightedText(text: airport.cityDisplay, query: searchQuery)
                                            .bodyStyle()
                                            .foregroundColor(.textSecondary)

                                        HighlightedText(text: airport.name, query: searchQuery)
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
        .onDisappear {
            // Cancel any pending search task to prevent memory leaks
            searchTask?.cancel()
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

// MARK: - Highlighted Text Helper

private struct HighlightedText: View {
    let text: String
    let query: String

    var body: some View {
        if query.isEmpty {
            Text(text)
        } else {
            highlightedText
        }
    }

    @ViewBuilder
    private var highlightedText: some View {
        let parts = highlightParts(in: text, matching: query)

        parts.reduce(Text("")) { result, part in
            result + Text(part.text)
                .foregroundColor(part.isHighlighted ? .brandBlue : .primary)
                .fontWeight(part.isHighlighted ? .semibold : .regular)
        }
    }

    private func highlightParts(in text: String, matching query: String) -> [(text: String, isHighlighted: Bool)] {
        var parts: [(text: String, isHighlighted: Bool)] = []
        let lowerText = text.lowercased()
        let lowerQuery = query.lowercased()

        guard let range = lowerText.range(of: lowerQuery) else {
            return [(text, false)]
        }

        let startIndex = text.index(text.startIndex, offsetBy: lowerText.distance(from: lowerText.startIndex, to: range.lowerBound))
        let endIndex = text.index(text.startIndex, offsetBy: lowerText.distance(from: lowerText.startIndex, to: range.upperBound))

        if startIndex > text.startIndex {
            parts.append((String(text[..<startIndex]), false))
        }

        parts.append((String(text[startIndex..<endIndex]), true))

        if endIndex < text.endIndex {
            parts.append((String(text[endIndex...]), false))
        }

        return parts
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
