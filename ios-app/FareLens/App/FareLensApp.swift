// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

@main
struct FareLensApp: App {
    @State private var appState = AppState()

    init() {
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear {
                    // Skip initialization when running unit tests to avoid crashes
                    // Tests should mock/inject their own dependencies
                    guard !isRunningTests else { return }

                    Task {
                        await appState.initialize()
                    }
                }
        }
    }

    /// Detects if the app is running in a test environment
    private var isRunningTests: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    private func configureAppearance() {
        // Configure app-wide appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
