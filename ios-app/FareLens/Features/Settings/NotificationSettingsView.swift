import SwiftUI
import UserNotifications
import Observation

struct NotificationSettingsView: View {
    @State private var viewModel = NotificationSettingsViewModel()

    var body: some View {
        ZStack {
            Color.backgroundPrimary.ignoresSafeArea()

            List {
                // Permission Status
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Notification Status")
                                .bodyStyle()
                                .foregroundColor(.textPrimary)

                            Text(viewModel.permissionStatus.description)
                                .footnoteStyle()
                                .foregroundColor(viewModel.permissionStatus.color)
                        }

                        Spacer()

                        Image(systemName: viewModel.permissionStatus.icon)
                            .foregroundColor(viewModel.permissionStatus.color)
                            .font(.title2)
                    }
                    .padding(.vertical, Spacing.sm)

                    if !viewModel.isAuthorized {
                        Button(action: {
                            viewModel.requestPermission()
                        }) {
                            HStack {
                                Image(systemName: "bell.badge.fill")
                                Text("Enable Notifications")
                                    .headlineStyle()
                            }
                            .foregroundColor(.brandBlue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                            .background(Color.brandBlue.opacity(0.1))
                            .cornerRadius(CornerRadius.sm)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    if viewModel.permissionStatus == .denied {
                        Text("Notifications are disabled. Enable them in Settings to receive deal alerts.")
                            .footnoteStyle()
                            .foregroundColor(.textSecondary)
                    }
                }

                // Notification Types
                Section {
                    PermissionRow(
                        icon: "tag.fill",
                        iconColor: .brandBlue,
                        title: "Deal Alerts",
                        subtitle: "Get notified about new flight deals",
                        isEnabled: viewModel.alertsEnabled
                    )

                    PermissionRow(
                        icon: "bell.fill",
                        iconColor: .warning,
                        title: "Price Drops",
                        subtitle: "Watchlist price drop notifications",
                        isEnabled: viewModel.priceDropsEnabled
                    )

                    PermissionRow(
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .error,
                        title: "Expiring Deals",
                        subtitle: "Alerts when deals are about to expire",
                        isEnabled: viewModel.expiringDealsEnabled
                    )
                } header: {
                    Text("Notification Types")
                        .headlineStyle()
                } footer: {
                    Text("You'll only receive the number of alerts allowed by your plan (Free: 3/day, Pro: 6/day).")
                        .footnoteStyle()
                        .foregroundColor(.textSecondary)
                }

                // Delivery Settings
                Section {
                    HStack {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.textSecondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Sound")
                                .bodyStyle()
                                .foregroundColor(.textPrimary)
                            Text(viewModel.soundEnabled ? "Enabled" : "Disabled")
                                .footnoteStyle()
                        }

                        Spacer()
                    }
                    .padding(.vertical, Spacing.xs)

                    HStack {
                        Image(systemName: "app.badge.fill")
                            .foregroundColor(.textSecondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Badge")
                                .bodyStyle()
                                .foregroundColor(.textPrimary)
                            Text(viewModel.badgeEnabled ? "Enabled" : "Disabled")
                                .footnoteStyle()
                        }

                        Spacer()
                    }
                    .padding(.vertical, Spacing.xs)

                    HStack {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.textSecondary)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text("Alerts")
                                .bodyStyle()
                                .foregroundColor(.textPrimary)
                            Text(viewModel.alertStyleEnabled ? "Enabled" : "Disabled")
                                .footnoteStyle()
                        }

                        Spacer()
                    }
                    .padding(.vertical, Spacing.xs)
                } header: {
                    Text("Delivery Settings")
                        .headlineStyle()
                } footer: {
                    Text("These settings are managed in iOS Settings. Tap below to change them.")
                        .footnoteStyle()
                        .foregroundColor(.textSecondary)
                }

                // Open Settings Button
                if viewModel.permissionStatus == .denied || viewModel.permissionStatus == .authorized {
                    Section {
                        Button(action: {
                            viewModel.openSettings()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Open iOS Settings")
                                    .bodyStyle()
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .font(.caption)
                            }
                            .foregroundColor(.brandBlue)
                            .padding(.vertical, Spacing.xs)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.checkPermissionStatus()
        }
    }
}

// MARK: - Permission Row

struct PermissionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let isEnabled: Bool

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

                Text(subtitle)
                    .footnoteStyle()
                    .foregroundColor(.textSecondary)
            }

            Spacer()

            if isEnabled {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.success)
                    .font(.title3)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.textTertiary)
                    .font(.title3)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - View Model

@Observable
@MainActor
final class NotificationSettingsViewModel {
    var permissionStatus: PermissionStatus = .notDetermined
    var alertsEnabled = false
    var soundEnabled = false
    var badgeEnabled = false
    var alertStyleEnabled = false
    var priceDropsEnabled = false
    var expiringDealsEnabled = false

    var isAuthorized: Bool {
        permissionStatus == .authorized || permissionStatus == .provisional
    }

    func checkPermissionStatus() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .notDetermined:
            permissionStatus = .notDetermined
        case .denied:
            permissionStatus = .denied
        case .authorized:
            permissionStatus = .authorized
            updateSettingsFromPermissions(settings)
        case .provisional:
            permissionStatus = .provisional
            updateSettingsFromPermissions(settings)
        case .ephemeral:
            permissionStatus = .authorized
            updateSettingsFromPermissions(settings)
        @unknown default:
            permissionStatus = .notDetermined
        }
    }

    func requestPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                if granted {
                    await checkPermissionStatus()
                } else {
                    permissionStatus = .denied
                }
            } catch {
                permissionStatus = .denied
            }
        }
    }

    func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func updateSettingsFromPermissions(_ settings: UNNotificationSettings) {
        alertsEnabled = settings.alertSetting == .enabled
        soundEnabled = settings.soundSetting == .enabled
        badgeEnabled = settings.badgeSetting == .enabled
        alertStyleEnabled = settings.alertStyle != .none

        // For notification types, we'll default to enabled if notifications are authorized
        // In a real app, these would be stored in user preferences
        priceDropsEnabled = isAuthorized
        expiringDealsEnabled = isAuthorized
    }
}

// MARK: - Permission Status

enum PermissionStatus {
    case notDetermined
    case denied
    case authorized
    case provisional

    var description: String {
        switch self {
        case .notDetermined:
            return "Not Configured"
        case .denied:
            return "Disabled"
        case .authorized:
            return "Enabled"
        case .provisional:
            return "Provisional"
        }
    }

    var color: Color {
        switch self {
        case .notDetermined:
            return .textSecondary
        case .denied:
            return .error
        case .authorized:
            return .success
        case .provisional:
            return .warning
        }
    }

    var icon: String {
        switch self {
        case .notDetermined:
            return "bell.slash.fill"
        case .denied:
            return "bell.slash.fill"
        case .authorized:
            return "bell.fill"
        case .provisional:
            return "bell.badge.fill"
        }
    }
}
