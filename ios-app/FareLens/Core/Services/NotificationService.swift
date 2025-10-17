// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import Foundation
import OSLog
import UIKit
import UserNotifications

protocol NotificationServiceProtocol {
    func requestAuthorization() async -> Bool
    func registerForRemoteNotifications() async
    func sendDealAlert(deal: FlightDeal, userId: UUID) async
}

actor NotificationService: NSObject, NotificationServiceProtocol, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()

    private let notificationCenter = UNUserNotificationCenter.current()
    private var isAuthorized = false
    private let logger = Logger(subsystem: "com.farelens.app", category: "notifications")

    override init() {
        super.init()
        notificationCenter.delegate = self
    }

    /// Request notification permissions from user
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            isAuthorized = granted
            logger.info("Notification authorization: \(granted ? "granted" : "denied", privacy: .public)")
            return granted
        } catch {
            logger
                .error("Failed to request notification authorization: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Register for remote push notifications (APNs)
    func registerForRemoteNotifications() async {
        await MainActor.run {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Send local notification for a flight deal
    func sendDealAlert(deal: FlightDeal, userId: UUID) async {
        guard isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = "New Flight Deal!"
        content.body = "\(deal.origin) → \(deal.destination) for \(deal.formattedPrice) (\(deal.discountPercent)% off)"
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "DEAL_ALERT"
        content.userInfo = [
            "dealId": deal.id.uuidString,
            "userId": userId.uuidString,
            "origin": deal.origin,
            "destination": deal.destination,
            "price": deal.totalPrice,
            "dealScore": deal.dealScore,
            "deepLink": deal.deepLink,
        ]

        // Immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: deal.id.uuidString,
            content: content,
            trigger: trigger
        )

        do {
            try await notificationCenter.add(request)
            logger
                .info(
                    "Deal alert scheduled: \(deal.id.uuidString, privacy: .public) for \(deal.origin, privacy: .public) → \(deal.destination, privacy: .public)"
                )
        } catch {
            logger.error("Failed to schedule notification: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Get pending notification count
    func getPendingNotifications() async -> Int {
        let requests = await notificationCenter.pendingNotificationRequests()
        return requests.count
    }

    /// Clear all notifications
    func clearAllNotifications() async {
        notificationCenter.removeAllDeliveredNotifications()
        notificationCenter.removeAllPendingNotificationRequests()
    }

    /// Update badge count
    func updateBadgeCount(_ count: Int) async {
        await MainActor.run {
            UIApplication.shared.applicationIconBadgeNumber = count
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Show notification even when app is in foreground
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo

        // Handle notification tap
        if let dealId = userInfo["dealId"] as? String,
           let deepLink = userInfo["deepLink"] as? String
        {
            // Open deep link to deal detail
            await handleDealNotificationTap(dealId: dealId, deepLink: deepLink)
        }
    }

    private func handleDealNotificationTap(dealId: String, deepLink: String) async {
        // Post notification to open deal detail screen
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenDealDetail"),
                object: nil,
                userInfo: ["dealId": dealId, "deepLink": deepLink]
            )
        }
    }
}
