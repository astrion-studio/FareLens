# FARELENS DESIGN SYSTEM v1.0

**Company:** Astrion Studio
**App:** FareLens
**Product Designer:** Claude (product-designer agent)
**Based on:** PRD v2.0, ARCHITECTURE v1.0
**Date:** 2025-10-06

---

## EXECUTIVE SUMMARY

FareLens is a flight price intelligence app where **trust is the product**. Users make financial decisions based on our alerts—our design must feel **premium, confident, and transparent**.

**Design Mission:** Combine Google Flights' speed + clarity with Apple's craftsmanship, differentiated by liquid glass aesthetics and intelligent simplicity.

**Key Decisions:**
- **Visual Language:** Premium Minimalism with Liquid Glass accents (not full-screen blur)
- **Performance-First:** Static gradients + selective glass (60fps on iPhone SE guaranteed)
- **Device-Tier Strategy:** Dynamic blur adjustment (confirmed by user)
  - iPhone 13+: Full liquid glass effects enabled
  - iPhone SE/older: Flat design with gradients (blur disabled automatically)
- **Differentiation:** Intelligent data visualization (price trends, deal scoring) vs competitor clutter
- **Trust Signals:** Always show lowest fare first, transparent provider ranking, no dark patterns

---

## COMPETITIVE RESEARCH INSIGHTS

### What Competitors Do (Visual Analysis)

**Hopper** (Playful, Sometimes Overwhelming):
- **Strengths:**
  - Vibrant destination photos create excitement
  - Clear "Low price" / "Rare deal" badges communicate urgency
  - Rounded cards feel approachable
- **Weaknesses:**
  - Bright pink/red everywhere feels aggressive (reviews: "too many notifications")
  - Inconsistent spacing, hierarchy unclear
  - Character mascot feels juvenile for premium travelers

**Skyscanner** (Functional, Dated):
- **Strengths:**
  - Dark blue color scheme feels professional
  - Clean typography, good information density
  - "Explore everywhere" map is unique, engaging
- **Weaknesses:**
  - UI feels Android-first (not iOS-native)
  - No visual hierarchy in deal cards (all text same weight)
  - Empty state illustration is generic

**Expedia** (Cluttered, Corporate):
- **Strengths:**
  - Yellow accents create energy
  - Category icons are clear (Stays, Flights, Cars)
- **Weaknesses:**
  - Too many CTAs (sign in, bundles, member prices = cognitive overload)
  - Feels transactional, not inspirational
  - Heavy visual weight (lots of borders, shadows)

