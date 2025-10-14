import SwiftUI

struct DealsView: View {
    @State var viewModel: DealsViewModel
    @Environment(AppState.self) var appState: AppState
    @State private var showingFilters = false

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color.backgroundPrimary.ignoresSafeArea()

                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task {
                            await viewModel.loadDeals(forceRefresh: true)
                        }
                    }
                } else if viewModel.deals.isEmpty {
                    EmptyDealsView()
                } else {
                    VStack(spacing: 0) {
                        // Filter bar
                        FilterBar(showingFilters: $showingFilters)
                            .padding(.horizontal, Spacing.screenHorizontal)
                            .padding(.top, Spacing.sm)

                        // Deals list
                        ScrollView {
                            LazyVStack(spacing: Spacing.cardSpacing) {
                                ForEach(viewModel.deals) { deal in
                                    FLDealCard(deal: deal)
                                        .onTapGesture {
                                            // Navigate to deal detail
                                        }
                                }
                            }
                            .padding(Spacing.screenHorizontal)
                        }
                        .refreshable {
                            await viewModel.refreshDeals()
                        }
                    }
                }
            }
            .navigationTitle("Deals")
            .navigationBarTitleDisplayMode(.large)
        }
        .task {
            await viewModel.loadDeals()
        }
    }
}

// MARK: - Supporting Views

struct FilterBar: View {
    @Binding var showingFilters: Bool

    var body: some View {
        HStack(spacing: Spacing.sm) {
            FLCompactButton(icon: "line.3.horizontal.decrease", title: "Filter") {
                showingFilters.toggle()
            }

            FLCompactButton(icon: "arrow.up.arrow.down", title: "Sort") {
                // Show sort options
            }

            Spacer()

            FLIconButton(icon: "arrow.clockwise") {
                // Refresh deals
            }
        }
    }
}

struct EmptyDealsView: View {
    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 64))
                .foregroundColor(.brandBlue.opacity(0.5))

            VStack(spacing: Spacing.sm) {
                Text("No deals right now")
                    .title2Style()
                    .foregroundColor(.textPrimary)

                Text("We're scanning thousands of flights.\nCheck back soon for amazing deals!")
                    .bodyStyle()
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            FLButton(title: "Create Watchlist", style: .secondary) {
                // Navigate to watchlists
            }
        }
        .padding(Spacing.screenHorizontal)
    }
}

