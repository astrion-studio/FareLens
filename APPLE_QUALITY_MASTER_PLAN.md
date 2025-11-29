# Apple Quality Master Plan
## FareLens iOS App - Comprehensive Fix & Polish Strategy

**Created**: 2025-11-27
**Status**: Ready for Implementation
**Estimated Total Time**: 60-80 hours
**Priority**: All 10 PRs need polish to meet Apple HIG standards

---

## Executive Summary

Our specialized agents (product-designer & code-reviewer) reviewed all 10 PRs and identified **93 total issues**:
- **12 P0 Blocking Issues** (crashes, missing features, critical bugs)
- **32 P1 High Priority Issues** (UX, accessibility, performance, maintainability)
- **29 P2 Polish Issues** (microinter actions, animations, visual refinements)
- **20 Testing Gaps** (missing unit tests, accessibility tests, edge case coverage)

**Grade**: Current implementation is **B-** (Good, Not Great). Functional but lacks Apple-level polish.

**Goal**: Achieve **A+** (Apple Quality) across all dimensions:
- ✅ Functionality (already good)
- ⚠️ Polish (needs significant work)
- ⚠️ Accessibility (major gaps)
- ⚠️ Micro-interactions (missing entirely)
- ⚠️ Error Handling (needs improvement)
- ⚠️ Performance (search needs optimization)

---

## Phase-by-Phase Implementation Plan

### Phase 1: Fix P0 Blocking Issues (CRITICAL - Must Do First)
**Time Estimate**: 8-12 hours
**Priority**: BLOCKING
**Description**: Fix production crashes, missing features, and critical bugs

#### Tasks:

