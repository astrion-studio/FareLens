// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Observation
import SwiftUI

struct AlertPreferencesView: View {
    @Bindable var viewModel: SettingsViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            List {
                // Master Toggle
                Section {
                    Toggle("Enable Alerts", isOn: $viewModel.alertPreferences.enabled)
                        .tint(.brandBlue)
                        .onChange(of: viewModel.alertPreferences.enabled) { _ in
                            Task {
                                await viewModel.updateAlertPreferences()
                            }
                        }
                } header: {
                    Text("Alerts")
                        .headlineStyle()
                } footer: {
                    Text("Receive push notifications when deals match your watchlists")
                        .footnoteStyle()
                }

                // Quiet Hours
                Section {
                    Toggle("Quiet Hours", isOn: $viewModel.alertPreferences.quietHoursEnabled)
                        .tint(.brandBlue)
                        .onChange(of: viewModel.alertPreferences.quietHoursEnabled) { _ in
                            Task {
                                await viewModel.updateAlertPreferences()
                            }
                        }

                    if viewModel.alertPreferences.quietHoursEnabled {
                        HStack {
                            Text("Start")
                                .bodyStyle()
                            Spacer()
                            Picker("", selection: $viewModel.alertPreferences.quietHoursStart) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(formatHour(hour))
                                        .tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: viewModel.alertPreferences.quietHoursStart) { _ in
                                Task {
                                    await viewModel.updateAlertPreferences()
                                }
                            }
                        }

                        HStack {
                            Text("End")
                                .bodyStyle()
                            Spacer()
                            Picker("", selection: $viewModel.alertPreferences.quietHoursEnd) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text(formatHour(hour))
                                        .tag(hour)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: viewModel.alertPreferences.quietHoursEnd) { _ in
                                Task {
                                    await viewModel.updateAlertPreferences()
                                }
                            }
                        }
                    }
                } header: {
                    Text("Quiet Hours")
                        .headlineStyle()
                } footer: {
                    Text(viewModel.alertPreferences.quietHoursEnabled ?
                        "No alerts between \(formatHour(viewModel.alertPreferences.quietHoursStart)) and \(formatHour(viewModel.alertPreferences.quietHoursEnd))" :
                        "Receive alerts at any time")
                        .footnoteStyle()
                }

                // Watchlist-Only Mode (Pro Feature)
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack(spacing: Spacing.xs) {
                                Text("Watchlist-Only Mode")
                                    .bodyStyle()

                                if !viewModel.user.isProUser {
                                    FLBadge(text: "Pro", style: .custom(
                                        backgroundColor: Color.warning.opacity(0.15),
                                        foregroundColor: .warning
                                    ))
                                }
                            }

                            Text("Only receive alerts for deals matching your watchlists")
                                .footnoteStyle()
                        }

                        Spacer()

                        Toggle("", isOn: $viewModel.alertPreferences.watchlistOnlyMode)
                            .tint(.brandBlue)
                            .disabled(!viewModel.user.isProUser)
                            .onChange(of: viewModel.alertPreferences.watchlistOnlyMode) { _ in
                                if viewModel.user.isProUser {
                                    Task {
                                        await viewModel.updateAlertPreferences()
                                    }
                                } else {
                                    viewModel.alertPreferences.watchlistOnlyMode = false
                                    viewModel.showingUpgradeSheet = true
                                }
                            }
                    }
                } footer: {
                    if !viewModel.user.isProUser {
                        Text("Upgrade to Pro to enable watchlist-only mode")
                            .footnoteStyle()
                            .foregroundColor(.warning)
                    }
                }

                // Alert Caps Info
                Section {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            Text("Daily Alert Limit")
                                .bodyStyle()
                            Spacer()
                            Text("\(viewModel.user.maxAlertsPerDay) alerts/day")
                                .headlineStyle()
                                .foregroundColor(.brandBlue)
                        }

                        if !viewModel.user.isProUser {
                            Text("Upgrade to Pro for 6 alerts/day (instead of 3)")
                                .footnoteStyle()
                                .foregroundColor(.textSecondary)
                        }
                    }
                } header: {
                    Text("Limits")
                        .headlineStyle()
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Alert Preferences")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }
}
