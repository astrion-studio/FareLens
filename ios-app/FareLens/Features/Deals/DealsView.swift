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
                    EmptyDealsView(
                        user: appState.user,
                        watchlistsViewModel: watchlistsViewModel,
                        onCreateWatchlist: {
                            showingCreateWatchlist = true
                        }
                    )
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
            } else {
                // Graceful fallback if ViewModel not ready (race condition or user logged out)
                VStack(spacing: Spacing.md) {
                    ProgressView()
                    Text("Loading...")
                        .bodyStyle()
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.backgroundPrimary)
            }
        }
        .task {
            await viewModel.loadDeals()
        }
        .onAppear {
            // Initialize WatchlistsViewModel once on appear (not in .task to avoid race)
            if watchlistsViewModel == nil, let user = appState.currentUser {
                watchlistsViewModel = WatchlistsViewModel(user: user)
            }
        }
        .onChange(of: appState.currentUser?.id) { _, newUserId in
            // Only recreate if user ID actually changed (UUID? is Equatable)
            if let newUserId,
               let current = appState.currentUser,
               watchlistsViewModel?.user.id != newUserId
            {
                watchlistsViewModel = WatchlistsViewModel(user: current)
            } else if newUserId == nil {
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
    let user: User?
    let watchlistsViewModel: WatchlistsViewModel?
    let onCreateWatchlist: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "airplane.departure")
                .font(.system(size: 64))
                .foregroundColor(.brandBlue.opacity(0.5))

            VStack(spacing: Spacing.sm) {
                Text("No deals right now")
                    .title2Style()
                    .foregroundColor(.textPrimary)

                if user?.preferredAirports.isEmpty == true {
                    // User has no preferred airports - guide them to set one
                    Text("Set your preferred airport to start seeing personalized deals!")
                        .bodyStyle()
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    // User has airports - show standard message
                    Text("We're scanning thousands of flights.\nCheck back soon for amazing deals!")
                        .bodyStyle()
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // Show appropriate CTA based on user state
            if user?.preferredAirports.isEmpty == true {
                // User has no airports - guide them to Settings
                NavigationLink(destination: SettingsView()) {
                    HStack {
                        Image(systemName: "location.fill")
                        Text("Set Preferred Airport")
                    }
                }
                .buttonStyle(FLButtonStyle(style: .primary))
            } else {
                // User has airports - optionally show Create Watchlist button
                FLButton(title: "Create Watchlist", style: .secondary, action: onCreateWatchlist)
                    .disabled(watchlistsViewModel == nil)
                    .opacity(watchlistsViewModel == nil ? 0.5 : 1.0)
            }
        }
        .padding(Spacing.screenHorizontal)
    }
}
