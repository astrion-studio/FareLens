// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI


@main
struct FareLensApp: App {
    @State private var appState = AppState()
    @State private var configValidation: ConfigValidator.ValidationResult?

    init() {
        configureAppearance()
        // Validate configuration at app startup (before any services initialize)
        _configValidation = State(initialValue: ConfigValidator.validate())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                // Show config error view if validation failed
                if let validation = configValidation, !validation.isValid {
                    ConfigErrorView(errors: validation.errors)
                } else {
                    // Config is valid - proceed with normal app flow
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
                        .onOpenURL { url in
                            Task {
                                await handleDeepLink(url)
                            }
                        }
                }
            }
        }
    }

    /// Handles incoming deep links from Supabase authentication
    private func handleDeepLink(_ url: URL) async {
        // Handle Supabase authentication callback/confirmation
        if url.scheme == "farelens" {
            // Extract session from URL and pass to Supabase client
            await AuthService.shared.handleAuthCallback(url: url)

            // Reinitialize app state to reflect the new auth status
            await appState.initialize()
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
