// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

struct SettingsView: View {
    @State var viewModel: SettingsViewModel
    @Environment(AppState.self) var appState: AppState

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationView {
            ZStack {
                Color.backgroundPrimary.ignoresSafeArea()

                List {
                    // Account Section
                    Section {
                        Button(action: {
                            if !viewModel.user.isProUser {
                                viewModel.showingUpgradeSheet = true
                            }
                            // TODO: For Pro users, navigate to account management
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(viewModel.user.email)
                                        .bodyStyle()
                                        .foregroundColor(.textPrimary)

                                    Text(viewModel.user.subscriptionTier.displayName)
                                        .footnoteStyle()
                                }

                                Spacer()

                                if !viewModel.user.isProUser {
                                    FLBadge(text: "Upgrade", style: .custom(
                                        backgroundColor: Color.brandBlue.opacity(0.15),
                                        foregroundColor: .brandBlue
                                    ))
                                }

                                Image(systemName: "chevron.right")
                                    .font(.footnote)
                                    .foregroundColor(.textTertiary)
                            }
                            .padding(.vertical, Spacing.xs)
                        }
                        .buttonStyle(.plain)
                    } header: {
                        Text("Account")
                            .headlineStyle()
                    }

                    // Alerts Section
                    Section {
                        NavigationLink(destination: AlertPreferencesView(viewModel: viewModel)) {
                            SettingsRow(
                                icon: "bell.fill",
                                iconColor: .brandBlue,
                                title: "Alert Preferences",
                                subtitle: viewModel.alertPreferences.enabled ? "Enabled" : "Disabled"
                            )
                        }

                        NavigationLink(destination: PreferredAirportsView(viewModel: viewModel)) {
                            SettingsRow(
                                icon: "airplane.departure",
                                iconColor: .brandBlue,
                                title: "Preferred Airports",
                                subtitle: "\(viewModel.preferredAirports.count) selected"
                            )
                        }
                    } header: {
                        Text("Alerts")
                            .headlineStyle()
                    }

                    // Notifications Section
                    Section {
                        NavigationLink(destination: NotificationSettingsView()) {
                            SettingsRow(
                                icon: "app.badge.fill",
                                iconColor: .error,
                                title: "Notifications",
                                subtitle: "Manage permissions"
                            )
                        }
                    } header: {
                        Text("Notifications")
                            .headlineStyle()
                    }

                    // Subscription Section
                    Section {
                        if viewModel.user.isProUser {
                            Button(action: {
                                // Manage subscription
                            }) {
                                SettingsRow(
                                    icon: "crown.fill",
                                    iconColor: .warning,
                                    title: "Manage Subscription",
                                    subtitle: "Active"
                                )
                            }
                        } else {
                            Button(action: {
                                viewModel.showingUpgradeSheet = true
                            }) {
                                SettingsRow(
                                    icon: "crown.fill",
                                    iconColor: .warning,
                                    title: "Upgrade to Pro",
                                    subtitle: "Unlimited watchlists, 6 alerts/day"
                                )
                            }
                        }
                    } header: {
                        Text("Subscription")
                            .headlineStyle()
                    }

                    // About Section
                    Section {
                        if let privacyURL = viewModel.privacyPolicyURL {
                            Link(destination: privacyURL) {
                                SettingsRow(
                                    icon: "hand.raised.fill",
                                    iconColor: .textSecondary,
                                    title: "Privacy Policy",
                                    subtitle: nil
                                )
                            }
                        }

                        if let termsURL = viewModel.termsOfServiceURL {
                            Link(destination: termsURL) {
                                SettingsRow(
                                    icon: "doc.text.fill",
                                    iconColor: .textSecondary,
                                    title: "Terms of Service",
                                    subtitle: nil
                                )
                            }
                        }

                        Button(action: {
                            Task {
                                await appState.signOut()
                            }
                        }) {
                            SettingsRow(
                                icon: "arrow.right.square.fill",
                                iconColor: .error,
                                title: "Sign Out",
                                subtitle: nil
                            )
                        }
                    } header: {
                        Text("About")
                            .headlineStyle()
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $viewModel.showingUpgradeSheet) {
                PaywallView()
            }
        }
    }
}

// MARK: - Settings Row

struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String?

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 28, height: 28)
                .font(.headline)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .bodyStyle()
                    .foregroundColor(.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .footnoteStyle()
                }
            }

            Spacer()
        }
        .padding(.vertical, Spacing.xs)
    }
}