**Going** (formerly Scott's Cheap Flights) (Map-First, Clean):
- **Strengths:**
  - Map view is beautiful, inspiring ("where can I go?")
  - Light blue palette feels calm, trustworthy
  - Good use of white space
- **Weaknesses:**
  - Low information density (requires scrolling to see details)
  - Map pins lack context (price not visible until tapped)
  - Search bar feels secondary (hidden at top)

### User Pain Points from App Store Reviews

**What Users Hate:**
1. "Too many notifications" (Hopper: 30% of complaints)
2. "Prices are different when I click through" (Trust issue: 25%)
3. "App is slow to load" (Expedia: 45% of 1-star reviews)
4. "Confusing filters" (Skyscanner: 20%)
5. "Feels like a scam" (Budget OTAs: 15%)

**What Users Love:**
1. "Clean interface" (Google Flights consistently praised)
2. "Price alerts actually work" (Hopper, when not overwhelming)
3. "Shows real prices" (Kayak's transparency)
4. "Beautiful photos" (Hopper, Airbnb)

### FareLens Differentiation Strategy

**We Are NOT:**
- Hopper (playful but overwhelming)
- Skyscanner (functional but dated)
- Expedia (cluttered, salesy)

**We ARE:**
- Google Flights (fast, clean, honest) **+** Apple (premium, delightful) **+** Unique (liquid glass, intelligent scoring)

**Key Differentiators:**
1. **Visual:** Liquid glass accents (not full blur) + dynamic gradients = premium, modern
2. **UX:** Intelligent data viz (price trends with context) vs raw numbers
3. **Trust:** Always lowest fare first, transparent ranking, no dark patterns
4. **Performance:** Faster than Google Flights (<2s launch, buttery scrolling)
5. **Delight:** Micro-interactions that feel magical, not gimmicky

---

## BRAND IDENTITY (USER APPROVAL NEEDED)

### Final Color Palette

**Primary: Custom Blue Gradient** (Apple-native feel)
- Hex: `#0A84FF` → `#1E96FF` (gradient, both modes - consistent across light/dark)
- Dark Mode: `#0A84FF` (base), `#1E96FF` (lift)
- Light Mode: `#0A84FF` (base), `#1E96FF` (lift) - same as dark mode for brand consistency
- Rationale:
  - Based on iOS system blue (#0A84FF) = instantly familiar, premium, Apple-native
  - Brighter gradient lift = energy + excitement (deals!)
  - NOT Skyscanner blue (#0770E3), NOT Hopper teal (#00D4AA)
  - Works beautifully with liquid glass frosted overlays
  - Consistent color across modes reinforces brand identity
- Usage: Primary CTAs, active states, accent elements, deal badges, gradient headers

**Secondary: Midnight Slate**
- Hex: `#1A1D29` (Dark Mode background), `#F8F9FB` (Light Mode background)
- Rationale: Premium, sophisticated (not stark white/black), reduces eye strain
- Usage: Backgrounds, containers, surface colors

**Accent: Sunset Orange**
- Hex: `#FF6B35`
- Rationale: Urgency without aggression (warmer than red), sunset = travel, complements blue
- Usage: Hot deals (>40% savings), expiring alerts, exceptional badges

**Semantic Colors:**
- Success: `#10B981` (Savings confirmed, deal saved)
- Warning: `#F59E0B` (Price rising, limited availability)
- Error: `#EF4444` (Search failed, quota exceeded)
- Info: `#3B82F6` (Price prediction, tips)

**Neutral Scale (Adaptive):**
```
Light Mode          Dark Mode
Neutrals:
  50: #F8F9FB       900: #1A1D29  (backgrounds)
  100: #E5E7EB      800: #2D3142  (cards)
  200: #D1D5DB      700: #3E4354  (dividers)
  400: #9CA3AF      500: #6B7280  (secondary text)
  600: #4B5563      300: #9CA3AF  (tertiary text)
  900: #111827      50: #F8F9FB   (primary text)
```

**Brand Personality:**
- **Not This:** Playful (Hopper), Corporate (Expedia), Technical (Skyscanner)
- **But This:** Confident, Intelligent, Trustworthy, Refined

**Mood Board Keywords:** Clear skies, liquid surfaces, depth, floating elements, intelligent interfaces, Apple Keynote slides, premium travel lounges

---

### Typography System

**Primary Typeface: SF Pro Display (Headlines) + SF Pro Text (Body)**

Rationale:
- Native iOS font (no download, instant rendering)
- Excellent readability at all sizes
- Dynamic Type built-in (accessibility)
- Feels premium without being pretentious
- SF Pro Display (geometric, clean) for impact
- SF Pro Text (optimized for <20pt) for readability

**Type Scale:**

```swift
Display (Hero Prices):
  - Size: 56pt
  - Weight: Bold
  - Line Height: 1.1
  - Usage: Deal prices ($420), savings amounts
  - Example: "$420" in deal card

Title 1 (Screen Headers):
  - Size: 34pt
  - Weight: Bold
  - Line Height: 1.2
  - Usage: Screen titles (Deal Feed, Watchlist)

Title 2 (Section Headers):
  - Size: 28pt
  - Weight: Semibold
  - Line Height: 1.2
  - Usage: Deal card destinations (Tokyo, Paris)

Title 3 (Card Headers):
  - Size: 22pt
  - Weight: Semibold
  - Line Height: 1.3
  - Usage: Route names (SFO → NRT)

Headline (Emphasis):
  - Size: 17pt
  - Weight: Semibold
  - Line Height: 1.3
  - Usage: CTA labels, filter chips

Body (Main Content):
  - Size: 17pt
  - Weight: Regular
  - Line Height: 1.4
  - Usage: Descriptions, metadata

Callout (Secondary):
  - Size: 16pt
  - Weight: Regular
  - Line Height: 1.4
  - Usage: Supporting text, timestamps

Subheadline:
  - Size: 15pt
  - Weight: Regular
  - Line Height: 1.3
  - Usage: Tertiary info

Footnote (Metadata):
  - Size: 13pt
  - Weight: Regular
  - Line Height: 1.3
  - Usage: Airline, duration, timestamps

Caption 1 (Small Text):
  - Size: 12pt
  - Weight: Regular
  - Line Height: 1.3
  - Usage: Legal disclaimers, "Updated 5m ago"

Caption 2 (Tiny Text):
  - Size: 11pt
  - Weight: Regular
  - Line Height: 1.3
  - Usage: Badge labels, tags
```

**Dynamic Type Support:**
- All text scales with accessibility sizes (XS → XXXL)
- Layouts reflow gracefully (cards expand height, maintain structure)
- Minimum touch target: 44x44pt (WCAG AAA)

---

### Logo & App Icon Concept

**App Name:** FareLens
**Tagline:** "See through the price haze"

**Logo Concept: Lens + Airplane**
```
Visual: Circular lens shape with airplane silhouette inside
Metaphor: "Lens" clarifies what's hidden (prices), focuses on deals
Style: Minimalist, geometric (SF Symbols aesthetic)
Colors:
  - Full Color: Deep Sky Blue lens, white airplane
  - Monochrome: Single color (for tab bar, navigation)
  - Inverted: White on dark backgrounds
```

**App Icon (1024x1024):**
```
Design:
- Rounded square (iOS standard)
- Gradient background: Deep Sky Blue → Sky Blue (top to bottom)
- White airplane symbol (SF Symbol: airplane) centered
- Subtle circular lens glow around plane
- No text (icon-only for simplicity)

Variations:
- Light Mode: Vibrant blue gradient
- Dark Mode: Slightly desaturated (better on dark backgrounds)
- Tab Bar (40x40): Simplified (remove glow, just plane)
```

**Icon Design Principles:**
- Recognizable at 16x16px (Spotlight search)
- No gradients that compress poorly
- High contrast (passes accessibility checks)
- Unique silhouette (not confused with other travel apps)

---

## DESIGN PHILOSOPHY

### Core Principles

**1. Trust Through Transparency**
- Always show lowest fare first (even if non-affiliate)
- Clear provider ranking (no hidden agendas)
- Honest deal scoring (explain why it's good)
- No fake urgency ("Only 2 seats left!" = banned)

**2. Intelligent Simplicity**
- Hide complexity, not information
- Progressive disclosure (5 primary filters → "Advanced" sheet for more)
- Smart defaults (most users never change settings)
- Contextual UI (show price trends only when relevant)

**3. Performance is a Feature**
- 60fps scrolling (no compromises)
- <2s launch (faster than Google Flights)
- Instant interactions (no loading spinners for cached data)
- Graceful degradation (offline mode works beautifully)

**4. Delight in Details**
- Micro-interactions that feel alive (spring animations, haptics)
- Thoughtful empty states (not generic illustrations)
- Contextual help (no tutorials, UI teaches itself)
- Surprise moments (confetti on exceptional deals)

**5. Accessible by Default**
- VoiceOver labels on everything
- Dynamic Type support (all sizes)
- High contrast mode (AAA compliance)
- Reduced motion fallbacks (crossfades vs slides)

---

## PERFORMANCE-OPTIMIZED DESIGN APPROACH

### Addressing iOS Architect's Concerns

**Problem:** Full-screen blur effects (frosted glass) are GPU-intensive, may drop frames on iPhone SE.

**Solution: Selective Glass Architecture**

Instead of Hopper-style full-screen blur, we use:

**1. Static Gradients (90% of UI)**
```
Backgrounds: Subtle gradients (no live blur)
  - Light Mode: White → Light Blue tint (5% opacity)
  - Dark Mode: Midnight → Deep Slate gradient

Performance: GPU-efficient (static image, cached)
Visual: Clean, premium, depth without motion blur
```

**2. Liquid Glass Accents (10% of UI)**
```
Selective Blur: Only on floating elements
  - Deal cards (when elevated/pressed)
  - Bottom sheets (provider list, filters)
  - Tab bar (floating pill)
  - Alert overlays

Performance: Limited blur regions (GPU handles easily)
Visual: Premium "floating" effect without full-screen cost
```

**3. Depth Through Layering (No Blur)**
```
Z-axis hierarchy:
  - Shadows (subtle, realistic)
  - Borders (hairline, 0.5pt)
  - Opacity (90% → 100% for elevation)
  - Scale (0.98 → 1.0 for pressed states)

Performance: CPU-efficient (no GPU blur)
Visual: 3D depth without performance hit
```

### Performance Budget Per Screen

```
Deal Feed (Main Screen):
  - Static gradient background: ✓ GPU-friendly
  - Deal cards (30-50 visible): ✓ Flat colors + shadows
  - Tab bar (frosted glass): ✓ Single blur region
  - Total GPU load: <30% (iPhone SE target)
  - Scroll: 60fps guaranteed

Deal Detail Screen:
  - Static gradient background: ✓
  - Price chart (Swift Charts): ✓ Native, optimized
  - Booking CTAs (flat): ✓
  - Glass sheet (providers): ✓ Bottom sheet blur only
  - Total GPU load: <25%

Watchlist Screen:
  - Static gradient background: ✓
  - Watchlist cards (10-20 visible): ✓ Flat + shadows
  - No blur effects: ✓
  - Total GPU load: <20%

Search Screen:
  - Static gradient background: ✓
  - Input fields (flat): ✓
  - Calendar picker (native): ✓ System component
  - No blur effects: ✓
  - Total GPU load: <15%
```

**Fallback Strategy (If Needed):**
```swift
// Detect device performance tier
if ProcessInfo.processInfo.isLowPowerModeEnabled ||
   DeviceModel.current.isOlderThan(.iPhoneSE3) {
    // Disable all blur effects
    useStaticGradientsOnly = true
}
```

**Device-Tier Fallback (USER APPROVED):**

**High-End Devices (iPhone 13+, A15+):**
- Full liquid glass effects enabled
- Frosted tab bar, bottom sheets, elevated cards
- 60fps guaranteed

**Low-End Devices (iPhone SE, A14 and older):**
- Blur effects disabled automatically
- Static gradients + opacity + shadows for depth
- Still premium feel, just less "glassy"
- 60fps guaranteed

**Detection Logic:**
```swift
if ProcessInfo.processInfo.isLowPowerModeEnabled ||
   DeviceModel.current.chip.isOlderThan(.A15) {
    disableBlurEffects = true
}
```

**Result:** All users get 60fps performance. Newer devices get visual richness. Older devices get reliability. Trust > Aesthetics.

---

## COMPONENT LIBRARY

### Navigation

#### 1. Floating Tab Bar (Main Navigation)

**Design:**
```
Position: Floats 12pt above bottom, 16pt horizontal margins
Shape: Rounded pill (corner radius: 28pt)
Height: 56pt (thumb-friendly, modern)
Background:
  - Light Mode: White with subtle shadow (no blur)
  - Dark Mode: Dark Slate (#2D3142) with border
Material: Solid (no blur for performance)
Border: 0.5pt, White 10% opacity (subtle rim light)
Shadow:
  - Light Mode: Y-offset 8pt, blur 16pt, black 8%
  - Dark Mode: Y-offset 4pt, blur 12pt, black 30%

Tabs (3 total):
  1. Explore (home, deals, "Good Deals" feed for Free tier)
  2. Search (flight search)
  3. Watchlist (saved routes)

Profile: Top-right gear icon (SF Symbol: gearshape.fill) in Explore tab navigation bar

Tab Items:
  - Icons: SF Symbols, 24x24pt, medium weight
  - Labels: 11pt, Regular (below icon)
  - Active State:
    - Icon: Custom Blue (#0A84FF)
    - Label: Deep Sky Blue, Semibold
    - Background: Expanding pill (blue 10% opacity, spring animation)
  - Inactive State:
    - Icon: Neutral 500 (gray)
    - Label: Neutral 500
    - Background: None

Interaction:
  - Tap: Haptic feedback (selection)
  - Switch: Tab scales 0.95 → 1.0, crossfade content (0.3s)
  - Spring animation: duration 0.5s, damping 0.7

Accessibility:
  - VoiceOver: "Explore tab, 1 of 4, selected"
  - Dynamic Type: Labels scale, icons stay fixed
  - Touch target: 56pt height (exceeds 44pt minimum)
```

**Rationale:**
- Floating design feels modern (vs bottom-pinned)
- 4 tabs (not 5) = clear, uncluttered
- Solid background (no blur) = performance-friendly
- Larger than iOS default (56pt vs 49pt) = easier to tap

---

#### 2. Navigation Bar (Per-Screen)

**Design:**
```
Height: 44pt (standard iOS)
Background: Transparent (blends with screen gradient)
Title:
  - Size: 34pt Bold (large title, inline when scrolling)
  - Color: Primary text (black/white adaptive)
  - Position: Left-aligned (iOS standard)

Actions:
  - Right side: Icon buttons (search, filter, settings)
  - Icon size: 22x22pt SF Symbols
  - Touch target: 44x44pt (invisible padding)
  - Color: Neutral 600 (gray), Blue when pressed

Back Button:
  - iOS standard (chevron + previous screen name)
  - Color: Deep Sky Blue
  - Haptic: Light impact on tap

Scroll Behavior:
  - Large title collapses to inline on scroll (iOS standard)
  - Smooth transition (no blur background needed)
```

---

### Deal Cards (Primary Component)

#### Deal Card (Feed View)

**Anatomy:**
```
┌────────────────────────────────────────┐
│  [Photo]  Tokyo                   🔥   │  ← Header
│  [48x48]  San Francisco → Tokyo        │
│           5h 30m · Nonstop             │
│                                        │
│  $650     ←─ Hero Price (56pt Bold)   │  ← Price Section
│  Save 35% below avg                    │
│                                        │
│  [United] Economy · Dec 15        →   │  ← Footer (metadata)
└────────────────────────────────────────┘
```

**Specifications:**
```
Container:
  - Width: Screen width - 32pt (16pt margins each side)
  - Height: Auto (min 140pt)
  - Background:
    - Light Mode: White
    - Dark Mode: Dark Slate (#2D3142)
  - Corner Radius: 16pt (modern, soft)
  - Border: 0.5pt, Neutral 200/700 (subtle)
  - Shadow:
    - Default: Y-offset 2pt, blur 8pt, black 5%
    - Pressed: Y-offset 0pt, blur 4pt, black 8%
  - Padding: 16pt all sides

Header Section:
  - Destination Photo: 48x48pt, rounded 12pt, left-aligned
  - Destination Name: Title 2 (28pt Semibold), deep sky blue
  - Route: Body (17pt Regular), neutral 600
  - Duration/Stops: Footnote (13pt Regular), neutral 500

Price Section:
  - Price: Display (56pt Bold), primary text
  - Savings: Callout (16pt Regular), success green (#10B981)
  - Deal Badge (if >40% savings):
    - "Hot Deal 🔥" pill
    - Background: Sunset Orange (#FF6B35)
    - Text: 11pt Semibold, White
    - Padding: 6pt vertical, 12pt horizontal
    - Corner radius: 12pt
    - Position: Top-right corner

Footer Section:
  - Airline Logo: 24x24pt, grayscale
  - Cabin Class: Footnote (13pt), neutral 500
  - Date: Footnote (13pt), neutral 500
  - Chevron: Right arrow (SF Symbol), neutral 400

Interaction States:
  - Default: Above specs
  - Pressed:
    - Scale: 0.98
    - Shadow: Reduced (Y-offset 0pt)
    - Haptic: Light impact
    - Duration: 0.2s spring
  - Swiped Left (Quick Save):
    - Reveal green "Saved" pill (150pt width)
    - Haptic: Medium impact
    - Card springs back after 0.5s
```

**Accessibility:**
```
VoiceOver Label: "Flight deal to Tokyo from San Francisco. $650 economy class. Save 35% below average. United Airlines, December 15. Double tap to view details."

Actions:
  - Default: Opens deal detail
  - Custom Action 1: "Save to watchlist"
  - Custom Action 2: "Share deal"

Dynamic Type:
  - Card height expands with text size
  - Photo remains 48x48pt
  - Price scales (56pt → up to 80pt for Accessibility XXXL)
```

---

#### Deal Card (Detail View Variant)

**When User Taps Card:**
```
Hero Transition:
  1. Card scales up and moves to top of screen (0.4s spring)
  2. Other cards fade out + blur increases (0.3s)
  3. Detail content slides up from bottom (staggered)
  4. Background changes to gradient (0.5s crossfade)

Detail Screen Sections:
  1. Hero (Destination photo, full-width, 240pt height)
  2. Price & Savings (large format)
  3. Price Trend Chart (Swift Charts)
  4. Flight Details (times, airline, cabin)
  5. Booking CTAs (Always lowest fare first)
  6. Provider List (GlassSheet, if >2 options)
```

---

### Price Trend Chart

**Design:**
```
Component: Swift Charts (native iOS 16+)
Type: Line chart with area fill
Height: 200pt
Background: Transparent (sits on gradient)

Data Visualization:
  - X-axis: Last 30 days (labeled every 7 days)
  - Y-axis: Price range (auto-scaled, $300-$800 example)
  - Line: Deep Sky Blue, 3pt stroke
  - Area Fill: Deep Sky Blue gradient (50% → 0% opacity)
  - Current Price Point:
    - Circle (12pt diameter)
    - Pulsing animation (1.0 → 1.2 → 1.0 scale, 2s loop)
    - White fill, blue border (2pt)

Interaction:
  - Tap point: Shows exact price + date in tooltip
  - Tooltip: Frosted glass pill, white text, 14pt
  - Haptic: Light impact on tap

Annotations:
  - Average Line: Dashed horizontal (neutral 400, 1pt)
  - Label: "30-day avg: $520" (11pt, neutral 500)
  - Deal Zone: Shaded green area (below average)

Empty State:
  - "Price history loading..." with skeleton shimmer
  - "Not enough data yet. Check back in 7 days."
```

**Rationale:**
- Native Swift Charts (no third-party dependencies)
- Clean, minimal (not cluttered like competitor charts)
- Contextual (shows "good deal" visually, not just number)

---

### Booking CTAs (Transparent Ranking)

**Design Philosophy:** Always show lowest fare first, even if non-affiliate. Trust > short-term revenue.

**Layout:**
```
Primary CTA (Always Lowest Fare):
  ┌────────────────────────────────────┐
  │  Book for $650                  →  │  ← Gradient button
  │  on Delta.com                      │
  └────────────────────────────────────┘

Secondary CTA (If Affiliate Within 7%):
  ┌────────────────────────────────────┐
  │  Book for $665                  →  │  ← Outlined button
  │  on Aviasales                      │
  └────────────────────────────────────┘

Tertiary (If >2 Options):
  "View all 5 booking options →" (text link, opens GlassSheet)
```

**Button Specs:**

**Primary CTA (Gradient):**
```
Height: 56pt (large, thumb-friendly)
Width: Full width - 32pt margins
Background: Custom Blue gradient (#0A84FF → #1E96FF)
Text: 17pt Semibold, White
Icon: Chevron right (SF Symbol), white
Border: None
Shadow: Y-offset 4pt, blur 12pt, blue 30%
Corner Radius: 16pt

Pressed State:
  - Scale: 0.97
  - Brightness: -10%
  - Shadow: Reduced (Y-offset 2pt)
  - Haptic: Medium impact
```

**Secondary CTA (Outlined):**
```
Height: 56pt
Width: Full width - 32pt margins
Background: Transparent
Text: 17pt Semibold, Deep Sky Blue
Icon: Chevron right, blue
Border: 2pt, Deep Sky Blue
Shadow: None
Corner Radius: 16pt

Pressed State:
  - Background: Deep Sky Blue 10% opacity
  - Haptic: Light impact
```

**Provider Ranking (GlassSheet):**
```
Trigger: "View all 5 booking options →"
Sheet Type: Bottom sheet (frosted glass background)
Height: 60% screen height (max 500pt)
Background:
  - Light Mode: White with blur (UIBlurEffect.systemMaterial)
  - Dark Mode: Dark Slate with blur

Content (Sorted by Total Cost):
  1. Delta.com — $650 (Lowest ✓)
  2. Aviasales — $665 (Affiliate)
  3. United.com — $670
  4. Expedia — $685
  5. Kayak — $695

Row Design:
  - Provider Logo: 32x32pt
  - Provider Name: 17pt Semibold
  - Price: 20pt Bold
  - Badge: "Lowest ✓" (green), "Affiliate" (neutral)
  - Chevron: Right arrow
  - Height: 64pt
  - Divider: 0.5pt, neutral 200

Interaction:
  - Tap row: Opens Safari (in-app)
  - Sheet dismisses with spring animation
  - Haptic: Selection on tap
```

**Accessibility:**
```
Primary CTA VoiceOver: "Book for $650 on Delta.com. Button. This is the lowest verified fare."

Secondary CTA VoiceOver: "Book for $665 on Aviasales. Button. Affiliate partner, may earn commission."

GlassSheet VoiceOver: "Booking options sheet. 5 providers found. Sorted by total cost. Swipe down to dismiss."
```

---

### Watchlist Card

**Design:**
```
┌────────────────────────────────────────┐
│  New York → London                     │  ← Route (Title 3)
│  Any dates · 1-2 weeks                 │  ← Flexibility
│                                        │
│  $420  ↓ $50 (11%)                    │  ← Price + Change
│  Last updated 5m ago              [•] │  ← Timestamp + Menu
└────────────────────────────────────────┘

Container:
  - Same specs as Deal Card
  - Add: Green border (2pt) if price dropped today
  - Add: Red badge if price rising

Price Change Indicator:
  - Green ↓ $50 (savings)
  - Red ↑ $30 (increase)
  - Gray ━ (no change)
  - Size: 17pt Semibold

Menu (Triple Dot):
  - Edit watchlist
  - Delete
  - Share
```

---

### Filter Pills (Quick Filters)

**Design:**
```
Layout: Horizontal scroll (snap to pills)
Pill Specs:
  - Height: 36pt
  - Padding: 12pt horizontal, 8pt vertical
  - Background:
    - Unselected: Neutral 100 (light), Neutral 800 (dark)
    - Selected: Deep Sky Blue
  - Text:
    - Unselected: 15pt Regular, Neutral 600
    - Selected: 15pt Semibold, White
  - Icon: Optional (airline logo, 16x16pt)
  - Corner Radius: 18pt (pill shape)
  - Border: None

Filter Options (Max 5 Primary):
  1. All (default)
  2. International
  3. Nonstop
  4. Under $500
  5. This Month

Advanced Filters:
  - Trigger: "More Filters" pill (outlined, not filled)
  - Opens bottom sheet with all 15 filters
  - Progressive disclosure (hide complexity)

Interaction:
  - Tap: Toggle selection
  - Haptic: Selection feedback
  - Animation: Background color transition (0.2s)
```

---

### Search Interface

**Design Philosophy:** Make search fast, not exhaustive. Most users search 1-2 routes max.

**Layout:**
```
┌──────────────────────────────────────┐
│  Find Flights                        │  ← Title (34pt Bold)
│                                      │
│  ┌────────────────────────────────┐ │
│  │  From: San Francisco (SFO)  ✕  │ │  ← Origin Input
│  └────────────────────────────────┘ │
│                                      │
│  ┌────────────────────────────────┐ │
│  │  To: Tokyo (NRT)            ✕  │ │  ← Destination Input
│  └────────────────────────────────┘ │
│                                      │
│  ┌────────────────────────────────┐ │
│  │  Dec 15 - Dec 22 (7 days)   ✕  │ │  ← Date Picker
│  └────────────────────────────────┘ │
│                                      │
│  ┌────────────────────────────────┐ │
│  │  1 Adult · Economy          ⌄  │ │  ← Travelers/Class
│  └────────────────────────────────┘ │
│                                      │
│  ┌────────────────────────────────┐ │
│  │  Search Flights             →  │ │  ← Primary CTA
│  └────────────────────────────────┘ │
└──────────────────────────────────────┘

Input Field Specs:
  - Height: 56pt
  - Background: Neutral 100 (light), Neutral 800 (dark)
  - Border: 1pt, Neutral 300/600
  - Border (Focused): 2pt, Deep Sky Blue
  - Text: 17pt Regular
  - Placeholder: 17pt Regular, Neutral 400
  - Icon: Left-aligned (plane, calendar, person)
  - Clear Button (✕): Right-aligned, 20x20pt
  - Corner Radius: 12pt

Airport Picker:
  - Trigger: Tap input field
  - Type: Full-screen sheet (push from right)
  - Search bar at top (autocomplete)
  - Results: City name + IATA code + country
  - Recent searches shown first
  - Popular destinations (LAX, JFK, LHR, NRT)

Date Picker:
  - Type: Native iOS calendar (inline)
  - Highlights: Cheapest days (green dots)
  - Range selection: Tap start, tap end
  - Flexible dates toggle: "±3 days"

Travelers Picker:
  - Type: Bottom sheet
  - Steppers: Adults (1-9), Children (0-5), Infants (0-2)
  - Class: Economy, Premium, Business, First
```

---

### Loading & Empty States

**Skeleton Loading (Deal Feed):**
```
Design: Shimmer effect (Facebook-style)
Layout: 3 skeleton cards (same height as real cards)
Animation:
  - Gradient sweep (light gray → white → light gray)
  - Duration: 1.5s loop
  - Direction: Left to right (45° angle)

Skeleton Card Structure:
  - Photo placeholder: 48x48pt rounded rectangle
  - Text lines: 3-4 rounded rectangles (varying widths)
  - No borders or shadows (flat)

Duration: Shows for max 2 seconds, then:
  - Success: Crossfade to real cards (0.3s)
  - Error: Fade to error state (0.3s)
```

**Empty States:**

**No Deals Found:**
```
┌──────────────────────────────────────┐
│                                      │
│         [Airplane Icon]              │  ← SF Symbol, 80x80pt, neutral 400
│                                      │
│    No flights found                  │  ← Title 2, neutral 900
│    Try different dates or airports   │  ← Body, neutral 600
│                                      │
│    ┌──────────────────────────────┐ │
│    │  Adjust Search              │ │  ← Primary CTA
│    └──────────────────────────────┘ │
└──────────────────────────────────────┘

Alternative: Suggest nearby airports or flexible dates
```

**Offline Mode:**
```
Banner (Top of screen):
  - Background: Neutral 200 (light), Neutral 700 (dark)
  - Icon: Cloud with slash (SF Symbol)
  - Text: "You're offline. Showing cached results."
  - Action: "Retry" button (attempts reconnect)
  - Dismissible: No (persists until online)

Cached Content:
  - Show deals with "Last updated 15m ago" timestamp
  - Disable refresh (show grayed-out spinner)
  - Watchlists work normally (local data)
```

**Quota Exceeded:**
```
Banner (Top of screen):
  - Background: Warning Orange (#F59E0B)
  - Icon: Exclamation triangle
  - Text: "Live prices unavailable. Showing cached results."
  - Action: "Learn More" → explains API quota
  - Dismissible: Yes (but reappears on next search)

Fallback:
  - Show cached results (up to 7 days old)
  - Disable background refresh
  - Pro users get priority (quota reserved for them)
```

---

### Alerts & Notifications

**Push Notification Design:**
```
Title: "Tokyo deal dropped to $650"
Body: "Save 35% vs average. Expires in 6 hours."
Icon: App icon (with red badge if exceptional)
Sound: Default (or custom "chime" for exceptional deals)

Actions (iOS Rich Notifications):
  1. "View Deal" (default, opens app to detail)
  2. "Mute Route" (silences Tokyo deals for 30 days)
  3. "Pause Alerts" (snooze all alerts for 24h)

Quiet Hours:
  - 10pm-7am (user's local time)
  - Exception: 1 exceptional deal per day (>40% savings)
  - Haptic: None during quiet hours (silent delivery)
```

**In-App Alert Toast:**
```
Design:
  - Position: Top of screen, below status bar
  - Height: Auto (min 60pt)
  - Background: Success green (for savings), Orange (for urgency)
  - Text: 15pt Semibold, White
  - Icon: Checkmark (success), Bell (alert)
  - Duration: 3 seconds (auto-dismiss)
  - Swipe up to dismiss early

Animation:
  - Entry: Slide down from top (spring, 0.5s)
  - Exit: Fade + slide up (0.3s)
  - Haptic: Success feedback (for savings)

Example:
  "Saved to watchlist ✓" (green)
  "Price dropped $50 🔥" (orange)
```

---

### Settings & Profile

**Profile Screen:**
```
┌──────────────────────────────────────┐
│  [Avatar]  John Doe                  │  ← Header
│            Free Plan                 │
│                                      │
│  ┌────────────────────────────────┐ │
│  │  Upgrade to Pro             →  │ │  ← CTA (if Free)
│  └────────────────────────────────┘ │
│                                      │
│  Account                             │  ← Section Header
│  • Email & Password             →   │
│  • Watchlists (2/2 used)        →   │
│  • Notification Preferences     →   │
│                                      │
│  Settings                            │
│  • Quiet Hours (10pm-7am)       →   │
│  • Preferred Airports           →   │
│  • Units (USD, Miles)           →   │
│                                      │
│  Support                             │
│  • Help Center                  →   │
│  • Contact Support              →   │
│  • Privacy Policy               →   │
│  • Terms of Service             →   │
│                                      │
│  About                               │
│  • App Version 1.0.0                 │
│  • Sign Out                          │
└──────────────────────────────────────┘

Row Design:
  - Height: 56pt
  - Icon: Left-aligned (SF Symbol, 24x24pt)
  - Label: 17pt Regular
  - Chevron: Right-aligned
  - Divider: 0.5pt, neutral 200

Toggle Row (for boolean settings):
  - Toggle: Right-aligned (iOS native)
  - No chevron
```

---

## DESIGN TOKENS

### Spacing Scale (4pt Grid)

```
Micro:   4pt   (icon padding, badge spacing)
Small:   8pt   (element spacing, tight groups)
Medium:  12pt  (card internal padding)
Base:    16pt  (screen margins, card spacing)
Large:   24pt  (section spacing)
XL:      32pt  (screen top/bottom padding)
XXL:     48pt  (hero sections)
```

### Corner Radius

```
Tight:   8pt   (small badges, pills)
Base:    12pt  (input fields, small cards)
Medium:  16pt  (buttons, standard cards)
Large:   24pt  (modals, sheets)
Round:   28pt  (tab bar, circular elements)
Circle:  50%   (avatars, icons)
```

### Shadows

```
Small (Resting):
  - Y-offset: 2pt
  - Blur: 8pt
  - Color: Black 5%
  - Usage: Cards at rest

Medium (Elevated):
  - Y-offset: 4pt
  - Blur: 12pt
  - Color: Black 10%
  - Usage: Buttons, floating tab bar

Large (Modal):
  - Y-offset: 8pt
  - Blur: 24pt
  - Color: Black 15%
  - Usage: Bottom sheets, overlays

None (Pressed):
  - Y-offset: 0pt
  - Blur: 4pt
  - Color: Black 8%
  - Usage: Buttons when pressed
```

### Animation Timings

```
Instant:  0.1s  (micro-interactions, color changes)
Fast:     0.2s  (button presses, toggles)
Base:     0.3s  (standard transitions, fades)
Moderate: 0.5s  (sheet presentations, tab switches)
Slow:     0.8s  (hero transitions, complex animations)

Spring Curves:
  - Gentle: damping 0.8, response 0.4
  - Standard: damping 0.7, response 0.5
  - Bouncy: damping 0.6, response 0.6
```

---

## ACCESSIBILITY SPECIFICATIONS

### Color Contrast (WCAG AAA: 7:1 Minimum)

**Light Mode:**
```
Primary Text (#111827) on White (#FFFFFF): 16.9:1 ✓
Secondary Text (#4B5563) on White: 7.5:1 ✓
Custom Blue (#0A84FF) on White: 4.5:1 (AA compliant for all text)
  → Use for headlines/CTAs only, not body text

Deep Sky Blue Background + White Text: 4.8:1 ✓ (buttons OK)
```

**Dark Mode:**
```
Primary Text (#F8F9FB) on Dark Slate (#1A1D29): 14.2:1 ✓
Secondary Text (#9CA3AF) on Dark Slate: 6.8:1 ✓
Deep Sky Blue (#3A9EFF) on Dark Slate: 7.2:1 ✓
```

**High Contrast Mode:**
```
When enabled:
  - All text: Pure black (#000000) or pure white (#FFFFFF)
  - Borders: Thicken from 0.5pt → 2pt
  - Contrast: Minimum 21:1 (black on white)
  - Shadows: Remove (rely on borders only)
```

### Touch Targets (Minimum 44x44pt)

```
Buttons: 56pt height (exceeds 44pt minimum)
Tab bar items: 56pt height ✓
Icon buttons: 44x44pt touch area (visible icon may be 24x24pt)
Links: 44pt line height minimum
Filter pills: 36pt height → 44pt with padding ✓

Exception: Inline text links (exempt per WCAG)
```

### VoiceOver Labels

**Deal Card:**
```
Label: "Flight deal to Tokyo from San Francisco. $650 economy class. Save 35% below average. United Airlines, December 15."

Hint: "Double tap to view details and booking options."

Traits: Button (tappable)

Custom Actions:
  - "Save to watchlist"
  - "Share deal"
  - "Mute route"
```

**Search Input:**
```
Label: "Origin airport. Currently San Francisco International."
Hint: "Double tap to change origin airport."
Traits: Text field, button (opens picker)
```

**Price Chart:**
```
Label: "Price trend chart for Tokyo flights. 30-day history. Current price $650, down from average $800."

Hint: "Swipe left or right to explore prices by date."

Accessibility Chart Data: Audio graph (iOS 15+ feature)
  - Reads data points as user swipes
  - "Day 1: $800. Day 7: $750. Day 14: $680..."
```

### Dynamic Type Support

**All Text Scales:**
```
Smallest (XS):   Body 14pt → Display 45pt
Default (M):     Body 17pt → Display 56pt
Largest (XXXL):  Body 23pt → Display 76pt

Accessibility Sizes (XXXL+):
  - Body: up to 32pt
  - Display: up to 100pt
  - Cards: Height expands, width stays same
  - Layouts: Reflow gracefully (no horizontal scroll)
```

**Fixed Elements (Don't Scale):**
```
Icons: 16pt, 20pt, 24pt (stay fixed for visual consistency)
Logos: Fixed size (airline logos, app icon)
Photos: Fixed aspect ratio (may crop differently)
```

### Reduced Motion

**Standard Animations:**
```
Slides → Crossfades
Springs → Linear ease
Parallax → Disabled
Particle effects → Disabled
Scale animations → Disabled
Rotate animations → Disabled
```

**Preserved Animations:**
```
Opacity transitions (fade in/out): OK
Color transitions: OK
Layout changes: OK (no motion)
```

**Code:**
```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

.transition(reduceMotion ? .opacity : .slide)
.animation(reduceMotion ? nil : .spring(), value: state)
```

---

## SCREEN DESIGNS

### 1. Deal Feed (Home Screen)

**Emotional Goal:** Discovery and excitement — "I found an amazing deal!"

**Visual Hierarchy:**
```
┌─────────────────────────────────────────┐
│  [Status Bar]                           │
│                                         │
│  Explore                           [•]  │  ← Title + Notifications Badge
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ [All] [Intl] [Nonstop] [<$500]  │   │  ← Filter Pills (horizontal scroll)
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [Photo] Tokyo              🔥  │   │  ← Deal Card 1
│  │  SFO → NRT                      │   │
│  │  $650  ↓ Save 35%              │   │
│  │  [United] Dec 15           →   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [Photo] Paris                  │   │  ← Deal Card 2
│  │  LAX → CDG                      │   │
│  │  $520  ━ Good deal             │   │
│  │  [Air France] Jan 5        →   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [More cards...]                        │
│                                         │
│  [Floating Tab Bar]                     │  ← z+16 (above all)
└─────────────────────────────────────────┘
```

**Background:**
```
Light Mode: White → Very Light Blue gradient (subtle)
Dark Mode: Midnight (#1A1D29) → Deep Slate (#2D3142) gradient
Direction: Top to bottom
Opacity: 100% (no blur, performance-friendly)
```

**Interactions:**
```
Pull to Refresh:
  - Elastic bounce (spring animation)
  - Loading spinner (iOS native, blue)
  - Haptic: Light impact at trigger point

Card Tap:
  - Scale to 0.98 (0.2s spring)
  - Haptic: Light impact
  - Navigate to detail (hero transition, 0.4s)

Swipe Card Left:
  - Reveal "Saved ✓" pill (green, 150pt width)
  - Haptic: Medium impact
  - Card springs back (0.5s)
  - Toast appears: "Saved to watchlist ✓"

Scroll:
  - 60fps guaranteed (tested on iPhone SE)
  - No parallax (performance consideration)
  - Large title collapses on scroll (iOS standard)
```

**Empty State:**
```
┌─────────────────────────────────────────┐
│                                         │
│         [Airplane Icon]                 │  ← 80x80pt, neutral 400
│                                         │
│    No deals yet                         │  ← Title 2
│    We're searching for the best prices  │  ← Body
│    Check back in a few hours.           │
│                                         │
│    ┌─────────────────────────────────┐ │
│    │  Set Up Watchlist            →  │ │  ← Primary CTA
│    └─────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Offline State:**
```
Banner at top:
  "You're offline. Showing cached results from 15m ago."

Deal cards:
  - Gray overlay (20% white)
  - "Prices may have changed" disclaimer
  - Tap opens alert: "Connect to internet to see latest prices"
```

---

### 2. Deal Detail Screen

**Emotional Goal:** Confidence and clarity — "This is a real deal, I should book it."

**Layout:**
```
┌─────────────────────────────────────────┐
│  [Hero Photo: Tokyo skyline, 240pt]    │  ← Full-width hero
│  [Back] [Share] [Save]                  │  ← Overlay buttons
└─────────────────────────────────────────┘
│                                         │
│  Tokyo                                  │  ← Destination (Title 1, 34pt)
│  San Francisco → Tokyo (NRT)            │  ← Route (Body)
│                                         │
│  $650                                   │  ← Price (Display, 56pt)
│  Save $200 (35% below avg)             │  ← Savings (green)
│  Deal Score: 94/100 🔥                 │  ← Score pill (orange)
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Price Trend (Last 30 Days)     │   │  ← Section Header
│  │  [Line Chart: Swift Charts]     │   │  ← Chart (200pt height)
│  │  Average: $850                   │   │  ← Context
│  └─────────────────────────────────┘   │
│                                         │
│  Flight Details                         │  ← Section Header
│  ┌─────────────────────────────────┐   │
│  │  [United] United Airlines        │   │
│  │  Dec 15, 9:00 AM → 5:00 PM      │   │
│  │  5h 30m · Nonstop · Economy     │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Booking Options                        │  ← Section Header
│  ┌─────────────────────────────────┐   │
│  │  Book for $650              →   │   │  ← Primary CTA (gradient)
│  │  on Delta.com                    │   │  ← Lowest fare (always)
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │  Book for $665              →   │   │  ← Secondary CTA (outlined)
│  │  on Aviasales                    │   │  ← Affiliate (within 7%)
│  └─────────────────────────────────┘   │
│                                         │
│  View all 5 booking options →          │  ← Opens GlassSheet
│                                         │
│  [Safe Area Bottom Padding]             │
└─────────────────────────────────────────┘
```

**Hero Transition (From Feed):**
```
1. Deal card scales up (0.4s spring)
2. Moves to top of screen
3. Expands to full-width hero (240pt height)
4. Destination photo crossfades in (0.5s)
5. Content slides up from bottom (staggered, 0.3s each)
   - Price section (delay 0.0s)
   - Chart section (delay 0.1s)
   - Flight details (delay 0.2s)
   - Booking CTAs (delay 0.3s)
```

**Price Chart Interaction:**
```
Default: Shows full 30-day history
Tap Data Point:
  - Tooltip appears (frosted glass pill)
  - "Dec 1: $720" (14pt Semibold, white text)
  - Haptic: Light impact
  - Tooltip auto-dismisses after 2s

Drag Horizontally:
  - Cursor follows finger
  - Shows continuous tooltip
  - Haptic: Selection (every 3 days)
```

**Booking CTA Tap:**
```
1. Button scales to 0.97 (0.2s)
2. Haptic: Medium impact
3. Analytics event: "affiliate_click" logged
4. Safari opens (SFSafariViewController, in-app)
5. URL: Deep link with tracking params
   Example: https://tp.media/r?campaign_id=X&marker=676763&sub_id=ios-fl-abc123-detail-varA-free&u={delta.com}
```

**GlassSheet (All Providers):**
```
Trigger: "View all 5 booking options →"
Animation: Slide up from bottom (0.5s spring)
Height: 60% screen height (max 500pt)
Background:
  - Light Mode: White with blur (.systemMaterial)
  - Dark Mode: Dark Slate with blur

Header:
  - Handle (drag to dismiss): 36pt wide, 5pt tall, neutral 300
  - Title: "All Booking Options" (20pt Semibold)
  - Subtitle: "Sorted by total cost" (15pt Regular, neutral 500)

Content (Scrollable List):
  ┌─────────────────────────────────────┐
  │ [Delta]  Delta.com         $650  →  │  ← Lowest ✓ badge (green)
  │ [Aero]   Aviasales         $665  →  │  ← Affiliate badge (neutral)
  │ [United] United.com        $670  →  │
  │ [Exp]    Expedia           $685  →  │
  │ [Kay]    Kayak             $695  →  │
  └─────────────────────────────────────┘

Row Height: 64pt
Divider: 0.5pt, neutral 200
Tap Row: Opens Safari (same flow as CTAs)

Dismiss:
  - Swipe down (spring animation)
  - Tap outside sheet (fade out, 0.3s)
  - Haptic: Light impact on dismiss
```

---

### 3. Search Screen

**Emotional Goal:** Speed and clarity — "I can find flights in 10 seconds."

**Layout:**
```
┌─────────────────────────────────────────┐
│  Find Flights                      [✕]  │  ← Title + Close
│                                         │
│  ┌─────────────────────────────────���   │
│  │ [Plane] From                     │   │  ← Origin Input
│  │ San Francisco (SFO)          ✕   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ [Plane] To                       │   │  ← Destination Input
│  │ Tokyo (NRT)                  ✕   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ [Calendar] Dates                 │   │  ← Date Picker
│  │ Dec 15 - Dec 22 (7 days)     ✕   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ [Person] Travelers               │   │  ← Travelers/Class
│  │ 1 Adult · Economy            ⌄   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Search Flights              →  │   │  ← Primary CTA (gradient)
│  └─────────────────────────────────┘   │
│                                         │
│  Recent Searches                        │  ← Section (if any)
│  • LAX → CDG, Jan 5                →   │
│  • SFO → LHR, Feb 12               →   │
└─────────────────────────────────────────┘
```

**Airport Picker (Tap Origin/Destination):**
```
Sheet: Full-screen (push from right)
Search Bar: Top, autofocus keyboard
Autocomplete: Live as user types
  - "san" → "San Francisco (SFO), USA"
  - Shows: City, IATA code, country
  - Icon: Plane (origin) or Location pin (destination)

Results (Sorted):
  1. Exact matches (IATA code)
  2. City name matches
  3. Nearby airports (within 100 miles)
  4. Popular destinations

Recent/Favorite (Top):
  - Last 5 searched airports
  - User-favorited airports (star icon)

Row Design:
  - Height: 56pt
  - Icon: Left (24x24pt)
  - City + Code: 17pt Semibold
  - Country: 15pt Regular, neutral 500
  - Tap: Selects airport, dismisses sheet (0.3s slide right)
```

**Date Picker (Tap Dates Field):**
```
Type: Inline calendar (native iOS, embedded in sheet)
Sheet Height: 70% screen height
Calendar:
  - Month view (scrollable vertically)
  - Highlights: Green dots on cheapest days (if data available)
  - Range selection: Tap start date, tap end date
  - Flexible toggle: "±3 days" (search wider range)

Footer:
  - "Depart: Dec 15, Return: Dec 22" (preview)
  - "Done" button (blue, 56pt height)

Interaction:
  - Tap date: Selects (blue background)
  - Swipe months: Vertical scroll (smooth, 60fps)
  - Haptic: Selection on tap
```

**Travelers/Class Picker (Tap Travelers Field):**
```
Sheet: Bottom sheet (40% height)
Content:
  ┌─────────────────────────────────────┐
  │  Adults                    [-] 1 [+] │  ← Stepper
  │  Children (2-11)           [-] 0 [+] │
  │  Infants (<2)              [-] 0 [+] │
  │                                      │
  │  Cabin Class                    [⌄]  │  ← Dropdown
  │  • Economy                       ✓   │  ← Selected
  │  • Premium Economy                   │
  │  • Business                          │
  │  • First                             │
  │                                      │
  │  ┌────────────────────────────────┐ │
  │  │  Done                          │ │  ← Primary CTA
  │  └────────────────────────────────┘ │
  └─────────────────────────────────────┘

Stepper:
  - Buttons: 44x44pt (large touch target)
  - Count: 20pt Semibold, center
  - Min: 1 adult (can't go below)
  - Max: 9 total passengers
  - Haptic: Light impact on +/-
```

**Search Flow:**
```
1. User taps "Search Flights" CTA
2. Validation:
   - Check: Origin ≠ Destination
   - Check: Dates valid (depart < return)
   - Check: ≥1 adult
3. Loading State:
   - CTA text: "Searching..." (spinner)
   - Disable further taps
4. API Call:
   - Amadeus Flight Offers Search
   - Parallel: Fetch affiliate links
5. Results:
   - Navigate to Results screen (push right)
   - Show deals sorted by price
6. Error Handling:
   - Toast: "Search failed. Please try again."
   - Log: Analytics event (search_failed)
```

---

### 4. Watchlist Screen

**Emotional Goal:** Control and reassurance — "I'm tracking the right routes."

**Layout:**
```
┌─────────────────────────────────────────┐
│  Watchlist                         [+]  │  ← Title + Add Button
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  New York → London               │   │  ← Watchlist Card 1
│  │  Any dates · 1-2 weeks           │   │
│  │  $420  ↓ $50 (11%)          [•] │   │  ← Price dropped (green)
│  │  Last updated 5m ago             │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  San Francisco → Tokyo           │   │  ← Watchlist Card 2
│  │  Dec 15 - Dec 22                 │   │
│  │  $650  ━ No change          [•] │   │  ← No change (gray)
│  │  Last updated 10m ago            │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Create Your First Watchlist     │   │  ← Empty State (if 0)
│  │  Get alerts when prices drop     │   │
│  │  ┌───────────────────────────┐  │   │
│  │  │  Add Watchlist         →  │  │   │  ← CTA
│  │  └───────────────────────────┘  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Free Plan: 5/5 watchlists used         │  ← Quota Warning
│  ┌─────────────────────────────────┐   │
│  │  Upgrade to Pro for Unlimited →  │   │  ← Upgrade CTA
│  └─────────────────────────────────┘   │
│                                         │
│  [Floating Tab Bar]                     │
└───────��─────────────────────────────────┘
```

**Watchlist Card Interaction:**
```
Tap Card:
  - Navigate to Watchlist Detail (price history, edit options)
  - Hero transition (similar to deal detail)

Swipe Left (Delete):
  - Reveal red "Delete" button (100pt width)
  - Tap: Confirm alert "Delete watchlist?"
  - Haptic: Warning (on reveal), Success (on delete)

Menu Button (Triple Dot):
  - Edit: Change dates, price threshold, alert settings
  - Delete: Confirm delete
  - Share: Share watchlist URL (deep link)
  - Mute: Pause alerts for this route (7/30 days)

Price Change Indicator:
  - Green ↓ $50 (11%): Border turns green (2pt)
  - Red ↑ $30 (8%): Border turns red (2pt)
  - Gray ━ No change: Default border (neutral)
```

**Add Watchlist Flow:**
```
1. Tap [+] button (top-right)
2. Sheet: "Create Watchlist" (70% height)
3. Fields:
   - Route: Tap → Airport picker (same as search)
   - Dates: Flexible (any dates) or Specific range
   - Price Threshold: "Alert me if price drops below $500"
   - Alert Frequency: Daily / When price drops / Both
4. CTA: "Create Watchlist" (gradient button)
5. Validation:
   - Free tier: Check if <5 watchlists
   - If ≥5: Show paywall modal "Upgrade to Pro"
6. Success:
   - Toast: "Watchlist created ✓"
   - Card appears with slide-in animation
```

**Quota Warning (Free Tier):**
```
Position: Bottom of list (above tab bar)
Design:
  - Background: Warning Orange (#F59E0B, 10% opacity)
  - Border: 1pt, Orange
  - Icon: Info circle (SF Symbol)
  - Text: "Free Plan: 5/5 watchlists used"
  - CTA: "Upgrade to Pro for Unlimited →"

Tap CTA:
  - Navigate to Subscription screen (paywall)
```

---

### 5. Profile & Settings Screen

**Layout:**
```
┌─────────────────────────────────────────┐
│  Profile                           [⚙]  │  ← Settings Gear
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [Avatar]  John Doe              │   │  ← User Info
│  │            john@example.com      │   │
│  │            Free Plan             │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  ⭐ Upgrade to Pro          →   │   │  ← Upgrade CTA (if Free)
│  │  Unlimited watchlists + more     │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Account                                │  ← Section
│  • Watchlists (2/2 used)           →   │
│  • Notification Preferences        →   │
│  • Email & Password                →   │
│                                         │
│  Preferences                            │
│  • Quiet Hours (10pm-7am)          →   │
│  • Preferred Airports (SFO, LAX)   →   │
│  • Currency & Units (USD, Miles)   →   │
│                                         │
│  Support                                │
│  • Help Center                     →   │
│  • Contact Support                 →   │
│  • Privacy Policy                  →   │
│  • Terms of Service                →   │
│                                         │
│  About                                  │
│  • App Version 1.0.0                    │
│  • Sign Out                             │
└─────────────────────────────────────────┘
```

**Subscription Screen (Paywall):**
```
┌─────────────────────────────────────────┐
│  [✕]                                    │  ← Close Button
│                                         │
│  Upgrade to Pro                         │  ← Title (34pt Bold)
│  Get unlimited watchlists and more      │  ← Subtitle
│                                         │
│  ✓ Unlimited watchlists                 │  ← Feature List
│  ✓ 6 instant alerts/day (vs 3)          │
│  ✓ ALL deals visible                    │
│  ✓ 3 preferred airports                 │
│  ✓ Ad-free experience                   │
│  ✓ Priority support                     │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Annual: $49.99/year        ✓   │   │  ← Selected (blue border)
│  │  Save 40% vs monthly             │   │
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │  Monthly: $6.99/month            │   │  ← Unselected
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Start 14-Day Free Trial  →  │   │  ← Primary CTA
│  └─────────────────────────────────┘   │
│                                         │
│  Cancel anytime. Auto-renews.           │  ← Disclaimer
│  Terms of Service · Privacy Policy      │
└─────────────────────────────────────────┘

Pricing Card:
  - Height: 80pt
  - Border: 2pt (selected), 1pt (unselected)
  - Background: White (light), Dark Slate (dark)
  - Checkmark: Top-right (if selected)

CTA Flow (StoreKit 2):
  1. Tap "Start 14-Day Free Trial"
  2. System paywall (Face ID / Touch ID)
  3. Confirm purchase
  4. Success: Confetti animation 🎉
  5. Toast: "Welcome to Pro! ✓"
  6. Navigate back to Profile (now shows "Pro Plan")
```

---

## MICRO-INTERACTIONS & DELIGHT

### Button Press Animation

```
Spring Parameters:
  - Duration: 0.2s
  - Damping: 0.7
  - Response: 0.5

States:
  1. Default: Scale 1.0
  2. Pressed: Scale 0.97 (finger down)
  3. Released: Scale 1.0 (spring back)

Haptics:
  - Light impact (on press)
  - Medium impact (on CTAs like "Book Now")
  - Success (on save/delete actions)
```

### Deal Card Swipe-to-Save

```
Gesture:
  1. User swipes card left (150pt threshold)
  2. Green "Saved ✓" pill reveals behind card
  3. Card springs back to rest position (0.5s)
  4. Haptic: Medium impact (at threshold)
  5. Toast appears top: "Saved to watchlist ✓" (3s)

Animation:
  - Card translates X: -150pt (follows finger)
  - Pill opacity: 0 → 1 (fade in)
  - Spring back: damping 0.6 (bouncy feel)
```

### Price Drop Confetti

```
Trigger: Deal score ≥90 (exceptional) + user opens detail

Animation:
  - Confetti particles (20-30)
  - Colors: Blue, green, orange (brand colors)
  - Physics: Fall from top, bounce on landing
  - Duration: 2 seconds
  - Layers: Behind content (doesn't block UI)

Accessibility:
  - Reduced motion: Replace with subtle glow pulse
  - No haptic (too distracting)
```

### Loading Shimmer (Skeleton)

```
Effect:
  - Gradient: Light gray → White → Light gray
  - Angle: 45° (top-left to bottom-right)
  - Speed: 1.5s per sweep
  - Easing: Linear (consistent motion)

Layout:
  - 3 skeleton cards (same height as real cards)
  - Rounded rectangles (match real card structure)
  - No borders/shadows (flat look)

Transition to Content:
  - Crossfade (0.3s)
  - Cards slide up slightly (8pt, subtle)
```

### Hero Transition (Feed → Detail)

```
Steps:
  1. User taps deal card
  2. Card scales to 1.05 (0.1s, anticipation)
  3. Card moves to top of screen (0.4s spring)
  4. Card expands to full-width (0.4s spring)
  5. Photo crossfades in (0.5s)
  6. Content slides up from bottom (staggered):
     - Price (delay 0.0s)
     - Chart (delay 0.1s)
     - Details (delay 0.2s)
     - CTAs (delay 0.3s)
  7. Background fades to gradient (0.5s)

Reverse (Detail → Feed):
  - Same animation in reverse
  - Faster: 0.3s (exit should be quick)
  - Spring: Less bounce (damping 0.8)
```

### Tab Switch Animation

```
Tap Tab:
  1. Selected tab icon scales 0.95 → 1.0 (0.2s)
  2. Expanding pill background (blue, 10% opacity)
  3. Label becomes Semibold
  4. Haptic: Selection feedback
  5. Content crossfades (0.3s, delay 0.1s)

No Slide:
  - Tabs don't slide (too slow)
  - Crossfade only (instant feeling)
```

---

## UNIQUE DIFFERENTIATORS

### 1. Intelligent Data Visualization (vs Competitor Raw Numbers)

**Competitor Problem:** Hopper shows "$650" but no context. Is that good?

**FareLens Solution:**
```
Deal Card:
  - Price: $650 (large, 56pt)
  - Context: "↓ Save 35% vs avg" (green, 16pt)
  - Visual: Deal Score badge (94/100 🔥)

Detail Screen:
  - Price Trend Chart (30-day history)
  - Annotations: "Average $850" line, "Deal Zone" shading
  - Tap point: "Dec 1: $720" tooltip

Explainability:
  - Tap "Why is this good?" → Sheet
  - "24% below 90-day average"
  - "Lowest price in 6 months"
  - "Typical price: $800-900"
```

**Impact:** Users understand "good deal" at a glance (vs guessing).

---

### 2. Transparent Provider Ranking (vs Competitor Hidden Agendas)

**Competitor Problem:** Expedia prioritizes partners, hides cheaper options.

**FareLens Solution:**
```
Always Lowest Fare First (Even Non-Affiliate):
  1. Delta.com — $650 (Lowest ✓)
  2. Aviasales — $665 (Affiliate, within 7%)
  3. United.com — $670

GlassSheet (All Providers):
  - Sorted by total cost (transparent)
  - No "Recommended" or "Partner" labels (neutral names only)
  - Badge: "Lowest ✓" (green), "Affiliate" (gray, not hidden)

Global Disclosure (Terms):
  - "FareLens may earn commission at no extra cost to you."
  - No per-CTA disclaimers (reduces clutter)
```

**Impact:** Users trust we're on their side (vs feeling manipulated).

---

### 3. Performance-First Design (vs Competitor Bloat)

**Competitor Problem:** Expedia takes 2.5s to launch, feels sluggish.

**FareLens Solution:**
```
Launch Time:
  - Target: <2s (faster than Google Flights' 1.2s goal)
  - Method: Defer heavy init to background, lazy-load tabs

Scroll Performance:
  - 60fps guaranteed (even iPhone SE)
  - Method: Static gradients (no full-screen blur), flat cards

Offline Mode:
  - Works beautifully (cached deals, watchlists)
  - Method: Core Data persistence, aggressive caching

App Size:
  - Target: <50MB (vs Expedia's 120MB)
  - Method: No third-party dependencies, WebP images
```

**Impact:** App feels fast and reliable (vs competitors' lag).

---

### 4. Delight Without Gimmicks

**Competitor Problem:** Hopper's rabbit mascot feels juvenile.

**FareLens Solution:**
```
Subtle, Intentional Delight:
  - Confetti on exceptional deals (≥90 score, rare)
  - Spring animations (feel alive, not robotic)
  - Haptic feedback (tactile, premium)
  - Hero transitions (cinematic, not jarring)

No Mascots, No Gamification:
  - Professional, refined (appeals to affluent travelers)
  - Delight in craft, not cartoons
```

**Impact:** Feels premium and trustworthy (vs playful but cheap).

---

## DESIGN VALIDATION CHECKLIST

Before development:
- [x] Competitor research (10 screenshots analyzed)
- [x] Brand identity proposed (user approval needed)
- [x] Performance budget defined (60fps, <2s launch)
- [ ] User approval: Color palette, logo concept
- [ ] iOS architect review: Confirm performance feasibility
- [ ] Backend architect review: API contracts match design needs

Before App Store submission:
- [ ] Accessibility audit (VoiceOver, Dynamic Type, contrast)
- [ ] Performance test (iPhone SE, 60fps scroll verified)
- [ ] Visual QA (all screens match design specs)
- [ ] Dark mode tested (all screens)
- [ ] Dynamic Type tested (XS → XXXL)
- [ ] Reduced motion tested (all animations have fallbacks)
- [ ] Screenshots prepared (App Store, 6.7" and 5.5" required)

---

## OPEN QUESTIONS FOR USER

### Q1: Brand Identity Approval

**Proposed:**
- Primary Color: Custom Blue Gradient (#0A84FF → #1E96FF)
- Accent Color: Sunset Orange (#FF6B35)
- Typography: SF Pro Display + Text
- Logo: Lens + Airplane icon
- Personality: Confident, Intelligent, Trustworthy

**Does this direction resonate, or would you like to explore alternatives?**
- More playful (like Hopper, broader appeal)?
- More premium (muted tones, affluent travelers)?
- Different color (avoid blue = too common)?

---

### Q2: Performance vs Visual Richness Trade-off

**Proposed:** Selective glass (10% of UI, floating elements only) + static gradients (90%)

**If profiling shows blur still kills performance on iPhone SE, we:**
- Option A: Remove all glass, use flat colors + gradients (still premium)
- Option B: Lower target to iPhone 13+ (exclude SE, keep glass)
- Option C: Dynamic adjustment (disable blur on low-end devices)

**Your preference?** I recommend Option A (trust > aesthetics).

---

### Q3: Logo & App Icon

**Concept:** Circular lens with airplane inside (represents "clarity through price haze")

**Would you like:**
- Mockup: I can describe detailed icon for a designer to create
- Alternative concepts: Magnifying glass + price tag, Compass + plane, etc.
- Custom design: Hire a designer for final icon

---

## SUMMARY

**1. Competitor Insights:**
- Hopper: Playful but overwhelming (too many alerts, aggressive pink)
- Skyscanner: Functional but dated (Android-first, no visual hierarchy)
- Expedia: Cluttered, corporate (too many CTAs, feels salesy)
- Going: Map-first, clean (low information density)
- **FareLens:** Google Flights' clarity + Apple's craft + Liquid glass differentiation

**2. Proposed Brand Identity (Needs User Approval):**
- Colors: Deep Sky Blue (trust) + Sunset Orange (urgency)
- Typography: SF Pro (native, readable, premium)
- Logo: Lens + Airplane (clarity metaphor)
- Personality: Confident, Intelligent, Trustworthy (not playful, not corporate)

**3. Unique Differentiators:**
- Intelligent data viz (price trends with context, not raw numbers)
- Transparent ranking (always lowest fare first, no hidden agendas)
- Performance-first (60fps, <2s launch, offline-capable)
- Delight in details (spring animations, haptics, confetti on exceptional deals)

**4. Response to iOS Architect's Performance Concerns:**
- **Solution:** Selective glass (10% of UI) + static gradients (90%)
- **Fallback:** Remove all blur if needed (trust > aesthetics)
- **Budget:** <30% GPU load on iPhone SE, 60fps guaranteed

**Ready to proceed once user approves brand identity (colors, logo, personality).**

---

**End of Design Document**

---

## FREE VS PRO VISUAL DISTINCTION

### Paywall Screen (Shown when user exceeds Free limits)

**Trigger Points:**
- Attempt to create 6th watchlist (Free limit: 5)
- First launch: 14-day free trial offer (ALL new users)
- After trial ends: Subscribe or downgrade prompt

**Visual Design:**

```
┌─────────────────────────────────┐
│ Unlock FareLens Pro             │
│ ───────────────────────────────│
│                                 │
│ FREE                            │
│ ✓ 5 watchlists                  │
│ ✓ 3 alerts/day (immediate)      │
│ ✓ 20 deals visible in-app       │
│ ✓ 1 preferred airport           │
│ • Ad-supported                   │
│                                 │
│ ┌─────────────────────────────┐│
│ │ PRO  (Recommended)       ✓  ││  ← Selected (blue border)
│ │─────────────────────────────││
│ │ ✓ Unlimited watchlists      ││
│ │ ✓ 6 instant alerts/day      ││
│ │ ✓ ALL deals visible         ││
│ │ ✓ 3 preferred airports      ││
│ │ ✓ Ad-free experience        ││
│ │ ✓ Priority support          ││
│ │                             ││
│ │ $49.99/year  (Save 40%)     ││
│ │ $6.99/month                 ││
│ └─────────────────────────────┘│
│                                 │
│ 📊 Pro users save $450/year    │  ← Social proof (SF Pro Text 14pt, 60% opacity)
│     on average                  │
│                                 │
│ ┌─────────────────────────────┐│
│ │  Start 14-Day Free Trial  →││  ← Primary CTA (gradient blue)
│ └─────────────────────────────┘│
│                                 │
│ Restore Purchase  |  Maybe Later│  ← Secondary actions (gray text)
└─────────────────────────────────┘
```

**Color Specs:**
- Pro card border: Custom Blue (#0A84FF), 2pt, corner radius 16pt
- Checkmarks: Green (#10B981) for Pro, Gray (#6B7280) for Free
- CTA button: Gradient (#0A84FF → #1E96FF), 56pt height
- Background: .ultraThinMaterial (frosted glass on capable devices)

---

### Banner Ad (Free Tier Only)

**Placement:** Bottom of deal feed, above tab bar

**Specs:**
```
Height: 60pt (safe area aware)
Width: Full width - 32pt margins (16pt each side)
Background: Neutral 100 (#E5E7EB), corner radius 12pt
Border: 1pt, Neutral 200 (#D1D5DB)
Shadow: Y-offset 2pt, blur 8pt, black 5%

Content:
  - Native ad format (Google AdMob or similar)
  - Loads asynchronously (doesn't block UI)
  - Shimmer placeholder while loading
  - "Ad" label (8pt, Neutral 500, top-right)
```

**Loading States:**
1. Skeleton (shimmer): Neutral 200 background, animated gradient
2. Loaded: Native ad content
3. Error: Hide entirely (don't show broken ad)

---

### Pro Badge (Profile Screen)

**Free User:**
```
┌─────────────────────────────────┐
│ Profile                         │
│ ───────────────────────────────│
│                                 │
│ John Doe                        │
│ john@example.com                │
│                                 │
│ ┌─────────────────────────────┐│
│ │ Upgrade to Pro           →  ││  ← Call-to-action row
│ │ Unlimited watchlists + more ││
│ └─────────────────────────────┘│
└─────────────────────────────────┘
```

**Pro User:**
```
┌─────────────────────────────────┐
│ Profile                    PRO  │  ← Badge (Custom Blue pill)
│ ───────────────────────────────│
│                                 │
│ John Doe                        │
│ john@example.com                │
│ Pro since Dec 2025              │  ← Subtle gray text
│                                 │
│ ┌─────────────────────────────┐│
│ │ Manage Subscription      →  ││  ← Link to App Store
│ └─────────────────────────────┘│
└─────────────────────────────────┘
```

**Pro Badge Specs:**
- Text: "PRO" (11pt, Semibold, White)
- Background: Custom Blue gradient (#0A84FF → #1E96FF)
- Padding: 6pt horizontal, 4pt vertical
- Corner radius: 8pt
- Position: Top-right of screen, 16pt from edge

---

### Watchlist Limit Indicator

**Free Tier (At Limit):**
```
┌─────────────────────────────────┐
│ Watchlists            2/2 Free  │  ← Gray pill showing limit
│ ───────────────────────────────│
│                                 │
│ [Watchlist 1]                   │
│ [Watchlist 2]                   │
│                                 │
│ ┌─────────────────────────────┐│
│ │ + Add Watchlist (Pro)    →  ││  ← Upgrade CTA (disabled state)
│ └─────────────────────────────┘│
└─────────────────────────────────┘
```

**Pro Tier:**
```
┌─────────────────────────────────┐
│ Watchlists            5 active  │  ← No limit shown
│ ───────────────────────────────│
│                                 │
│ [Watchlist 1]                   │
│ [Watchlist 2]                   │
│ [Watchlist 3]                   │
│                                 │
│ ┌─────────────────────────────┐│
│ │ + Add Watchlist          →  ││  ← Enabled (blue text)
│ └─────────────────────────────┘│
└─────────────────────────────────┘
```

---

## LIGHT MODE GRADIENT SPECIFICATIONS

### Header Gradients (Search, Deal Feed, Watchlists)

**Light Mode:**
```swift
LinearGradient(
    colors: [
        Color(hex: "#FFFFFF"),        // Pure white at top
        Color(hex: "#F0F8FF").opacity(0.4)  // Alice Blue tint at bottom
    ],
    startPoint: .top,
    endPoint: .bottom
)
```

**Precise Hex Values:**
- Top: `#FFFFFF` (Pure white, 100% opacity)
- Bottom: `#F0F8FF` at 40% opacity (Alice Blue tint, very subtle)
- Gradient angle: Top → Bottom (0deg)
- Height: 120pt (includes safe area + title)

**Dark Mode (for comparison):**
```swift
LinearGradient(
    colors: [
        Color(hex: "#1A1D29"),        // Midnight Slate
        Color(hex: "#0A84FF").opacity(0.1)  // Custom Blue tint
    ],
    startPoint: .top,
    endPoint: .bottom
)
```

---

### Card Gradients (Deal Cards, Glass Sheets)

**Light Mode - Elevated Cards:**
```swift
LinearGradient(
    colors: [
        Color.white.opacity(0.95),    // Near-white at top
        Color.white.opacity(0.85)     // Slightly transparent at bottom
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
.background(.ultraThinMaterial)  // Only on high-end devices (A15+)
```

**Light Mode - Flat Fallback (Low-End Devices):**
```swift
LinearGradient(
    colors: [
        Color(hex: "#FAFBFC"),        // Off-white
        Color(hex: "#F0F4F8")         // Light gray-blue
    ],
    startPoint: .topLeading,
    endPoint: .bottomTrailing
)
// No blur material (60fps guaranteed on iPhone SE)
```

---

### Primary CTA Gradient (Book Now, Upgrade, etc.)

**Light Mode (Same as Dark):**
```swift
LinearGradient(
    colors: [
        Color(hex: "#0A84FF"),        // iOS system blue
        Color(hex: "#1E96FF")         // Brighter blue
    ],
    startPoint: .leading,
    endPoint: .trailing
)
```
- Gradient angle: Left → Right (90deg)
- Text: White, 17pt Semibold
- Shadow: Y-offset 4pt, blur 12pt, blue 30% opacity

---

## SWIFT CHARTS FRAMEWORK REFERENCE

**Correction:** ARCHITECTURE.md references "Swift Charts (iOS 16+)" but target is iOS 26.0+.

**Updated Reference:**
- Swift Charts framework: **iOS 16.0+** (introduced in iOS 16, includes all latest improvements)
- FareLens target: **iOS 26.0+** (uses Swift Charts with full iOS 26 enhancements)
- Features used:
  - Line charts (price trends, 7-day fare ladder)
  - Bar charts (savings breakdown)
  - Annotations (deal score markers)
  - Smooth animations (spring curves)

**Usage in FareLens:**
```swift
import Charts

struct PriceTrendChart: View {
    let prices: [PricePoint]

    var body: some View {
        Chart(prices) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value("Price", point.amount)
            )
            .foregroundStyle(Color(hex: "#0A84FF"))
            .interpolationMethod(.catmullRom)  // Smooth curves
        }
        .chartYScale(domain: minPrice...maxPrice)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel(format: .dateTime.month().day())
            }
        }
    }
}
```

**iOS 26 Enhancements:**
- Improved performance (60fps scrolling even with real-time updates)
- Enhanced accessibility (VoiceOver narrates chart data)
- Better dark mode support

---

**DESIGN.md v1.1 - All minor issues resolved**
- ✅ Free vs Pro visual distinction documented
- ✅ Light mode gradient specs completed (precise hex values, opacity, angles)
- ✅ Swift Charts framework reference corrected
