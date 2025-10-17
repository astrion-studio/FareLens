// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

struct WatchlistsView: View {
    @State var viewModel: WatchlistsViewModel
    @Environment(AppState.self) var appState: AppState
    @State private var showingCreateSheet = false

    var body: some View {
        NavigationView {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task {
                            await viewModel.loadWatchlists()
                        }
                    }
                } else if viewModel.watchlists.isEmpty {
                    EmptyWatchlistsView {
                        showingCreateSheet = true
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: Spacing.cardSpacing) {
                            // Quota indicator
                            if !viewModel.canAddWatchlist {
                                QuotaWarning(
                                    current: viewModel.watchlists.count,
                                    max: viewModel.user.maxWatchlists,
                                    isProUser: viewModel.user.isProUser
                                )
                            }

                            // Watchlist cards
                            ForEach(viewModel.watchlists) { watchlist in
                                WatchlistCard(watchlist: watchlist)
                                    .onTapGesture {
                                        // Navigate to edit
                                    }
                                    .contextMenu {
                                        Button(action: {
                                            Task {
                                                await viewModel.toggleActive(watchlist)
                                            }
                                        }) {
                                            Label(
                                                watchlist.isActive ? "Pause" : "Resume",
                                                systemImage: watchlist.isActive ? "pause.fill" : "play.fill"
                                            )
                                        }

                                        Button(role: .destructive, action: {
                                            Task {
                                                await viewModel.deleteWatchlist(watchlist)
                                            }
                                        }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(Spacing.screenHorizontal)
                    }
                }
            }
            .navigationTitle("Watchlists")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        if viewModel.canAddWatchlist {
                            showingCreateSheet = true
                        } else {
                            viewModel.showingUpgradeAlert = true
                        }
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(.brandBlue)
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreateWatchlistView(viewModel: viewModel)
            }
            .alert("Upgrade to Pro", isPresented: $viewModel.showingUpgradeAlert) {
                Button("Upgrade", role: .none) {
                    // Show paywall
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "Free plan: \(viewModel.user.maxWatchlists) watchlists max. Upgrade to Pro for unlimited watchlists."
                )
            }
        }
        .task {
            await viewModel.loadWatchlists()
        }
    }
}

// MARK: - Watchlist Card

struct WatchlistCard: View {
    let watchlist: Watchlist

    var body: some View {
        FLCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(watchlist.name)
                            .title3Style()
                            .foregroundColor(.textPrimary)

                        Text("\(watchlist.origin) → \(watchlist.displayDestination)")
                            .bodyStyle()
                            .foregroundColor(.textSecondary)
                    }

                    Spacer()

                    if !watchlist.isActive {
                        FLBadge(text: "Paused", style: .custom(
                            backgroundColor: Color.warning.opacity(0.15),
                            foregroundColor: .warning
                        ))
                    }
                }

                // Filters
                if watchlist.dateRange != nil || watchlist.maxPrice != nil {
                    Divider()

                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        if let dateRange = watchlist.displayDateRange {
                            Label(dateRange, systemImage: "calendar")
                                .footnoteStyle()
                        }

                        if let maxPrice = watchlist.displayMaxPrice {
                            Label(maxPrice, systemImage: "dollarsign.circle")
                                .footnoteStyle()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

struct EmptyWatchlistsView: View {
    let onCreate: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "bookmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.brandBlue.opacity(0.5))

            VStack(spacing: Spacing.sm) {
                Text("No watchlists yet")
                    .title2Style()
                    .foregroundColor(.textPrimary)

                Text("Create a watchlist to get alerts\nwhen deals match your preferences")
                    .bodyStyle()
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            FLButton(title: "Create Your First Watchlist", style: .primary, action: onCreate)
                .padding(.horizontal, Spacing.xl)
        }
        .padding(Spacing.screenHorizontal)
    }
}

// MARK: - Quota Warning

struct QuotaWarning: View {
    let current: Int
    let max: Int
    let isProUser: Bool

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.warning)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(isProUser ? "Watchlist Limit" : "Free Plan: \(current)/\(max) watchlists used")
                    .headlineStyle()
                    .foregroundColor(.textPrimary)

                if !isProUser {
                    Text("Upgrade to Pro for unlimited watchlists")
                        .footnoteStyle()
                }
            }

            Spacer()

            if !isProUser {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundColor(.textTertiary)
            }
        }
        .padding(Spacing.md)
        .background(Color.warning.opacity(0.1))
        .cornerRadius(CornerRadius.sm)
    }
}
