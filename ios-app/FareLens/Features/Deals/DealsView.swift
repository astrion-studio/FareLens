// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

struct DealsView: View {
    @State var viewModel: DealsViewModel
    @Environment(AppState.self) var appState: AppState
    @State private var showingFilters = false
    @State private var selectedDeal: FlightDeal?
    @State private var showingCreateWatchlist = false
    @State private var watchlistsViewModel: WatchlistsViewModel?

    var body: some View {
        NavigationStack {
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
                    EmptyDealsView(onCreateWatchlist: {
                        showingCreateWatchlist = true
                    })
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
                                    Button {
                                        selectedDeal = deal
                                    } label: {
                                        FLDealCard(deal: deal)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
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
        .sheet(item: $selectedDeal) { deal in
            DealDetailView(deal: deal)
        }
        .sheet(isPresented: $showingCreateWatchlist) {
            if let viewModel = watchlistsViewModel {
                CreateWatchlistView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.loadDeals()

            // Initialize WatchlistsViewModel once at view lifecycle
            if let user = appState.currentUser {
                watchlistsViewModel = WatchlistsViewModel(user: user)
            }
        }
        .onChange(of: appState.currentUser) { _, newUser in
            // Update ViewModel if user changes
            if let user = newUser {
                watchlistsViewModel = WatchlistsViewModel(user: user)
            } else {
                watchlistsViewModel = nil
            }
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
    let onCreateWatchlist: () -> Void

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

            FLButton(title: "Create Watchlist", style: .secondary, action: onCreateWatchlist)
        }
        .padding(Spacing.screenHorizontal)
    }
}
