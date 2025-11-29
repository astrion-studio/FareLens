// FareLens - Flight Deal Alert App
// Copyright © 2025 FareLens. All rights reserved.

import SwiftUI

/// Reusable animation presets for consistent motion across the app
/// Following Apple's design principles for natural, predictable animations
extension Animation {
    /// Fast, snappy animation for buttons and small UI changes
    /// Response: 0.3s, Damping: 0.7
    /// Use for: Button presses, toggles, small state changes
    static let uiSnappy = Animation.spring(response: 0.3, dampingFraction: 0.7)

    /// Standard animation for most UI transitions
    /// Response: 0.4s, Damping: 0.75
    /// Use for: Form validation, modal presentation, content updates
    static let uiStandard = Animation.spring(response: 0.4, dampingFraction: 0.75)

    /// Smooth animation for large view transitions
    /// Response: 0.5s, Damping: 0.8
    /// Use for: Screen transitions, large content changes, empty states
    static let uiSmooth = Animation.spring(response: 0.5, dampingFraction: 0.8)
}