**1.1 - Fix Division by Zero Crash in AlertsView** (#P0-CR-1)
- **File**: `AlertsView.swift:160`
- **Issue**: Progress ring crashes when `dailyLimit = 0`
- **Fix**:
```swift
// Current (line 160):
.trim(from: 0, to: CGFloat(sent) / CGFloat(limit))

// Fixed:
.trim(from: 0, to: limit > 0 ? CGFloat(sent) / CGFloat(limit) : 0)
```
- **Why**: Prevents crash for edge case users or during testing
- **Time**: 15 minutes

**1.2 - Implement Gear Icon Navigation** (#P0-CR-2)
- **File**: `AlertsView.swift:66-72`
- **Issue**: Gear icon button does nothing (just a comment)
- **Fix**:
```swift
// Add @State variable:
@State private var showingAlertPreferences = false

// Update button:
Button(action: {
    showingAlertPreferences = true
}) {
    Image(systemName: "gear")
        .foregroundColor(.brandBlue)
}
.accessibilityLabel("Alert settings")
.sheet(isPresented: $showingAlertPreferences) {
    AlertPreferencesView(viewModel: AlertPreferencesViewModel(user: viewModel.user))
}
```
- **Why**: This was the entire point of PR #168
- **Time**: 30 minutes

**1.3 - Fix Search Algorithm Tier Count** (#P0-CR-3)
- **File**: `Airport.swift` search function
- **Issue**: PR title says "5-tier" but code implements 3-tier
- **Fix**: Either add missing tiers (IATA prefix, city prefix) OR update PR title/comments
- **Implementation**:
```swift
func search(query: String) -> [Airport] {
    guard query.count >= 2 else { return [] }

    let query = query.lowercased()
    var results: [(airport: Airport, tier: Int)] = []

    for airport in airports {
        let iata = airport.iata.lowercased()
        let name = airport.name.lowercased()
        let city = airport.city.lowercased()

        // Tier 1: Exact IATA match
        if iata == query {
            results.append((airport, 1))
        }
        // Tier 2: IATA prefix match
        else if iata.hasPrefix(query) {
            results.append((airport, 2))
        }
        // Tier 3: City prefix match
        else if city.hasPrefix(query) {
            results.append((airport, 3))
        }
        // Tier 4: Contains in name or city
        else if name.contains(query) || city.contains(query) {
            results.append((airport, 4))
        }
        // Tier 5: Fuzzy match (Levenshtein distance ≤ 2)
        else if levenshteinDistance(city, query) <= 2 {
            results.append((airport, 5))
        }
    }

    // Sort by tier, then alphabetically
    return results
        .sorted { $0.tier == $1.tier ? $0.airport.city < $1.airport.city : $0.tier < $1.tier }
        .map { $0.airport }
        .prefix(10)
        .map { $0 }
}
```
- **Time**: 1 hour

**1.4 - Fix Missing ErrorText Component** (#P0-CR-4)
- **File**: Onboarding/OnboardingView.swift
- **Issue**: References `ErrorText` component that doesn't exist
- **Fix**: Either create the component OR inline the error text styling
- **Quick Fix** (inline):
```swift
// Replace ErrorText(message: error.message) with:
Text(error.message)
    .footnoteStyle()
    .foregroundColor(.error)
    .padding(.horizontal, Spacing.xs)
```
- **Better Fix** (create reusable component):
```swift
// Create new file: DesignSystem/Components/ErrorText.swift
struct ErrorText: View {
    let message: String

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.error)
            Text(message)
                .footnoteStyle()
                .foregroundColor(.error)
        }
        .padding(.horizontal, Spacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(message)")
    }
}
```
- **Time**: 45 minutes

**1.5 - Replace String-Based Error Parsing** (#P0-CR-5)
- **File**: `SettingsViewModel.swift:91-96`
- **Issue**: Using `lowercased().contains()` for error matching is unsafe (locale bugs, internationalization issues)
- **Fix**:
```swift
// Instead of string matching, use typed errors:
catch let error as URLError {
    switch error.code {
    case .notConnectedToInternet, .networkConnectionLost, .timedOut:
        errorMessage = "Network error. Please check your connection and try again."
        feedbackGenerator.notificationOccurred(.error)
    case .userAuthenticationRequired:
        errorMessage = "Session expired. Please sign in again."
        feedbackGenerator.notificationOccurred(.error)
    default:
        errorMessage = "Failed to save airports. Please try again."
        feedbackGenerator.notificationOccurred(.error)
    }
} catch let error as AuthError {
    errorMessage = "Session expired. Please sign in again."
    feedbackGenerator.notificationOccurred(.error)
} catch {
    errorMessage = "Failed to save airports. Please try again."
    feedbackGenerator.notificationOccurred(.error)
}
```
- **Why**: Prevents displaying wrong error messages in non-English locales
- **Time**: 1 hour

**1.6 - Fix Untracked Background Task** (#P0-CR-6)
- **File**: `SettingsViewModel.swift:85-88`
- **Issue**: Detached Task can cause race conditions and incorrect UI state
- **Fix**:
```swift
// Add property to SettingsViewModel:
private var dismissSuccessTask: Task<Void, Never>?

// In updatePreferredAirports():
// Cancel any existing dismiss task
dismissSuccessTask?.cancel()

// Show success feedback
showSaveSuccess = true

// Haptic feedback (with optimized timing)
Task { @MainActor in
    try? await Task.sleep(for: .milliseconds(50))
    feedbackGenerator.notificationOccurred(.success)
}

// Auto-hide success message after 1.2 seconds
dismissSuccessTask = Task { @MainActor in
    try? await Task.sleep(for: .seconds(1.2))
    guard !Task.isCancelled else { return }
    showSaveSuccess = false
}

// In deinit or when view disappears:
deinit {
    dismissSuccessTask?.cancel()
}
```
- **Why**: Prevents race conditions when saving multiple times or navigating away
- **Time**: 45 minutes

**Phase 1 Total Time**: 4.5-6 hours

---

### Phase 2: Implement Progressive Disclosure for Free Tier
**Time Estimate**: 6-8 hours
**Priority**: P0 (UX critical)
**Description**: Show locked features to Free users with clear upgrade path (Apple Settings app pattern)

#### Tasks:

**2.1 - Show Disabled Weight Controls with Lock Icon** (#P0-UX-1)
- **Files**: `PreferredAirportsView.swift`, `AirportWeightRow`
- **Current**: Weight controls completely hidden for Free users
- **Fix**: Show disabled slider with lock icon and "Pro Feature" badge
- **Implementation**:
```swift
// In AirportWeightRow:
VStack(alignment: .leading, spacing: Spacing.xs) {
    HStack {
        Text("Weight: \(Int(weight * 100))%")
            .footnoteStyle()
            .foregroundColor(showWeightControls ? .textSecondary : .textTertiary)

        if !showWeightControls {
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundColor(.brandBlue)

            Text("Pro")
                .caption2Style()
                .foregroundColor(.white)
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, 2)
                .background(Color.brandBlue)
                .cornerRadius(4)
        }
    }
}

// Slider with disabled state
VStack(spacing: Spacing.xs) {
    Slider(value: .constant(weight), in: 0.0...1.0)
        .disabled(!showWeightControls)
        .opacity(showWeightControls ? 1.0 : 0.5)
        .tint(showWeightControls ? .brandBlue : .textTertiary)
        .onTapGesture {
            if !showWeightControls {
                // Trigger upgrade sheet
                onUpgradeRequired?()
            }
        }

    HStack {
        Text("0%").captionStyle()
        Spacer()
        Text("100%").captionStyle()
    }
    .foregroundColor(showWeightControls ? .textSecondary : .textTertiary)
}
.accessibilityHint(showWeightControls ? "" : "Pro feature. Double tap to learn more.")
```
- **Time**: 2 hours

**2.2 - Add Pro Badge and Upgrade Sheet Trigger** (#P0-UX-2)
- **Files**: `PreferredAirportsView.swift`
- **Fix**: Add onUpgradeRequired callback to AirportWeightRow
- **Implementation**:
```swift
// Update AirportWeightRow signature:
struct AirportWeightRow: View {
    let airport: PreferredAirport
    let weight: Double
    let showWeightControls: Bool
    let onWeightChange: ((Double) -> Void)?
    let onDelete: () -> Void
    let onUpgradeRequired: (() -> Void)?  // NEW

    // ... rest of implementation
}

// In PreferredAirportsView, pass upgrade callback:
AirportWeightRow(
    airport: airport,
    weight: airport.weight,
    showWeightControls: viewModel.user.subscriptionTier == .pro,
    onWeightChange: viewModel.user.subscriptionTier == .pro ? { newWeight in
        viewModel.updateAirportWeight(at: index, weight: newWeight)
    } : nil,
    onDelete: {
        viewModel.removePreferredAirport(at: index)
    },
    onUpgradeRequired: {
        viewModel.showingUpgradeSheet = true
    }
)
```
- **Time**: 1.5 hours

**2.3 - Show Total Weight Section for Free Users** (#P0-UX-3)
- **Files**: `PreferredAirportsView.swift:37-54`
- **Current**: Total Weight section completely hidden for Free users
- **Fix**: Show with educational message
- **Implementation**:
```swift
// Always show Total Weight section
Section {
    HStack {
        Text("Total Weight")
            .bodyStyle()
        Spacer()
        Text(String(format: "%.1f", viewModel.preferredAirports.totalWeight))
            .headlineStyle()
            .foregroundColor(viewModel.isWeightSumValid ? .success : .error)
    }
} footer: {
    if viewModel.user.subscriptionTier == .pro {
        if !viewModel.isWeightSumValid {
            Text("Weights must sum to 1.0")
                .footnoteStyle()
                .foregroundColor(.error)
        }
    } else {
        // Educational message for Free users
        HStack(spacing: Spacing.xs) {
            Image(systemName: "info.circle.fill")
                .font(.caption)
                .foregroundColor(.brandBlue)
            Text("Pro users can prioritize multiple airports with custom weights (e.g., 60% LAX, 40% SFO)")
                .footnoteStyle()
                .foregroundColor(.textSecondary)
        }
        .padding(.vertical, Spacing.xs)
    }
}
```
- **Time**: 1 hour

**Phase 2 Total Time**: 4.5-6 hours

---

### Phase 3: Add State Transition Animations
**Time Estimate**: 4-6 hours
**Priority**: P0 (UX critical)
**Description**: Add Apple-quality spring animations to all state changes

#### Tasks:

**3.1 - Add Spring Animations to Save Button** (#P0-UX-6)
- **File**: `PreferredAirportsView.swift:71-108`
- **Current**: Button morphs instantly between states (jarring)
- **Fix**:
```swift
Group {
    // ... button states
}
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.isSaving)
.animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.showSaveSuccess)
.transition(.scale.combined(with: .opacity))
```
- **Time**: 30 minutes

**3.2 - Add Empty State Transitions** (#P2-UX-2)
- **Files**: All empty state views
- **Fix**:
```swift
EmptyAlertsView(...)
    .transition(.opacity.combined(with: .scale(scale: 0.95)))
    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.filteredAlerts.isEmpty)
```
- **Time**: 1 hour

**3.3 - Add Checkmark Drawing Animation** (#P2-UX-6)
- **File**: `PreferredAirportsView.swift:88`
- **Fix**:
```swift
Image(systemName: "checkmark.circle.fill")
    .foregroundColor(.white)
    .font(.title3)
    .transition(.scale.combined(with: .opacity))
    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.showSaveSuccess)
```
- **Time**: 30 minutes

**Phase 3 Total Time**: 2-3 hours

---

### Phase 4: Implement Comprehensive Haptic Feedback
**Time Estimate**: 3-4 hours
**Priority**: P1 (High)
**Description**: Add tactile feedback for all user actions (Apple standard)

#### Tasks:

**4.1 - Add Prepared Haptic Generator** (#P1-CR-3)
- **File**: `SettingsViewModel.swift`
- **Fix**:
```swift
// Add property:
private let feedbackGenerator = UINotificationFeedbackGenerator()

// In init:
init(user: User) {
    self.user = user
    alertPreferences = user.alertPreferences
    preferredAirports = user.preferredAirports
    feedbackGenerator.prepare()
}

// Before save:
func updatePreferredAirports() async {
    feedbackGenerator.prepare()  // Re-prepare before use

    // ... save logic

    // On success:
    feedbackGenerator.notificationOccurred(.success)

    // On error:
    feedbackGenerator.notificationOccurred(.error)
}
```
- **Time**: 45 minutes

**4.2 - Add Slider Haptic Feedback** (#P1-UX-2)
- **File**: `PreferredAirportsView.swift` (AirportWeightRow)
- **Fix**:
```swift
Slider(value: Binding(
    get: { weight },
    set: { newValue in
        onWeightChange(newValue)
        // Add light haptic on value change
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
), in: 0.0...1.0, step: 0.05)  // Changed to 5% increments
```
- **Time**: 30 minutes

**4.3 - Optimize Haptic Timing** (#P1-UX-11)
- **File**: `SettingsViewModel.swift:80-82`
- **Current**: Haptic fires immediately, feels disconnected
- **Fix**: Delay haptic by 50ms to coincide with visual update
```swift
showSaveSuccess = true

Task { @MainActor in
    try? await Task.sleep(for: .milliseconds(50))
    feedbackGenerator.notificationOccurred(.success)
}
```
- **Time**: 15 minutes

**Phase 4 Total Time**: 1.5-2 hours

---

### Phase 5: Add Complete Accessibility Support
**Time Estimate**: 8-12 hours
**Priority**: P1 (High - Legal requirement under ADA)
**Description**: Make app fully usable with VoiceOver and accessibility features

#### Tasks:

**5.1 - Add VoiceOver Labels to All Interactive Elements** (#P1-CR-7)
- **Files**: All view files
- **Scope**: ~50+ interactive elements need labels
- **Examples**:
```swift
// Delete button (PreferredAirportsView.swift:175)
Button(action: onDelete) {
    Image(systemName: "trash")
}
.accessibilityLabel("Delete \(airport.iata) from preferred airports")
.accessibilityHint("Double tap to remove")

// Add airport button (PreferredAirportsView.swift:119)
Button(action: { ... }) {
    Image(systemName: "plus")
}
.accessibilityLabel("Add preferred airport")
.accessibilityHint("Double tap to add a new airport")

// Gear icon (AlertsView.swift:69)
Button(action: { ... }) {
    Image(systemName: "gear")
}
.accessibilityLabel("Alert settings")
.accessibilityHint("Double tap to configure alert preferences")

// Weight slider (AirportWeightRow)
Slider(...)
    .accessibilityLabel("Weight for \(airport.iata)")
    .accessibilityValue("\(Int(weight * 100)) percent")

// Progress ring (AlertsView.swift:154-168)
ZStack {
    // progress ring
}
.accessibilityElement(children: .ignore)
.accessibilityLabel("Alerts sent today")
.accessibilityValue("\(sent) of \(limit) sent")
```
- **Time**: 4-6 hours

**5.2 - Add Accessibility Hints for Pro-Locked Features** (#P1-UX-1)
- **Files**: All Pro-gated features
- **Fix**:
```swift
Slider(...)
    .disabled(!showWeightControls)
    .accessibilityHint(showWeightControls ?
        "Swipe up or down to adjust weight" :
        "Pro feature. Double tap to learn about upgrading")
```
- **Time**: 1 hour

**5.3 - Add VoiceOver Announcements for State Changes**
- **Files**: SettingsViewModel, AlertsViewModel
- **Fix**:
```swift
// After successful save:
showSaveSuccess = true
UIAccessibility.post(notification: .announcement, argument: "Airports saved successfully")

// After error:
errorMessage = "Failed to save"
UIAccessibility.post(notification: .announcement, argument: "Error: Failed to save airports")
```
- **Time**: 1 hour

**5.4 - Test with Dynamic Type**
- **Task**: Open app with Accessibility XXL text size, verify all layouts work
- **Time**: 1 hour

**5.5 - Test with VoiceOver**
- **Task**: Navigate entire app with VoiceOver, verify all actions work
- **Time**: 2 hours

**Phase 5 Total Time**: 9-11 hours

---

### Phase 6: Enhance Form Validation UX
**Time Estimate**: 4-6 hours
**Priority**: P1 (High)
**Description**: Make validation clear, helpful, and guide users to success

#### Tasks:

**6.1 - Add Inline Validation with Helpful Guidance** (#P1-UX-4)
- **File**: `PreferredAirportsView.swift:42-44`
- **Current**: Shows "Weights must sum to 1.0" when invalid
- **Fix**: Show current total and how much to adjust
```swift
Section {
    HStack {
        Text("Total Weight")
            .bodyStyle()
        Spacer()
        Text(String(format: "%.1f", viewModel.preferredAirports.totalWeight))
            .headlineStyle()
            .foregroundColor(viewModel.isWeightSumValid ? .success : .error)
    }
} footer: {
    if !viewModel.isWeightSumValid {
        let total = viewModel.preferredAirports.totalWeight
        let diff = abs(1.0 - total)
        let adjustment = total < 1.0 ? "add \(String(format: "%.1f", diff))" : "reduce by \(String(format: "%.1f", diff))"

        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.error)
            Text("Weights must sum to 1.0 (currently \(String(format: "%.1f", total)), \(adjustment))")
                .footnoteStyle()
                .foregroundColor(.error)
        }
    }
}
```
- **Time**: 1 hour

**6.2 - Add Swipe-to-Delete Confirmation** (#P1-UX-5)
- **File**: `PreferredAirportsView.swift:175-179`
- **Current**: Trash button has no confirmation
- **Fix**: Use swipeActions with confirmation alert
```swift
// Remove trash button, add swipe action:
.swipeActions(edge: .trailing, allowsFullSwipe: true) {
    Button(role: .destructive) {
        // Show confirmation alert
        showDeleteConfirmation = (true, index)
    } label: {
        Label("Delete", systemImage: "trash")
    }
}
.alert("Remove \(airport.iata)?", isPresented: $showDeleteConfirmation) {
    Button("Cancel", role: .cancel) { }
    Button("Remove", role: .destructive) {
        viewModel.removePreferredAirport(at: confirmationIndex)
    }
} message: {
    Text("This airport will be removed from your preferred list.")
}
```
- **Time**: 1.5 hours

**6.3 - Add Error Recovery Buttons** (#P1-UX-13)
- **File**: `PreferredAirportsView.swift:65-69`
- **Current**: Error message shown as text only
- **Fix**: Add retry button
```swift
if let error = viewModel.errorMessage {
    VStack(spacing: Spacing.xs) {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundColor(.error)
            Text(error)
                .footnoteStyle()
                .foregroundColor(.error)
        }

        Button("Try Again") {
            Task {
                await viewModel.updatePreferredAirports()
            }
        }
        .font(.footnote)
        .foregroundColor(.brandBlue)
    }
    .padding(Spacing.sm)
    .background(Color.error.opacity(0.1))
    .cornerRadius(CornerRadius.sm)
}
```
- **Time**: 45 minutes

**6.4 - Add Visual Feedback for Disabled Save Button** (#P1-UX-15)
- **File**: `PreferredAirportsView.swift:106`
- **Current**: Disabled button looks same as enabled
- **Fix**:
```swift
FLButton(title: "Save Changes", style: .primary) {
    Task {
        await viewModel.updatePreferredAirports()
    }
}
.disabled(!viewModel.isWeightSumValid)
.opacity(viewModel.isWeightSumValid ? 1.0 : 0.5)
.animation(.easeInOut(duration: 0.2), value: viewModel.isWeightSumValid)
```
- **Time**: 15 minutes

**Phase 6 Total Time**: 3.5-4.5 hours

---

### Phase 7: Optimize Search Experience
**Time Estimate**: 4-6 hours
**Priority**: P1 (High)
**Description**: Make search fast, efficient, and provide great results

#### Tasks:

**7.1 - Add Search Debouncing and Task Cancellation** (#P1-CR-5)
- **File**: `PreferredAirportsView.swift:268-270`
- **Current**: Every keystroke triggers search (10x more API calls than needed)
- **Fix**:
```swift
// Add to AddAirportSheet:
@State private var searchTask: Task<Void, Never>?

.onChange(of: searchQuery) { _, newValue in
    // Cancel previous search
    searchTask?.cancel()

    // Debounce: only search after 300ms of no typing
    searchTask = Task {
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }
        await performSearch(newValue)
    }
}

private func performSearch(_ query: String) async {
    guard !Task.isCancelled else { return }
    guard query.count >= 2 else {
        searchResults = []
        isSearching = false
        return
    }

    isSearching = true

    guard !Task.isCancelled else {
        isSearching = false
        return
    }

    searchResults = await AirportService.shared.search(query: query)
    isSearching = false
}
```
- **Time**: 1.5 hours

**7.2 - Add Minimum Query Length** (#Nit-1)
- **Already included in 7.1**

**7.3 - Add Result Highlighting**
- **File**: `PreferredAirportsView.swift` (AddAirportSheet result row)
- **Fix**: Highlight matching text in search results
```swift
// In ForEach(searchResults):
VStack(alignment: .leading, spacing: Spacing.xs) {
    Text(airport.iata)
        .headlineStyle()
        .foregroundColor(.textPrimary)
        // Add highlighting by making matching characters bold

    Text(highlightedText(airport.cityDisplay, query: searchQuery))
        .bodyStyle()
        .foregroundColor(.textSecondary)
}

private func highlightedText(_ text: String, query: String) -> AttributedString {
    var attributed = AttributedString(text)
    if let range = text.range(of: query, options: .caseInsensitive) {
        let attributedRange = AttributedString.Index(range.lowerBound, within: attributed)!..<AttributedString.Index(range.upperBound, within: attributed)!
        attributed[attributedRange].font = .headline
        attributed[attributedRange].foregroundColor = .brandBlue
    }
    return attributed
}
```
- **Time**: 2 hours

**7.4 - Optimize Search Algorithm Performance**
- **File**: `Airport.swift` search function
- **Current**: O(4n) - iterates through array 4 times
- **Fix**: O(n) - single pass with tier assignment
```swift
func search(query: String) -> [Airport] {
    guard query.count >= 2 else { return [] }

    let query = query.lowercased()
    var results: [(airport: Airport, tier: Int)] = []

    // Single pass through airports
    for airport in airports {
        let iata = airport.iata.lowercased()
        let name = airport.name.lowercased()
        let city = airport.city.lowercased()

        // Assign tier based on first match (tiers are mutually exclusive)
        let tier: Int? = {
            if iata == query { return 1 }
            if iata.hasPrefix(query) { return 2 }
            if city.hasPrefix(query) { return 3 }
            if name.contains(query) || city.contains(query) { return 4 }
            if levenshteinDistance(city, query) <= 2 { return 5 }
            return nil
        }()

        if let tier = tier {
            results.append((airport, tier))
        }
    }

    // Sort by tier, then alphabetically
    return results
        .sorted { $0.tier == $1.tier ? $0.airport.city < $1.airport.city : $0.tier < $1.tier }
        .prefix(10)
        .map { $0.airport }
}
```
- **Time**: 1 hour

**Phase 7 Total Time**: 4.5-6 hours

---

### Phase 8: Improve Empty States
**Time Estimate**: 4-6 hours
**Priority**: P1 (High)
**Description**: Make empty states helpful, actionable, and educational

#### Tasks:

**8.1 - Fix Deals Empty State Logic** (#P0-UX-deals)
- **File**: `DealsView.swift`
- **Issue**: "Create Watchlist" CTA doesn't make sense when no deals found
- **Fix**: Show context-aware CTA
```swift
// Check if user has preferred airports
if viewModel.user.preferredAirports.isEmpty {
    // No preferred airports set
    EmptyDealsView(
        title: "Set Your Home Airport",
        message: "Add your preferred airport to start seeing personalized flight deals",
        buttonTitle: "Set Preferred Airport",
        action: {
            // Navigate to airport settings
        }
    )
} else if viewModel.deals.isEmpty {
    // Has airports but no deals
    EmptyDealsView(
        title: "No deals right now",
        message: "We're actively monitoring flights from your preferred airports. Check back soon!",
        buttonTitle: "Create Watchlist",
        secondaryButtonTitle: "Adjust Preferences",
        action: {
            // Navigate to watchlist creation
        },
        secondaryAction: {
            // Navigate to settings
        }
    )
}
```
- **Time**: 2 hours

**8.2 - Add Actionable CTAs to Empty States** (#P1-UX-7)
- **Files**: AlertsView, DealsView
- **Fix**: Make CTAs specific and actionable
- **Time**: 1 hour

**8.3 - Add Onboarding Checklist to Alerts Empty State** (#P1-UX-8)
- **File**: `AlertsView.swift` (EmptyAlertsView)
- **Fix**:
```swift
VStack(spacing: Spacing.lg) {
    Image(systemName: "bell.slash")
        .font(.system(size: 64))
        .foregroundColor(.brandBlue.opacity(0.5))

    VStack(spacing: Spacing.sm) {
        Text("No alerts yet")
            .title2Style()

        Text("Complete setup to start receiving deals:")
            .bodyStyle()
            .foregroundColor(.textSecondary)
    }

    // Checklist
    VStack(alignment: .leading, spacing: Spacing.sm) {
        ChecklistItem(
            icon: viewModel.user.preferredAirports.isEmpty ? "circle" : "checkmark.circle.fill",
            text: "Set preferred airports",
            isComplete: !viewModel.user.preferredAirports.isEmpty,
            action: {
                // Navigate to airport settings
            }
        )

        ChecklistItem(
            icon: viewModel.user.watchlists.isEmpty ? "circle" : "checkmark.circle.fill",
            text: "Create a watchlist (optional)",
            isComplete: !viewModel.user.watchlists.isEmpty,
            action: {
                // Navigate to watchlist creation
            }
        )

        ChecklistItem(
            icon: "circle",
            text: "Receive your first alert",
            isComplete: false,
            action: nil
        )
    }
    .padding(Spacing.md)
    .background(Color.cardBackground)
    .cornerRadius(CornerRadius.md)
}
```
- **Time**: 2 hours

**8.4 - Improve InfoBox Visual Hierarchy** (#P2-UX-3)
- **File**: InfoBox component
- **Fix**: Use bullet points, better spacing
- **Time**: 30 minutes

**8.5 - Add Pull-to-Refresh to Empty States** (#P2-UX-5)
- **Files**: AlertsView, DealsView
- **Fix**: Add `.refreshable()` modifier to empty states
- **Time**: 30 minutes

**Phase 8 Total Time**: 6-8 hours

---

### Phase 9: Enhance Micro-interactions
**Time Estimate**: 3-5 hours
**Priority**: P1 (High)
**Description**: Add delightful details that make the app feel polished

#### Tasks:

**9.1 - Add Button Press Scale Animation**
- **Files**: All button components
- **Fix**:
```swift
// In FLButton component:
Button(action: action) {
    // ... button content
}
.scaleEffect(isPressed ? 0.96 : 1.0)
.animation(.easeInOut(duration: 0.1), value: isPressed)
.simultaneousGesture(
    DragGesture(minimumDistance: 0)
        .onChanged { _ in isPressed = true }
        .onEnded { _ in isPressed = false }
)
```
- **Time**: 1.5 hours

**9.2 - Reduce Success Auto-Dismiss Time** (#P1-UX-12)
- **File**: `SettingsViewModel.swift:86`
- **Current**: 2 seconds feels slow
- **Fix**: Change to 1.2 seconds (already in plan for Phase 1.6)
- **Time**: 5 minutes

**9.3 - Implement Optimistic UI** (#P1-UX-14)
- **File**: `SettingsViewModel.swift` updatePreferredAirports
- **Fix**:
```swift
func updatePreferredAirports() async {
    guard isWeightSumValid else {
        errorMessage = "Airport weights must sum to 1.0"
        return
    }

    // Optimistic update - update UI immediately
    let previousAirports = user.preferredAirports
    user.preferredAirports = preferredAirports

    isSaving = true
    errorMessage = nil
    defer { isSaving = false }

    do {
        let endpoint = APIEndpoint.updateUser(preferredAirports: preferredAirports)
        try await APIClient.shared.requestNoResponse(endpoint)

        // Success - show feedback
        showSaveSuccess = true
        feedbackGenerator.notificationOccurred(.success)

        // Auto-hide
        dismissSuccessTask?.cancel()
        dismissSuccessTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            showSaveSuccess = false
        }
    } catch {
        // Revert optimistic update on error
        user.preferredAirports = previousAirports
        preferredAirports = previousAirports

        // Handle error...
        feedbackGenerator.notificationOccurred(.error)
    }
}
```
- **Time**: 1 hour

**9.4 - Add Reduce Motion Support**
- **Files**: All animated views
- **Fix**:
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

// In animations:
.animation(reduceMotion ? nil : .spring(...), value: ...)
```
- **Time**: 1 hour

**Phase 9 Total Time**: 3.5-5 hours

---

### Phase 10: Code Quality Improvements
**Time Estimate**: 3-4 hours
**Priority**: P1 (Maintainability)
**Description**: Clean up code duplication, use modern APIs, fix patterns

#### Tasks:

**10.1 - Replace Duplicate Tier Checks** (#P1-CR-6)
- **Files**: PreferredAirportsView.swift (lines 22, 37)
- **Fix**: Use existing `user.isProUser` property
```swift
// Replace all instances of:
viewModel.user.subscriptionTier == .pro

// With:
viewModel.user.isProUser
```
- **Time**: 15 minutes

**10.2 - Make onWeightChange Optional** (#P1-CR-4)
- **File**: `PreferredAirportsView.swift:23-24`
- **Fix**: Only pass callback for Pro users (already covered in Phase 2)
- **Time**: Included in Phase 2

**10.3 - Replace errorMessage with assertionFailure** (#P1-CR-8)
- **Files**: SettingsViewModel.swift lines 115, 124
- **Fix**:
```swift
func removePreferredAirport(at index: Int) {
    guard index >= 0, index < preferredAirports.count else {
        assertionFailure("Invalid airport index: \(index), count: \(preferredAirports.count)")
        return
    }
    preferredAirports.remove(at: index)
}

func updateAirportWeight(at index: Int, weight: Double) {
    guard index >= 0, index < preferredAirports.count else {
        assertionFailure("Invalid airport index: \(index), count: \(preferredAirports.count)")
        return
    }
    preferredAirports[index].weight = weight
}
```
- **Time**: 15 minutes

**10.4 - Use Modern Task.sleep API** (#Nit-2)
- **Files**: All files using Task.sleep
- **Fix**: Replace `nanoseconds: 2_000_000_000` with `for: .seconds(2)`
- **Time**: 30 minutes

**10.5 - Add Floating Point Tolerance for Weight Validation** (#edge-case)
- **File**: PreferredAirport model or validation
- **Fix**:
```swift
extension [PreferredAirport] {
    var isValidWeightSum: Bool {
        let total = reduce(0.0) { $0 + $1.weight }
        return abs(total - 1.0) < 0.01  // 1% tolerance
    }
}
```
- **Time**: 15 minutes

**Phase 10 Total Time**: 1.5-2 hours

---

### Phase 11: Fix Gemini-Identified Issues
**Time Estimate**: 2-3 hours
**Priority**: P1
**Description**: Address specific issues raised by Gemini Code Assist

#### Tasks:

**11.1 - Fix UUID Handling for Preferred Airports**
- **File**: Backend PATCH /user endpoint
- **Issue**: Gemini noted "critical issue with how preferred airport UUIDs are handled"
- **Investigation**: Need to read backend code to see the specific issue
- **Time**: 1.5 hours

**11.2 - Verify Tier-Based Validations**
- **Files**: Backend validation logic
- **Task**: Test that Free tier (1 airport) and Pro tier (3 airports) limits work correctly
- **Time**: 1 hour

**Phase 11 Total Time**: 2.5-3.5 hours

---

### Phase 12: Testing & Verification
**Time Estimate**: 8-12 hours
**Priority**: CRITICAL
**Description**: Comprehensive testing to ensure everything works

#### Tasks:

**12.1 - Run Swift Test Suite**
- **Command**: `swift test`
- **Fix any failures**
- **Time**: 2 hours

**12.2 - Test on Device - Free Tier Account**
- **Scope**: Test all 10 PRs with Free tier account
- **Verify**: Weight controls locked, upgrade prompts, 1 airport limit
- **Time**: 2 hours

**12.3 - Test on Device - Pro Tier Account**
- **Scope**: Test all 10 PRs with Pro tier account
- **Verify**: Weight controls work, 3 airport limit, watchlist-only mode
- **Time**: 2 hours

**12.4 - Test with Network Link Conditioner**
- **Scenarios**: Slow 3G, 100% packet loss, high latency
- **Verify**: Loading states, error handling, retry logic
- **Time**: 1 hour

**12.5 - Run Xcode Accessibility Inspector**
- **Check**: All labels, hints, contrast ratios
- **Fix any violations**
- **Time**: 1.5 hours

**12.6 - Test Weight Validation Edge Cases**
- **Cases**: 0.999, 1.001, 0.0, 2.0, negative values
- **Verify**: Tolerance works, validation messages clear
- **Time**: 30 minutes

**12.7 - Test All Empty States**
- **Verify**: Correct messages, working CTAs, proper navigation
- **Time**: 1 hour

**12.8 - Test All Animations**
- **Verify**: Smooth transitions, no jank, Reduce Motion support
- **Time**: 1 hour

**Phase 12 Total Time**: 11-14 hours

---

## Total Time Estimates

| Phase | Description | Time Estimate |
|-------|-------------|---------------|
| 1 | P0 Blocking Issues | 8-12 hours |
| 2 | Progressive Disclosure | 6-8 hours |
| 3 | State Animations | 4-6 hours |
| 4 | Haptic Feedback | 3-4 hours |
| 5 | Accessibility | 8-12 hours |
| 6 | Form Validation | 4-6 hours |
| 7 | Search Optimization | 4-6 hours |
| 8 | Empty States | 4-6 hours |
| 9 | Micro-interactions | 3-5 hours |
| 10 | Code Quality | 3-4 hours |
| 11 | Gemini Issues | 2-3 hours |
| 12 | Testing | 8-12 hours |
| **TOTAL** | **All Phases** | **57-84 hours** |

**Realistic Estimate**: 60-70 hours for full Apple-quality implementation

---

## Priority Tiers for Implementation

### MUST DO (Blocking - 20-28 hours)
- Phase 1: P0 Blocking Issues (8-12h)
- Phase 2: Progressive Disclosure (6-8h)
- Phase 3: State Animations (4-6h)
- Phase 12: Testing (2h basics)

### SHOULD DO (Critical UX - 22-30 hours)
- Phase 4: Haptic Feedback (3-4h)
- Phase 5: Accessibility (8-12h)
- Phase 6: Form Validation (4-6h)
- Phase 7: Search Optimization (4-6h)
- Phase 8: Empty States (4-6h)

### NICE TO HAVE (Polish - 15-24 hours)
- Phase 9: Micro-interactions (3-5h)
- Phase 10: Code Quality (3-4h)
- Phase 11: Gemini Issues (2-3h)
- Phase 12: Full Testing (8-12h)

---

## Questions for User

Before starting implementation, I need clarification on:

1. **Scope**: Do you want me to implement ALL phases (60-70 hours), or prioritize certain phases?

2. **Backend Access**: Can I modify backend code (Cloudflare Workers) for Phase 11 (Gemini UUID issue)?

3. **Testing**: Do you have test accounts for Free and Pro tiers, or should I create test users?

4. **Deployment**: Should I create separate PRs for each phase, or combine related phases?

5. **ErrorText Component**: Should I create a reusable component or inline the styling? (Phase 1.4)

6. **Priority**: Are there specific features/screens that are higher priority? (e.g., onboarding more critical than settings?)

7. **Design System**: Should I create reusable components for patterns like ChecklistItem, or inline implementations?

---

## Success Criteria

We'll know we've achieved Apple quality when:

✅ **Functionality**: All 10 PRs work correctly with no crashes or bugs
✅ **Polish**: Smooth animations, delightful haptics, no jarring transitions
✅ **Accessibility**: Full VoiceOver support, WCAG AAA compliance
✅ **Performance**: Search is instant (<100ms), no lag or jank
✅ **Progressive Disclosure**: Free users understand Pro features and how to unlock them
✅ **Error Handling**: Clear, actionable error messages with recovery options
✅ **Empty States**: Helpful, educational, with clear next steps
✅ **Testing**: 100% pass rate on all tests, works on Free + Pro tiers

**Target Grade**: A+ (Apple Quality Standard)

---

## Next Steps

1. **User reviews this plan and answers questions**
2. **User approves scope and priority**
3. **I begin Phase 1 implementation**
4. **We iterate through phases sequentially**
5. **We test thoroughly after each phase**
6. **We ship polished, Apple-quality code**

Ready to start when you are! 🚀
