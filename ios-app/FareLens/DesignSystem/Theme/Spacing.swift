import SwiftUI

/// FareLens Design System - Spacing & Layout
/// 8pt base grid system for consistent spacing
struct Spacing {
    /// 4pt - Micro spacing (icon padding, badge spacing)
    static let xs: CGFloat = 4

    /// 8pt - Small spacing (text line gaps, compact lists)
    static let sm: CGFloat = 8

    /// 12pt - Default spacing (card content padding)
    static let md: CGFloat = 12

    /// 16pt - Medium spacing (element gaps, section padding)
    static let lg: CGFloat = 16

    /// 24pt - Large spacing (screen margins, card spacing)
    static let xl: CGFloat = 24

    /// 32pt - Extra large spacing (section gaps)
    static let xxl: CGFloat = 32

    /// 48pt - Huge spacing (screen top/bottom margins)
    static let xxxl: CGFloat = 48

    // MARK: - Common Use Cases

    /// Standard screen horizontal padding
    static let screenHorizontal: CGFloat = lg // 16pt

    /// Standard screen vertical padding
    static let screenVertical: CGFloat = xl // 24pt

    /// Card inner padding
    static let cardPadding: CGFloat = lg // 16pt

    /// Card spacing (between cards)
    static let cardSpacing: CGFloat = md // 12pt

    /// Button padding (horizontal)
    static let buttonHorizontal: CGFloat = xl // 24pt

    /// Button padding (vertical)
    static let buttonVertical: CGFloat = md // 12pt

    /// Minimum touch target (WCAG AAA)
    static let minTouchTarget: CGFloat = 44
}

/// Corner radius values for consistent rounded corners
struct CornerRadius {
    /// 4pt - Small radius (badges, tags)
    static let xs: CGFloat = 4

    /// 8pt - Medium radius (buttons, chips)
    static let sm: CGFloat = 8

    /// 12pt - Default radius (cards, inputs)
    static let md: CGFloat = 12

    /// 16pt - Large radius (modal sheets, large cards)
    static let lg: CGFloat = 16

    /// 24pt - Extra large radius (hero elements)
    static let xl: CGFloat = 24

    /// Full circle (badges, avatars)
    static let full: CGFloat = 9999
}

/// Shadow presets for depth hierarchy
struct Shadows {
    /// Subtle shadow for cards
    static let card = Shadow(
        color: Color.black.opacity(0.08),
        radius: 8,
        x: 0,
        y: 2
    )

    /// Medium shadow for floating elements
    static let floating = Shadow(
        color: Color.black.opacity(0.12),
        radius: 16,
        x: 0,
        y: 4
    )

    /// Heavy shadow for modals
    static let modal = Shadow(
        color: Color.black.opacity(0.20),
        radius: 24,
        x: 0,
        y: 8
    )

    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
}

/// View modifier for applying shadows
extension View {
    func cardShadow() -> some View {
        self.shadow(
            color: Shadows.card.color,
            radius: Shadows.card.radius,
            x: Shadows.card.x,
            y: Shadows.card.y
        )
    }

    func floatingShadow() -> some View {
        self.shadow(
            color: Shadows.floating.color,
            radius: Shadows.floating.radius,
            x: Shadows.floating.x,
            y: Shadows.floating.y
        )
    }

    func modalShadow() -> some View {
        self.shadow(
            color: Shadows.modal.color,
            radius: Shadows.modal.radius,
            x: Shadows.modal.x,
            y: Shadows.modal.y
        )
    }
}
