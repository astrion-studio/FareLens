import SwiftUI

struct AlertsView: View {
    @State var viewModel: AlertsViewModel
    @State private var selectedFilter: AlertFilter = .all

    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task {
                            await viewModel.loadAlerts(forceRefresh: true)
                        }
                    }
                } else if viewModel.filteredAlerts.isEmpty {
                    EmptyAlertsView(filter: selectedFilter)
                } else {
                    VStack(spacing: 0) {
                        // Filter Picker
                        FilterPicker(selectedFilter: $selectedFilter)
                            .padding(.horizontal, Spacing.screenHorizontal)
                            .padding(.vertical, Spacing.sm)
                            .onChange(of: selectedFilter) { newFilter in
                                viewModel.applyFilter(newFilter)
                            }

                        // Alert List
                        ScrollView {
                            LazyVStack(spacing: Spacing.cardSpacing) {
                                // Today's Alert Count
                                if selectedFilter == .all || selectedFilter == .today {
                                    TodayAlertCounter(
                                        sent: viewModel.alertsSentToday,
                                        limit: viewModel.dailyLimit
                                    )
                                }

                                // Alert History
                                ForEach(viewModel.filteredAlerts) { alert in
                                    AlertHistoryCard(alert: alert)
                                        .onTapGesture {
                                            viewModel.openDealDetail(alert)
                                        }
                                }
                            }
                            .padding(Spacing.screenHorizontal)
                        }
                        .refreshable {
                            await viewModel.refreshAlerts()
                        }
                    }
                }
            }
            .navigationTitle("Alerts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Navigate to alert preferences
                    }) {
                        Image(systemName: "gear")
                            .foregroundColor(.brandBlue)
                    }
                }
            }
        }
        .task {
            await viewModel.loadAlerts()
        }
    }
}

// MARK: - Filter Picker

enum AlertFilter: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
}

struct FilterPicker: View {
    @Binding var selectedFilter: AlertFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(AlertFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        isSelected: selectedFilter == filter,
                        onTap: {
                            selectedFilter = filter
                        }
                    )
                }
            }
        }
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .footnoteStyle()
                .foregroundColor(isSelected ? .white : .textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .background(isSelected ? Color.brandBlue : Color.cardBackground)
                .cornerRadius(CornerRadius.sm)
        }
    }
}

// MARK: - Today Alert Counter

struct TodayAlertCounter: View {
    let sent: Int
    let limit: Int

    var body: some View {
        FLCard {
            HStack(spacing: Spacing.md) {
                Image(systemName: "bell.badge.fill")
                    .foregroundColor(.brandBlue)
                    .font(.title2)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Today's Alerts")
                        .title3Style()
                        .foregroundColor(.textPrimary)

                    Text("\(sent) of \(limit) sent")
                        .bodyStyle()
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                // Progress Ring
                ZStack {
                    Circle()
                        .stroke(Color.textTertiary.opacity(0.2), lineWidth: 6)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: CGFloat(sent) / CGFloat(limit))
                        .stroke(progressColor, lineWidth: 6)
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))

                    Text("\(sent)")
                        .headlineStyle()
                        .foregroundColor(.textPrimary)
                }
            }
        }
    }

    private var progressColor: Color {
        let percentage = Double(sent) / Double(limit)
        if percentage >= 1.0 {
            return .error
        } else if percentage >= 0.75 {
            return .warning
        } else {
            return .success
        }
    }
}

// MARK: - Alert History Card

struct AlertHistoryCard: View {
    let alert: AlertHistory

    var body: some View {
        FLCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("\(alert.deal.origin) → \(alert.deal.destination)")
                            .title3Style()
                            .foregroundColor(.textPrimary)

                        Text(alert.formattedTimestamp)
                            .captionStyle()
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    FLBadge(text: "\(alert.deal.dealScore)", style: .score(alert.deal.dealScore))
                }

                // Deal Info
                HStack(spacing: Spacing.lg) {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "calendar")
                            .foregroundColor(.textSecondary)
                            .font(.caption)
                        Text(alert.deal.departureDate.formatted(date: .abbreviated, time: .omitted))
                            .footnoteStyle()
                            .foregroundColor(.textSecondary)
                    }

                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "airplane")
                            .foregroundColor(.textSecondary)
                            .font(.caption)
                        Text(alert.deal.airline)
                            .footnoteStyle()
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()
                }

                Divider()

                // Price & Action
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(alert.deal.formattedPrice)
                            .title2Style()
                            .foregroundColor(.brandBlue)

                        Text("\(alert.deal.discountPercent)% off")
                            .captionStyle()
                            .foregroundColor(.success)
                    }

                    Spacer()

                    if alert.isStillAvailable {
                        FLCompactButton(icon: "arrow.up.right", title: "Book") {
                            // Open booking URL
                        }
                    } else {
                        Text("Expired")
                            .captionStyle()
                            .foregroundColor(.error)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.error.opacity(0.1))
                            .cornerRadius(CornerRadius.xs)
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

struct EmptyAlertsView: View {
    let filter: AlertFilter

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "bell.slash")
                .font(.system(size: 64))
                .foregroundColor(.brandBlue.opacity(0.5))

            VStack(spacing: Spacing.sm) {
                Text("No alerts \(filterText)")
                    .title2Style()
                    .foregroundColor(.textPrimary)

                Text("We'll notify you when we find deals matching your preferences")
                    .bodyStyle()
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            FLButton(title: "Adjust Alert Settings", style: .secondary) {
                // Navigate to alert preferences
            }
            .padding(.horizontal, Spacing.xl)
        }
        .padding(Spacing.screenHorizontal)
    }

    private var filterText: String {
        switch filter {
        case .all:
            return "yet"
        case .today:
            return "today"
        case .thisWeek:
            return "this week"
        case .thisMonth:
            return "this month"
        }
    }
}
