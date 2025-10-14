import SwiftUI

/// FareLens Design System - Color Palette
/// Based on DESIGN.md lines 107-147
extension Color {
    // MARK: - Brand Colors

    /// Primary Brand Color - iOS System Blue Gradient
    /// Light & Dark Mode: #0A84FF → #1E96FF
    static let brandBlue = Color(hex: "0A84FF")
    static let brandBlueLift = Color(hex: "1E96FF")

    /// Primary Brand Gradient
    static let brandGradient = LinearGradient(
        colors: [brandBlue, brandBlueLift],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Secondary - Midnight Slate (Adaptive)
    static let backgroundPrimary = Color("BackgroundPrimary") // Adaptive: #1A1D29 dark, #F8F9FB light
    static let backgroundSecondary = Color("BackgroundSecondary") // Adaptive: #2D3142 dark, #E5E7EB light

    /// Accent - Sunset Orange
    static let accentOrange = Color(hex: "FF6B35")

    // MARK: - Semantic Colors

    /// Success - Savings confirmed, deal saved
    static let success = Color(hex: "10B981")

    /// Warning - Price rising, limited availability
    static let warning = Color(hex: "F59E0B")

    /// Error - Search failed, quota exceeded
    static let error = Color(hex: "EF4444")

    /// Info - Price prediction, tips
    static let info = Color(hex: "3B82F6")

    // MARK: - Neutral Scale (Adaptive)

    /// Primary text color (adaptive)
    static let textPrimary = Color("TextPrimary") // #111827 light, #F8F9FB dark

    /// Secondary text color (adaptive)
    static let textSecondary = Color("TextSecondary") // #4B5563 light, #9CA3AF dark

    /// Tertiary text color (adaptive)
    static let textTertiary = Color("TextTertiary") // #6B7280 light, #9CA3AF dark

    /// Divider color (adaptive)
    static let divider = Color("Divider") // #D1D5DB light, #3E4354 dark

    /// Card background (adaptive)
    static let cardBackground = Color("CardBackground") // #FFFFFF light, #2D3142 dark

    // MARK: - Deal Score Colors

    /// Deal score: Excellent (90-100)
    static let scoreExcellent = success

    /// Deal score: Great (80-89)
    static let scoreGreat = brandBlue

    /// Deal score: Good (70-79)
    static let scoreGood = warning

    /// Deal score: Fair (<70)
    static let scoreFair = Color.gray

    // MARK: - Liquid Glass Effect Colors

    /// Glass overlay (for liquid glass effects)
    static let glassOverlay = Color.white.opacity(0.15)

    /// Glass border (for liquid glass effects)
    static let glassBorder = Color.white.opacity(0.2)

    // MARK: - Helper Initializer

    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

/// Gradient presets for common use cases
extension LinearGradient {
    /// Primary brand gradient (blue → blue lift)
    static let brand = LinearGradient(
        colors: [Color.brandBlue, Color.brandBlueLift],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Sunset gradient for hot deals
    static let sunset = LinearGradient(
        colors: [Color(hex: "FF6B35"), Color(hex: "FF8C61")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Success gradient for confirmed savings
    static let successGradient = LinearGradient(
        colors: [Color(hex: "10B981"), Color(hex: "34D399")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
