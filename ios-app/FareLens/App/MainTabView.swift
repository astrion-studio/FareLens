import SwiftUI

struct MainTabView: View {
    @Environment(AppState.self) var appState: AppState
    @State private var selectedTab = 0

    var body: some View {
        Group {
            if let user = appState.currentUser {
                TabView(selection: $selectedTab) {
                    DealsView(
                        viewModel: DealsViewModel(user: user)
                    )
                    .tabItem {
                        Label("Deals", systemImage: selectedTab == 0 ? "airplane.departure" : "airplane")
                    }
                    .tag(0)

                    WatchlistsView(
                        viewModel: WatchlistsViewModel(user: user)
                    )
                    .tabItem {
                        Label("Watchlists", systemImage: selectedTab == 1 ? "bookmark.fill" : "bookmark")
                    }
                    .tag(1)

                    AlertsView(
                        viewModel: AlertsViewModel(user: user)
                    )
                    .tabItem {
                        Label("Alerts", systemImage: selectedTab == 2 ? "bell.fill" : "bell")
                    }
                    .tag(2)

                    SettingsView(
                        viewModel: SettingsViewModel(user: user)
                    )
                    .tabItem {
                        Label("Settings", systemImage: selectedTab == 3 ? "gear" : "gearshape")
                    }
                    .tag(3)
                }
                .accentColor(.brandBlue)
            } else {
                // Should never happen - ContentView ensures user exists before showing MainTabView
                // But defensive programming requires handling this case
                ErrorView(message: "User session not found. Please sign in again.") {
                    Task {
                        await appState.signOut()
                    }
                }
            }
        }
    }
}
