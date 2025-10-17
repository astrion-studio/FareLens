// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) var appState: AppState

    var body: some View {
        Group {
            if appState.isLoading {
                LoadingView()
            } else if appState.isAuthenticated {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 64))
                    .foregroundColor(.brandBlue)

                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.brandBlue)

                Text("Loading...")
                    .bodyStyle()
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: Spacing.xl) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.error)

                VStack(spacing: Spacing.sm) {
                    Text("Something went wrong")
                        .title2Style()
                        .foregroundColor(.textPrimary)

                    Text(message)
                        .bodyStyle()
                        .foregroundColor(.textSecondary)
                        .multilineTextAlignment(.center)
                }

                FLButton(title: "Try Again", style: .primary) {
                    retry()
                }
                .padding(.horizontal, Spacing.screenHorizontal)
            }
            .padding(Spacing.screenHorizontal)
        }
    }
}
