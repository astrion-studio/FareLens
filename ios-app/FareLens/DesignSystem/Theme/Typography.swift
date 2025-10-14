import SwiftUI

/// FareLens Design System - Typography
/// Based on DESIGN.md lines 157-243
extension Font {
    // MARK: - Display (Hero Prices)

    /// Display - 56pt Bold
    /// Usage: Deal prices ($420), savings amounts
    static let display = Font.system(size: 56, weight: .bold, design: .default)

    // MARK: - Titles

    /// Title 1 - 34pt Bold
    /// Usage: Screen titles (Deal Feed, Watchlist)
    static let title1 = Font.system(size: 34, weight: .bold, design: .default)

    /// Title 2 - 28pt Semibold
    /// Usage: Deal card destinations (Tokyo, Paris)
    static let title2 = Font.system(size: 28, weight: .semibold, design: .default)

    /// Title 3 - 22pt Semibold
    /// Usage: Route names (SFO → NRT)
    static let title3 = Font.system(size: 22, weight: .semibold, design: .default)

    // MARK: - Body Text

    /// Headline - 17pt Semibold
    /// Usage: CTA labels, filter chips
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)

    /// Body - 17pt Regular
    /// Usage: Descriptions, metadata
    static let body = Font.system(size: 17, weight: .regular, design: .default)

    /// Callout - 16pt Regular
    /// Usage: Supporting text, timestamps
    static let callout = Font.system(size: 16, weight: .regular, design: .default)

    /// Subheadline - 15pt Regular
    /// Usage: Tertiary info
    static let subheadline = Font.system(size: 15, weight: .regular, design: .default)

    // MARK: - Small Text

    /// Footnote - 13pt Regular
    /// Usage: Airline, duration, timestamps
    static let footnote = Font.system(size: 13, weight: .regular, design: .default)

    /// Caption 1 - 12pt Regular
    /// Usage: Legal disclaimers, "Updated 5m ago"
    static let caption1 = Font.system(size: 12, weight: .regular, design: .default)

    /// Caption 2 - 11pt Regular
    /// Usage: Badge labels, tags
    static let caption2 = Font.system(size: 11, weight: .regular, design: .default)
}

/// Text style modifiers for consistent styling
extension Text {
    /// Apply display style (hero prices)
    func displayStyle() -> Text {
        self.font(.display)
            .kerning(-0.5) // Tighter kerning for large text
    }

    /// Apply title 1 style (screen headers)
    func title1Style() -> Text {
        self.font(.title1)
            .kerning(-0.4)
    }

    /// Apply title 2 style (section headers)
    func title2Style() -> Text {
        self.font(.title2)
            .kerning(-0.3)
    }

    /// Apply title 3 style (card headers)
    func title3Style() -> Text {
        self.font(.title3)
    }

    /// Apply headline style (emphasis)
    func headlineStyle() -> Text {
        self.font(.headline)
    }

    /// Apply body style (main content)
    func bodyStyle() -> Text {
        self.font(.body)
    }

    /// Apply callout style (secondary)
    func calloutStyle() -> Text {
        self.font(.callout)
    }

    /// Apply subheadline style (tertiary)
    func subheadlineStyle() -> Text {
        self.font(.subheadline)
    }

    /// Apply footnote style (metadata)
    func footnoteStyle() -> Text {
        self.font(.footnote)
            .foregroundColor(.textSecondary)
    }

    /// Apply caption style (small text)
    func captionStyle() -> Text {
        self.font(.caption1)
            .foregroundColor(.textTertiary)
    }
}

/// Line height multipliers (for Text with specific line spacing needs)
struct LineHeight {
    static let tight: CGFloat = 1.1    // Display text
    static let normal: CGFloat = 1.2   // Titles
    static let relaxed: CGFloat = 1.3  // Body, Headlines
    static let loose: CGFloat = 1.4    // Long-form content
}
