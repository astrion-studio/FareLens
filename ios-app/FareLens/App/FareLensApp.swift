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
                    Task {
                        await appState.initialize()
                    }
                }
        }
    }

    private func configureAppearance() {
        // Configure app-wide appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
