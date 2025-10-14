import Foundation

/// Represents a historical alert that was sent to a user
struct AlertHistory: Identifiable, Codable {
    let id: UUID
    let deal: FlightDeal
    let sentAt: Date
    let wasClicked: Bool
    let expiresAt: Date?

    var isStillAvailable: Bool {
        guard let expiresAt = expiresAt else { return true }
        return expiresAt > Date()
    }

    var formattedTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: sentAt, relativeTo: Date())
    }
}
