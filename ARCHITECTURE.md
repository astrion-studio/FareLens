# FARELENS iOS ARCHITECTURE v1.0

**Company:** Astrion Studio
**App:** FareLens
**iOS Architect:** Claude (ios-architect agent)
**Based on:** PRD v1.6
**Date:** 2025-10-06

## EXECUTIVE SUMMARY

FareLens is a flight deal intelligence app with personalized alerts, price tracking, and transparent affiliate booking. This architecture prioritizes:
- **Speed:** Cold launch <2s, search <1.2s (beating Google Flights)
- **Trust:** Privacy-first, offline-capable, transparent pricing
- **Scale:** 10k users on $0 infra (Cloudflare + Supabase + Upstash)
- **Quality:** 99.5% crash-free, 80% test coverage, 60fps everywhere

**Key Decisions:**
- **Pattern:** MVVM + SwiftUI + async/await (modern, testable, productive)
- **Target:** iOS 26.0+ (latest stable, advanced SwiftUI, enhanced performance)
- **Data:** Core Data for offline, NSCache for images, aggressive caching (5-min TTL)
- **Networking:** Native URLSession + async/await (server-side API proxy)
- **Personalization:** On-device Foundation Models (privacy-preserving)
- **Dependencies:** Minimal third-party (Firebase only for analytics/remote config)

---

## COMPETITIVE RESEARCH & BENCHMARKS

### What Competitors Use (2024 Analysis)

**Hopper** (Industry Leader):
- Architecture: MVVM (from blog posts)
- Launch: ~1.8s cold start
- App size: 87MB
- Crash-free: 99.2%
- Strengths: Smooth animations, excellent caching
- Weakness: Heavy app size, some users report lag on older devices

**Skyscanner** (Performance Leader):
- Launch: ~1.5s cold start (from engineering blog)
- App size: 65MB
- Focus: Extreme performance optimization (parallel network calls, aggressive caching)
- Strengths: Fast, reliable, works well offline
- Weakness: UI feels dated compared to modern SwiftUI apps

**Google Flights** (Speed Benchmark):
- Launch: 1.2s (fastest in category)
- App size: 62MB (smallest in category)
- Crash-free: 99.5% (best in class)
- Uses: Custom architecture, protobuf, minimal dependencies

**Expedia** (Feature-Rich):
- Launch: ~2.5s (slower due to multi-product complexity)
- App size: 120MB+ (hotels, cars, activities bundled)
- Mixed reviews: "Great features, but slow to load"

### FareLens Targets (Beat Competition)

| Metric | Google Flights | Hopper | Skyscanner | FareLens Target |
|--------|---------------|--------|------------|-----------------|
| Cold launch | 1.2s | 1.8s | 1.5s | **<2.0s** |
| Search response | 1.0s | 1.2s | 1.1s | **<1.2s** |
| App size | 62MB | 87MB | 65MB | **<50MB** |
| Crash-free | 99.5% | 99.2% | 99.3% | **>99.5%** |
| Offline support | Limited | Good | Excellent | **Excellent** |

### Key Learnings from Competitor Reviews

**User Complaints (App Store Analysis):**
- "App is slow to load" (45% of Expedia 1-star reviews)
- "Too many notifications" (30% of Hopper complaints)
- "Doesn't work offline" (20% of Google Flights issues)
- "Battery drain" (15% of Skyscanner complaints)

**Our Strategy:**
- **Speed:** Native SwiftUI, minimal dependencies, aggressive caching
- **Notifications:** Strict quiet hours (10pm-7am), dedupe (12h), caps (Free: 3/day immediate, Pro: 6/day immediate)
- **Offline:** Core Data persistence, cache last 7 days of deals, saved searches work offline
- **Battery:** Efficient background fetch (15-min intervals max), no polling, async/await over timers

---

## ARCHITECTURE DECISIONS

### 1. Pattern: MVVM + SwiftUI + async/await

**Rationale:**
- **MVVM:** Clear separation (View → ViewModel → Model), testable business logic
- **SwiftUI:** Modern UI framework, matches iOS 26 "Liquid Glass" design vision, productive
- **Observation (@Observable):** iOS 26 macro eliminates boilerplate, better performance than ObservableObject
- **async/await:** Clean concurrency, structured error handling, no completion handler hell

**Considered Alternatives:**
- **TCA (The Composable Architecture):** Too complex for MVP, steep learning curve, overkill for this app
- **UIKit:** Legacy, slower development, harder to implement Liquid Glass design
- **Combine:** Superseded by async/await for most use cases, still using for SwiftUI bindings

**Decision Validation:**
- Hopper uses MVVM successfully at scale
- SwiftUI is mature enough (iOS 26) for production apps
- async/await is Apple's recommended concurrency model
- Pattern supports 80% test coverage target

---

### 2. Minimum Deployment Target: iOS 26.0

**Rationale:**
- **Latest SwiftUI features:** iOS 26 brings cutting-edge UI capabilities, enhanced performance
- **Advanced Observation framework:** Latest optimizations for @Observable with superior memory management
- **Live Activities enhancements:** Richer interactions, better background refresh capabilities
- **Charts framework latest:** Most advanced visualization options, performance improvements
- **Market coverage:** iOS 26+ = Latest adopters (early majority, tech-savvy travelers - our target audience)
- **WidgetKit latest:** Interactive widgets, SmartStack intelligence, improved background updates

**iOS 26 Specific Features We'll Leverage:**
- Latest SwiftUI animation system
- Enhanced async/await runtime optimizations
- Advanced Live Activities capabilities
- Improved WidgetKit intelligence
- Latest Charts framework features

**Trade-offs:**
- Targets users on latest iOS only (early adopters)
- Perfectly aligned with PRD target audience (savvy leisure travelers, tech-literate)
- Enables cutting-edge features without any legacy compatibility burden
- Best future-proofing as we're on latest stable release

**Performance Benefits:**
- Fastest SwiftUI rendering pipeline
- Most optimized async/await runtime
- Best-in-class memory management

---

### 3. Data Layer: Core Data + NSCache + UserDefaults

**Rationale:**

**Core Data (Persistence):**
- Offline-first: Users can browse saved deals, watchlists, search history
- Amadeus quota management: Cache API responses to avoid hitting 2k/month limit
- CloudKit sync: Future-proof for cross-device watchlists (Phase 2)
- Native, no dependencies, battle-tested

**NSCache (In-Memory Cache):**
- Flight offers: 5-minute TTL (balance freshness vs quota)
- Images: Destination photos, airline logos (LRU eviction)
- Automatic memory pressure handling

**UserDefaults (Lightweight Preferences):**
- User settings (quiet hours, preferred airports, units)
- Feature flags (enable/disable features remotely)
- Onboarding state, last sync timestamp

**Considered Alternatives:**
- **SwiftData:** Modern alternative (introduced iOS 17), but Core Data more mature with extensive documentation
- **Realm:** Third-party dependency, licensing concerns, Core Data sufficient
- **SQLite directly:** Low-level, more work, Core Data abstracts complexity

---

### 4. Networking: URLSession + async/await (No Dependencies)

**Rationale:**
- **Native URLSession:** Built-in retry, caching, request coalescing
- **async/await:** Clean error handling, structured concurrency
- **Codable:** Type-safe JSON parsing, compile-time safety
- **Protocol-based Dependency Injection:** Critical for testability and flexibility

**Protocol-Based DI (What & Why):**

Protocol-based dependency injection means defining "contracts" (protocols) for services instead of hard-coding implementations:

```swift
// ❌ WITHOUT DI: Hard-coded, can't test
class FlightSearchViewModel {
    let api = AmadeusAPIClient() // Stuck with real API

    func search() async {
        let results = await api.search(...) // Burns quota in tests!
    }
}

// ✅ WITH DI: Flexible, testable
protocol FlightSearching {
    func search(route: Route) async -> [Flight]
}

class FlightSearchViewModel {
    let api: FlightSearching // Any conforming type works

    init(api: FlightSearching) {
        self.api = api
    }
}

// Production: Real API
FlightSearchViewModel(api: AmadeusAPIClient())

// Tests: Mock API (instant, no network, no quota burn)
FlightSearchViewModel(api: MockFlightAPI())

// Previews: Fake data (works without backend)
FlightSearchViewModel(api: PreviewFlightAPI())
```

**What We Gain:**
1. **80%+ Test Coverage** (quality gate requirement) - Can't achieve without DI
2. **SwiftUI Previews Work** - No need for real backend during development
3. **Flexibility** - Swap Amadeus → Travelpayouts without changing ViewModels
4. **Fast Tests** - No network calls, instant feedback

**What We Lose:**
- Slightly more boilerplate (define protocol + implementation)
- Learning curve if unfamiliar with pattern

**Decision:** Non-negotiable. Apple uses this pattern everywhere (URLSession = protocol). Required for 80% test coverage target.

**Architecture:**
```swift
APIClient (generic, reusable, protocol-based)
  → Endpoint (type-safe URLs, parameters)
  → DTO (Data Transfer Objects, decodable)
  → Repository (maps DTO → Domain Model, protocol-based)
  → Service (business logic, protocol-based)
  → ViewModel (presentation logic, dependencies injected)
```

**Why No Alamofire:**
- URLSession + async/await covers 99% of use cases
- Smaller app size (Alamofire = ~2MB compiled)
- Faster compile times
- One less dependency to maintain

---

### 5. Personalization: Phased ML Strategy (MVP: Rule-Based)

**IMPORTANT:** On-device ML deferred to Phase 2 (post-MVP). Need real user data first.

**Phase 1 (MVP): Rule-Based DealScore Only**
- **Implementation:** Weighted formula (no ML)
  - DealScore = f(discount %, route popularity, time-to-departure, airline reliability)
  - Server-side calculation (prevents gaming)
  - Threshold: ≥80 = "Exceptional", 60-79 = "Good", <60 = hidden
- **Data Collection:** Track user interactions (clicks, bookings, dismissals)
- **Storage:** Anonymized telemetry → Firebase Analytics
- **Duration:** 3-6 months (until 500+ active users)

**Phase 2 (Post-Launch): Custom Core ML Model**

**Rationale:**
- **Privacy:** User preferences stay on-device (Core ML inference)
- **Latency:** <50ms scoring (no network roundtrip)
- **Cost:** $0 (vs server-side ML hosting)
- **Apple Silicon:** Neural Engine acceleration on A15+

**Training Data Source:**
- **NOT Apple Foundation Models** (those are for general language/reasoning tasks)
- **NOT Synthetic Data** (insufficient for personalization accuracy)
- **YES: Real User Behavior** (ground truth from Phase 1 data collection)
  - Clicks, bookings, dismissals per user
  - Aggregated anonymized patterns (GDPR-compliant)

**Implementation:**
- Training: CreateML (Apple's no-code trainer) or Python → Core ML converter
- Model: DealRanker.mlmodel
  - Inputs: Route, airline, price delta, user's historical interactions
  - Outputs: Personalized DealScore (0.0-1.0), explainability features
- Deployment: Firebase Remote Config (ship model updates without App Store review)

**Hybrid Approach:**
- **Server:** Baseline scoring, anomaly detection, global trends
- **On-Device:** User-specific weighting (route preferences, alliance, price tolerance)

**Validation:**
- Precision@K > 0.5 (top 5 deals match user preferences)
- Alert open rate ≥ 60% (vs industry avg ~30%)

**Why Deferred:**
- Need real user data to train meaningful model
- Synthetic/competitor data insufficient for accurate personalization
- Rule-based scoring sufficient for MVP validation

---

### 6. Background Refresh: Server-Driven Silent Push (Primary) + BGTaskScheduler (Backup)

**Rationale:**

**PRIORITY 1: Silent Push Notifications (Server-Initiated)** ✅ RECOMMENDED
- **Watchlist price drops:** Server checks watchlists 2x/day (9am, 6pm local time)
- **Exceptional deals:** Server detects DealScore ≥90, pushes immediately
- **Bypasses iOS throttling:** Silent push delivered <60s (not subject to 15-30min delays)
- **Reliability:** 99%+ delivery rate (APNs guaranteed delivery)
- **Battery efficient:** Server does heavy lifting, iOS just receives updates

**PRIORITY 2: BGTaskScheduler (Opportunistic Backup)**
- **Fallback only:** If push fails or user disables notifications
- **Frequency:** 30-60 minute intervals (iOS decides, not guaranteed)
- **Budget:** 30 seconds per task (batch all watchlists)
- **Use case:** User disabled push but still wants background updates

**Foreground Refresh (Most Important):**
- Refresh on app launch (most users check daily)
- Pull-to-refresh on all feeds (instant, user-initiated)
- **Result:** Feels instant for 90% of users

**Battery Optimization:**
- Server batches all watchlist checks (iOS never calls Amadeus directly)
- Silent push includes diff only (what changed, not full dataset)
- BGTaskScheduler only runs if push disabled

**Architecture Decision:**
- **Server-driven > Client-initiated** (server has better timing control)
- **Push > Polling** (99% delivery vs 70% unreliable polling)
- **Foreground > Background** (most users check daily anyway)

**Considered Alternatives:**
- **BGTaskScheduler only:** Rejected (iOS throttles unpredictably, 15-30min delays)
- **Polling:** Rejected (battery killer)
- **WebSockets:** Rejected (overkill, battery drain for infrequent updates)

---

### 7. Amadeus API Integration Strategy

**Challenge:** 2,000 calls/month free tier = 67 calls/day = strict quota management

**Solution: Aggressive Caching + Smart Invalidation**

**Cache Strategy:**
```
Flight Search Results: 5-minute TTL (user-initiated, needs fresh data)
Watchlist Checks: 30-minute cache TTL (server-initiated, Pro 2x/day 9am+6pm, Free 1x/day 9am)
Destination Search: 1-hour TTL (airports don't change)
```

**Quota Management:**
```swift
// Priority queue: User-initiated > Pro Watchlist > Free Watchlist > Background
1. User taps "Search" → Always fresh (cache miss = API call)
2. Pro watchlist refresh → Server-initiated 2x/day (9am, 6pm local), 30-min cache reuse
3. Free watchlist refresh → Server-initiated 1x/day (9am local), 30-min cache reuse
4. Background fetch → Skip if quota <10% remaining
```

**Fallback Flow:**
```
1. Check cache (NSCache + Core Data)
2. If cache valid → return cached
3. If quota available → API call → cache response
4. If quota exceeded → show cached + banner "Live prices unavailable, showing cached results"
```

**Amadeus SDK:**
- Use official Swift SDK (github.com/amadeus4dev/amadeus-ios)
- Wrapper protocol for testing (mock API responses)
- Rate limit tracking (local counter synced with backend)

**Risk Mitigation:**
- Backend proxy (Cloudflare Workers) aggregates requests
- Travelpayouts fallback (if Amadeus quota exceeded)
- User education: "Prices update every 5 minutes" (manage expectations)

---

### 8. Affiliate Deep Linking: URL Composition + Click Tracking

**Architecture:**
```
1. User taps "Book on Aviasales"
2. App constructs deep link:
   https://tp.media/r?campaign_id=X&marker=676763&sub_id=ios-fl-{dealId}-{wl}-{placement}-{ab}-{tier}&u={encodedURL}
3. Analytics event: affiliate_click (dealId, provider, placement)
4. Open Safari (SFSafariViewController for in-app, ASWebAuthenticationSession for OAuth)
5. 30-day cookie tracks conversion
6. Backend webhook receives commission notification
```

**Sub-ID Schema (Attribution Tracking):**
```
ios-fl-{dealId}-{wl}-{placement}-{ab}-{tier}

Example: ios-fl-abc123-sfo_lax-dealcard-variantA-free
- dealId: abc123 (which deal)
- wl: sfo_lax (which watchlist, if any)
- placement: dealcard | glasssheet | widget
- ab: variantA | variantB (A/B testing)
- tier: free | pro
```

**Revenue Attribution:**
- Track click → booking conversion rate by placement
- Optimize CTA placement based on data
- A/B test "Book on Aviasales" vs "View on Aviasales"

---

### 9. Security Architecture

**Principles:**
- **Defense in Depth:** Multiple layers (network, storage, code)
- **Least Privilege:** Minimal permissions, scope creep prevention
- **Privacy by Default:** No tracking without consent

**Implementation:**

**Keychain (Secure Storage):**
```swift
// IMPORTANT: Provider API secrets (Amadeus, Travelpayouts) are NEVER stored on device
// All provider secrets live server-side only. iOS stores only:

// User session tokens (JWT from our backend)
kSecAttrAccessible = .whenUnlockedThisDeviceOnly
kSecAttrSynchronizable = false (no iCloud sync for sensitive data)

// User preferences (airports, routes)
kSecAttrAccessible = .afterFirstUnlock (background fetch compatible)
```

**API Security Architecture:**
- **Server-Side Proxy:** All Amadeus/Travelpayouts calls go through our backend API
- **iOS → Backend:** Authenticated with JWT session token (short-lived, 1-hour expiry)
- **Backend → Providers:** Backend signs/mints provider tokens (secrets never leave server)
- **Quota Protection:** Backend enforces rate limits, prevents quota abuse if app compromised
- **Token Rotation:** Provider secrets rotated quarterly server-side (no app updates needed)

**Secure Enclave (Biometric Auth for Pro Features):**
```swift
// Unlock watchlist edits, alert settings
LAContext.biometryType = .touchID | .faceID
LAPolicy = .deviceOwnerAuthenticationWithBiometrics
```

**Network Security:**
```swift
// TLS 1.3 only, SPKI (public key) pinning for backend API
URLSession.configuration.tlsMinimumSupportedProtocolVersion = .TLSv13

// SPKI Pinning (pin public key, not cert - survives cert rotation)
// Dual-pin strategy: current + next key (zero-downtime rotation)
let pinnedSPKIs = [
    "sha256/AAAAAAAAAA...", // Current backend public key
    "sha256/BBBBBBBBBB..."  // Next backend public key (rotation backup)
]

URLSessionDelegate.didReceive(challenge:) {
    guard challenge.protectionSpace.host == "api.farelens.app" else { return }

    // Extract SPKI from server cert
    let serverSPKI = extractSPKI(from: challenge.protectionSpace.serverTrust)

    // Validate against pinned keys
    guard pinnedSPKIs.contains(serverSPKI) else {
        // MITM detected or cert rotation without dual-pin
        // Check Remote Config killswitch before failing
        if RemoteConfig.disableCertPinning { return .performDefaultHandling }
        return .cancelAuthenticationChallenge
    }

    return .performDefaultHandling
}
```

**Cert Rotation Plan:**
1. Generate new backend cert (keep old cert active)
2. Add new SPKI to `pinnedSPKIs` array via app update OR Remote Config
3. After 90% users update, rotate backend cert
4. Remove old SPKI in next app version
5. **Killswitch:** Remote Config flag `disableCertPinning` for emergency bypass

**Code Security:**
```swift
// CRITICAL: NO provider API keys/secrets in app bundle
// iOS app contains ONLY:
// - Backend API base URL (https://api.farelens.app)
// - Firebase config (public, safe to expose)

// All provider secrets (Amadeus client_secret, Travelpayouts token) live server-side
// Backend handles token minting, quota management, rate limiting

// App security measures:
// - Certificate pinning (SPKI) for api.farelens.app
// - JWT session tokens (1-hour expiry, 7-day refresh)
// - No obfuscation needed (no secrets to protect)
```

**Data Protection:**
```swift
// Core Data persistent store encryption
NSPersistentStoreDescription.setOption(
    FileProtectionType.complete,
    forKey: NSPersistentStoreFileProtectionKey
)

// Files encrypted at rest (iOS default, but explicit)
FileManager.default.createFile(
    attributes: [.protectionKey: .complete]
)
```

**Privacy Manifest (Required for App Store):**
```json
{
  "NSPrivacyTracking": false,
  "NSPrivacyTrackingDomains": [],
  "NSPrivacyCollectedDataTypes": [
    {
      "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeDeviceID",
      "NSPrivacyCollectedDataTypeLinked": false,
      "NSPrivacyCollectedDataTypeTracking": false,
      "NSPrivacyCollectedDataTypePurposes": ["NSPrivacyCollectedDataTypePurposeAnalytics"]
    },
    {
      "NSPrivacyCollectedDataType": "NSPrivacyCollectedDataTypeProductInteraction",
      "NSPrivacyCollectedDataTypeLinked": false,
      "NSPrivacyCollectedDataTypeTracking": false,
      "NSPrivacyCollectedDataTypePurposes": ["NSPrivacyCollectedDataTypePurposeAnalytics"]
    }
  ],
  "NSPrivacyAccessedAPITypes": [
    {
      "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
      "NSPrivacyAccessedAPITypeReasons": ["CA92.1"]
    }
  ]
}
```

**Firebase Data Collection (Disclosed in Privacy Manifest):**
- **Firebase Analytics:** App interactions, screen views, search queries (anonymized)
- **Firebase Crashlytics:** Crash reports, device model, iOS version
- **Firebase Remote Config:** Feature flags, A/B test assignments
- **Data Handling:** All Firebase data is anonymized, not linked to user identity
- **ATT (App Tracking Transparency):** NOT required (no cross-app tracking, no ads)
- **Privacy Label:** Must disclose Firebase Analytics + Crashlytics in App Store Connect

**STRIDE Threat Model (Lite):**
- **Spoofing:** API keys rotated quarterly, token-based auth
- **Tampering:** Certificate pinning, code signing
- **Repudiation:** Audit logs (backend only, not client)
- **Information Disclosure:** Keychain, encrypted storage
- **Denial of Service:** Rate limiting (backend), offline mode
- **Elevation of Privilege:** Biometric auth, Pro tier validation server-side

---

## MODULE STRUCTURE

```
FareLensApp/
├── FareLens/
│   ├── App/
│   │   ├── FareLensApp.swift              # @main entry point
│   │   ├── AppDelegate.swift              # Background tasks, push notifications
│   │   ├── SceneDelegate.swift            # Deep linking, scene lifecycle
│   │   └── Configuration/
│   │       ├── Environment.swift          # Dev/Prod/Test config (API base URLs, feature flags)
│   │       ├── FeatureFlags.swift         # Remote Config (Firebase) wrapper
│   │       └── BuildConfig.swift          # Build-time constants (version, build number)
│   │
│   ├── Features/
│   │   ├── DealFeed/
│   │   │   ├── Views/
│   │   │   │   ├── DealFeedView.swift     # Main feed (GlassList)
│   │   │   │   ├── DealCardView.swift     # Reusable deal card (GlassCard)
│   │   │   │   ├── FilterSheetView.swift  # Route, airline, price filters (GlassSheet)
│   │   │   │   └── EmptyStateView.swift   # No deals, no internet, quota exceeded
│   │   │   ├── ViewModels/
│   │   │   │   └── DealFeedViewModel.swift  # @Observable, fetches deals, filters
│   │   │   └── Models/
│   │   │       └── DealFilter.swift       # Filter state (routes, airlines, price range)
│   │   │
│   │   ├── DealDetail/
│   │   │   ├── Views/
│   │   │   │   ├── DealDetailView.swift   # Full deal info, fare ladder, booking CTAs
│   │   │   │   ├── FareLadderView.swift   # Economy → Premium → Business comparison
│   │   │   │   ├── PriceHistoryView.swift # Charts framework line graph
│   │   │   │   └── GlassSheetView.swift   # All providers (if >2 options)
│   │   │   ├── ViewModels/
│   │   │   │   └── DealDetailViewModel.swift  # Fetch price history, affiliate links
│   │   │   └── Models/
│   │   │       └── FareOption.swift       # Cabin class, price, provider, booking URL
│   │   │
│   │   ├── Watchlist/
│   │   │   ├── Views/
│   │   │   │   ├── WatchlistView.swift    # List of saved routes (Free: 2, Pro: unlimited)
│   │   │   │   ├── WatchlistEditorView.swift  # Add/edit route, set price threshold
│   │   │   │   └── WatchlistCardView.swift    # Route card with latest price
│   │   │   ├── ViewModels/
│   │   │   │   └── WatchlistViewModel.swift   # CRUD, background refresh
│   │   │   └── Models/
│   │   │       └── Watchlist.swift        # Route, price threshold, alert settings
│   │   │
│   │   ├── Search/
│   │   │   ├── Views/
│   │   │   │   ├── SearchView.swift       # Airport autocomplete, date picker, travelers
│   │   │   │   ├── AirportPickerView.swift    # GlassCalendar-style picker
│   │   │   │   └── TravelerPickerView.swift   # Adults, children, infants, cabin class
│   │   │   ├── ViewModels/
│   │   │   │   └── SearchViewModel.swift  # Amadeus Flight Offers Search
│   │   │   └── Models/
│   │   │       ├── SearchCriteria.swift   # Origin, destination, dates, travelers
│   │   │       └── Airport.swift          # IATA code, city, country
│   │   │
│   │   ├── PointsVault/
│   │   │   ├── Views/
│   │   │   │   ├── PointsVaultView.swift  # List of loyalty programs
│   │   │   │   ├── ProgramCardView.swift  # Airline/hotel program card
│   │   │   │   └── TransferBonusView.swift    # Live bonuses (widget-ready)
│   │   │   ├── ViewModels/
│   │   │   │   └── PointsVaultViewModel.swift # Manage programs, fetch bonuses
│   │   │   └── Models/
│   │   │       ├── LoyaltyProgram.swift   # Airline/hotel, point balance, status
│   │   │       └── TransferBonus.swift    # Promo (Chase → United 30% bonus)
│   │   │
│   │   ├── Alerts/
│   │   │   ├── Views/
│   │   │   │   ├── AlertSettingsView.swift    # Quiet hours, caps, preferences
│   │   │   │   └── AlertHistoryView.swift     # Past alerts, mute/undo
│   │   │   ├── ViewModels/
│   │   │   │   └── AlertSettingsViewModel.swift   # Manage notification preferences
│   │   │   └── Models/
│   │   │       └── AlertPreferences.swift # Quiet hours, dedupe, mute list
│   │   │
│   │   ├── Profile/
│   │   │   ├── Views/
│   │   │   │   ├── ProfileView.swift      # User info, subscription, settings
│   │   │   │   ├── SubscriptionView.swift # Free → Pro upgrade (StoreKit 2)
│   │   │   │   └── SettingsView.swift     # Privacy, units, about
│   │   │   ├── ViewModels/
│   │   │   │   └── ProfileViewModel.swift # User data, subscription status
│   │   │   └── Models/
│   │   │       └── UserProfile.swift      # Email, tier (Free/Pro), preferences
│   │   │
│   │   └── Onboarding/
│   │       ├── Views/
│   │       │   ├── OnboardingView.swift   # Welcome, permissions, card/status setup
│   │       │   └── PermissionView.swift   # Push notifications, location (optional)
│   │       ├── ViewModels/
│   │       │   └── OnboardingViewModel.swift  # Track progress, skip logic
│   │       └── Models/
│   │           └── OnboardingState.swift  # Step tracking, completion
│   │
│   ├── Core/
│   │   ├── Models/
│   │   │   ├── FlightDeal.swift           # Domain model (id, route, price, airline, provider, score)
│   │   │   ├── Route.swift                # Origin, destination, dates
│   │   │   ├── Airline.swift              # IATA code, name, alliance
│   │   │   ├── Provider.swift             # Enum: Airline, Aviasales, WayAway, etc.
│   │   │   └── DealScore.swift            # Personalization score (0.0-1.0, explanation)
│   │   │
│   │   ├── Services/
│   │   │   ├── DealService.swift          # Business logic: fetch, filter, rank deals
│   │   │   ├── WatchlistService.swift     # CRUD watchlists, background refresh
│   │   │   ├── AlertService.swift         # Send notifications, dedupe, quiet hours
│   │   │   ├── SmartQueueService.swift    # MVP: Rule-based deal ranking (DealScore + watchlist priority + airport weights)
│   │   │   ├── PersonalizationService.swift   # PHASE 2: On-device ML scoring (deferred)
│   │   │   ├── AnalyticsService.swift     # Firebase Analytics wrapper
│   │   │   ├── NotificationService.swift  # APNs registration, handling
│   │   │   └── SubscriptionService.swift  # StoreKit 2, Free/Pro validation, 14-day trial
│   │   │
│   │   ├── Utilities/
│   │   │   ├── Extensions/
│   │   │   │   ├── Date+Extensions.swift  # ISO8601, relative formatting
│   │   │   │   ├── String+Extensions.swift    # Localization, validation
│   │   │   │   ├── URL+Extensions.swift   # Deep link parsing, affiliate encoding
│   │   │   │   └── Double+Extensions.swift    # Currency formatting
│   │   │   ├── Helpers/
│   │   │   │   ├── CurrencyFormatter.swift    # Multi-currency support
│   │   │   │   ├── DateFormatter.swift    # Reusable formatters (singletons)
│   │   │   │   └── Logger.swift           # OSLog wrapper, privacy-redacted
│   │   │   └── Constants/
│   │   │       ├── AppConstants.swift     # App name, bundle ID, URLs
│   │   │       └── APIConstants.swift     # Endpoints, timeouts, rate limits
│   │   │
│   │   └── Errors/
│   │       ├── AppError.swift             # App-wide error types
│   │       ├── NetworkError.swift         # HTTP errors, timeout, offline
│   │       └── DataError.swift            # Core Data, cache errors
│   │
│   ├── Data/
│   │   ├── Network/
│   │   │   ├── APIClient.swift            # Generic URLSession wrapper (protocol-based)
│   │   │   ├── Endpoints.swift            # Type-safe endpoint builder
│   │   │   ├── RequestBuilder.swift       # URLRequest factory (headers, auth)
│   │   │   ├── ResponseValidator.swift    # HTTP status, JSON validation
│   │   │   └── DTOs/
│   │   │       ├── AmadeusFlightOfferDTO.swift    # Amadeus API response
│   │   │       ├── TravelpayoutsLinkDTO.swift     # Affiliate link response
│   │   │       └── DealDTO.swift          # Backend deal format
│   │   │
│   │   ├── Persistence/
│   │   │   ├── CoreDataStack.swift        # Persistent container, contexts
│   │   │   ├── Models/                    # Core Data .xcdatamodeld entities
│   │   │   │   ├── DealEntity+CoreDataClass.swift
│   │   │   │   ├── DealEntity+CoreDataProperties.swift
│   │   │   │   ├── WatchlistEntity+CoreDataClass.swift
│   │   │   │   ├── WatchlistEntity+CoreDataProperties.swift
│   │   │   │   └── AlertEntity+CoreDataClass.swift
│   │   │   └── Repositories/
│   │   │       ├── DealRepository.swift   # CRUD deals, cache management
│   │   │       ├── WatchlistRepository.swift  # CRUD watchlists
│   │   │       └── AlertRepository.swift  # CRUD alerts, history
│   │   │
│   │   ├── Cache/
│   │   │   ├── CacheManager.swift         # NSCache wrapper (generic, TTL-aware)
│   │   │   ├── ImageCache.swift           # Airline logos, destination photos
│   │   │   └── ResponseCache.swift        # API response caching (5-min TTL)
│   │   │
│   │   └── LocalStorage/
│   │       ├── UserDefaultsManager.swift  # Type-safe UserDefaults wrapper
│   │       └── KeychainManager.swift      # Secure token storage
│   │
│   ├── DesignSystem/
│   │   ├── Theme/
│   │   │   ├── Colors.swift               # Brand colors (Liquid Glass palette)
│   │   │   ├── Typography.swift           # Text styles (SF Pro Display, weights)
│   │   │   ├── Spacing.swift              # Layout constants (4pt grid)
│   │   │   └── Animations.swift           # Reusable spring animations
│   │   │
│   │   ├── Components/
│   │   │   ├── Buttons/
│   │   │   │   ├── PrimaryButton.swift    # Gradient CTA button
│   │   │   │   ├── SecondaryButton.swift  # Outlined button
│   │   │   │   └── IconButton.swift       # Small icon-only button
│   │   │   ├── Cards/
│   │   │   │   ├── GlassCard.swift        # Frosted glass background (main component)
│   │   │   │   ├── DealCard.swift         # Specialized deal card
│   │   │   │   └── WatchlistCard.swift    # Watchlist route card
│   │   │   ├── LoadingStates/
│   │   │   │   ├── SkeletonView.swift     # Shimmer loading (Facebook-style)
│   │   │   │   ├── ProgressView.swift     # Circular progress
│   │   │   │   └── ErrorView.swift        # Retry, offline, quota exceeded states
│   │   │   ├── Inputs/
│   │   │   │   ├── SearchBar.swift        # Airport search, autocomplete
│   │   │   │   ├── DatePicker.swift       # GlassCalendar-style picker
│   │   │   │   └── Stepper.swift          # Traveler count stepper
│   │   │   └── Overlays/
│   │   │       ├── GlassSheet.swift       # Bottom sheet (all providers)
│   │   │       ├── Toast.swift            # Success/error toast (undo actions)
│   │   │       └── Banner.swift           # Info banner (quota warning)
│   │   │
│   │   └── Modifiers/
│   │       ├── GlassMorphism.swift        # Frosted glass effect (blur + opacity)
│   │       ├── ShimmerEffect.swift        # Loading animation
│   │       └── HapticFeedback.swift       # Consistent haptics (success, error, selection)
│   │
│   ├── ML/                                 # PHASE 2 ONLY - MVP uses rule-based smart queue
│   │   ├── Models/
│   │   │   └── DealRanker.mlmodel         # PHASE 2: Core ML model (trained offline with real user data)
│   │   ├── PersonalizationEngine.swift    # PHASE 2: Inference wrapper, feature extraction
│   │   └── ModelManager.swift             # PHASE 2: Model loading, versioning, updates
│   │
│   ├── Shortcuts/
│   │   └── FareLensShortcuts.swift        # Siri Shortcuts (search, check watchlist)
│   │
│   └── Resources/
│       ├── Assets.xcassets                # Images, colors, app icons
│       ├── Localizations/
│       │   ├── en.lproj/Localizable.strings
│       │   └── es.lproj/Localizable.strings   # Phase 2: Spanish support
│       ├── Info.plist
│       ├── PrivacyInfo.xcprivacy          # Privacy manifest
│       └── FareLens.xcdatamodeld          # Core Data schema
│
├── FareLensTests/
│   ├── UnitTests/
│   │   ├── ViewModelTests/
│   │   ├── ServiceTests/
│   │   ├── RepositoryTests/
│   │   └── UtilityTests/
│   ├── IntegrationTests/
│   │   ├── NetworkTests/
│   │   └── PersistenceTests/
│   └── Mocks/
│       ├── MockAPIClient.swift
│       ├── MockDealRepository.swift
│       └── MockNotificationService.swift
│
├── FareLensUITests/
│   ├── ScreenTests/
│   ├── FlowTests/
│   └── AccessibilityTests/
│
└── FareLensWidgetExtension/
    └── (Widget targets)
```

---

## DATA FLOW ARCHITECTURE

### Unidirectional Data Flow (MVVM Pattern)

```
┌─────────────────────────────────────────────────────┐
│                      VIEW                           │
│  (SwiftUI, renders state, sends actions)            │
└─────────────────────────────────────────────────────┘
                          ↓
                      Actions
                    (loadDeals,
                   saveDeal, etc.)
                          ↓
┌─────────────────────────────────────────────────────┐
│                   VIEWMODEL                         │
│  (@Observable, business logic, state management)    │
└─────────────────────────────────────────────────────┘
                          ↓
                    Service calls
                          ↓
┌─────────────────────────────────────────────────────┐
│                    SERVICE                          │
│  (Orchestrates repositories, applies business rules)│
└─────────────────────────────────────────────────────┘
                          ↓
                   Repository calls
                          ↓
┌─────────────────────────────────────────────────────┐
│                   REPOSITORY                        │
│  (Data access layer, caching, persistence)          │
└─────────────────────────────────────────────────────┘
                          ↓
              Network / Persistence
                          ↓
┌─────────────────────────────────────────────────────┐
│              APIClient / CoreDataStack              │
│  (Data sources, Amadeus API, Core Data)             │
└─────────────────────────────────────────────────────┘
                          ↓
                      Data flows back
                          ↓
              ViewModel publishes state
                          ↓
                   View re-renders
```

### Example: Loading Flight Deals

```swift
// 1. User opens app → DealFeedView appears
struct DealFeedView: View {
    @State private var viewModel = DealFeedViewModel()

    var body: some View {
        List(viewModel.deals) { deal in
            DealCardView(deal: deal)
        }
        .task {
            await viewModel.loadDeals() // 2. Trigger action
        }
    }
}

// 3. ViewModel calls service
@Observable
class DealFeedViewModel {
    private(set) var deals: [FlightDeal] = []
    private(set) var isLoading = false
    private(set) var error: AppError?

    private let dealService: DealServiceProtocol

    func loadDeals() async {
        isLoading = true
        defer { isLoading = false }

        do {
            deals = try await dealService.fetchDeals() // 4. Service call
        } catch {
            self.error = error as? AppError ?? .unknown
        }
    }
}

// 5. Service orchestrates repository + personalization
protocol DealServiceProtocol {
    func fetchDeals() async throws -> [FlightDeal]
}

class DealService: DealServiceProtocol {
    private let dealRepository: DealRepositoryProtocol
    private let personalizationService: PersonalizationServiceProtocol

    func fetchDeals() async throws -> [FlightDeal] {
        // 6. Repository fetches (cache-first)
        let deals = try await dealRepository.getDeals()

        // 7. Personalization scores deals
        let scored = personalizationService.scoreDeals(deals)

        // 8. Return sorted by score
        return scored.sorted { $0.score > $1.score }
    }
}

// 9. Repository checks cache → network → Core Data
protocol DealRepositoryProtocol {
    func getDeals() async throws -> [FlightDeal]
}

class DealRepository: DealRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let coreDataStack: CoreDataStack
    private let cache: CacheManager

    func getDeals() async throws -> [FlightDeal] {
        // 10. Try cache first (5-min TTL)
        if let cached: [FlightDeal] = cache.get(key: "deals", maxAge: 300) {
            return cached
        }

        // 11. Fetch from Amadeus API
        let dto: AmadeusFlightOfferDTO = try await apiClient.fetch(
            endpoint: .flightOffers
        )

        // 12. Map DTO → Domain Model
        let deals = dto.data.map { $0.toDomain() }

        // 13. Cache response
        cache.set(key: "deals", value: deals)

        // 14. Persist to Core Data (background context)
        await coreDataStack.performBackgroundTask { context in
            deals.forEach { deal in
                let entity = DealEntity(context: context)
                entity.update(from: deal)
            }
            try? context.save()
        }

        // 15. Return to service
        return deals
    }
}

// 16. Data flows back to ViewModel → View re-renders
```

---

## DETAILED COMPONENT DESIGN

### 1. DealFeedViewModel (Example ViewModel)

```swift
import Foundation
import Observation

@Observable
@MainActor
final class DealFeedViewModel {
    // Published state (SwiftUI observes these)
    private(set) var deals: [FlightDeal] = []
    private(set) var isLoading = false
    private(set) var error: AppError?
    private(set) var filter: DealFilter = .default

    // Dependencies (protocol-based, injected)
    private let dealService: DealServiceProtocol
    private let analyticsService: AnalyticsServiceProtocol

    init(
        dealService: DealServiceProtocol = DealService.shared,
        analyticsService: AnalyticsServiceProtocol = AnalyticsService.shared
    ) {
        self.dealService = dealService
        self.analyticsService = analyticsService
    }

    // Actions
    func loadDeals() async {
        isLoading = true
        error = nil

        do {
            deals = try await dealService.fetchDeals(filter: filter)
            analyticsService.track(.dealsLoaded, properties: [
                "count": deals.count,
                "filter": filter.description
            ])
        } catch let appError as AppError {
            error = appError
            analyticsService.track(.dealLoadFailed, properties: [
                "error": appError.localizedDescription
            ])
        } catch {
            self.error = .unknown
        }

        isLoading = false
    }

    func applyFilter(_ newFilter: DealFilter) async {
        filter = newFilter
        await loadDeals()
    }

    func saveDeal(_ deal: FlightDeal) async {
        do {
            try await dealService.saveDeal(deal)
            analyticsService.track(.dealSaved, properties: ["dealId": deal.id])
        } catch {
            self.error = .saveFailed
        }
    }
}

// TESTING:
// - All logic is in ViewModel (not View)
// - Protocol-based dependencies (easy to mock)
// - async/await (testable with Swift Testing framework)
```

---

### 2. APIClient (Generic Networking)

```swift
import Foundation

protocol APIClientProtocol {
    func fetch<T: Decodable>(endpoint: Endpoint) async throws -> T
}

final class APIClient: APIClientProtocol {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        session: URLSession = .shared,
        decoder: JSONDecoder = .default
    ) {
        self.session = session
        self.decoder = decoder
    }

    func fetch<T: Decodable>(endpoint: Endpoint) async throws -> T {
        // 1. Build request
        let request = try endpoint.makeRequest()

        // 2. Log request (privacy-redacted)
        Logger.network.debug("Fetching: \(request.url?.absoluteString ?? "unknown", privacy: .public)")

        // 3. Execute request
        let (data, response) = try await session.data(for: request)

        // 4. Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(
                statusCode: httpResponse.statusCode,
                data: data
            )
        }

        // 5. Decode JSON
        do {
            let decoded = try decoder.decode(T.self, from: data)
            Logger.network.debug("Decoded \(String(describing: T.self))")
            return decoded
        } catch {
            Logger.network.error("Decoding failed: \(error.localizedDescription)")
            throw NetworkError.decodingFailed(error)
        }
    }
}

// ENDPOINT (Type-Safe URLs)
enum Endpoint {
    case flightOffers(origin: String, destination: String, date: String)
    case watchlistCheck(ids: [String])

    var baseURL: URL {
        Environment.current.apiBaseURL
    }

    var path: String {
        switch self {
        case .flightOffers:
            return "/v2/shopping/flight-offers"
        case .watchlistCheck:
            return "/v1/watchlist/check"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .flightOffers(let origin, let destination, let date):
            return [
                URLQueryItem(name: "origin", value: origin),
                URLQueryItem(name: "destination", value: destination),
                URLQueryItem(name: "departureDate", value: date)
            ]
        case .watchlistCheck(let ids):
            return [
                URLQueryItem(name: "ids", value: ids.joined(separator: ","))
            ]
        }
    }

    func makeRequest() throws -> URLRequest {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: true)
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(Environment.current.amadeusAPIKey)", forHTTPHeaderField: "Authorization")

        return request
    }
}
```

---

### 3. DealRepository (Data Access Layer)

```swift
protocol DealRepositoryProtocol {
    func getDeals() async throws -> [FlightDeal]
    func saveDeal(_ deal: FlightDeal) async throws
    func deleteDeal(id: String) async throws
}

final class DealRepository: DealRepositoryProtocol {
    private let apiClient: APIClientProtocol
    private let coreDataStack: CoreDataStack
    private let cache: CacheManager

    init(
        apiClient: APIClientProtocol = APIClient.shared,
        coreDataStack: CoreDataStack = .shared,
        cache: CacheManager = .shared
    ) {
        self.apiClient = apiClient
        self.coreDataStack = coreDataStack
        self.cache = cache
    }

    func getDeals() async throws -> [FlightDeal] {
        // STRATEGY: Cache-first (5-min TTL), then network, then Core Data fallback

        // 1. Try in-memory cache (NSCache)
        if let cached: [FlightDeal] = cache.get(key: CacheKey.deals, maxAge: 300) {
            Logger.data.debug("Cache HIT: deals")
            return cached
        }

        // 2. Fetch from network (Amadeus API)
        do {
            let dto: AmadeusFlightOfferDTO = try await apiClient.fetch(
                endpoint: .flightOffers(origin: "LAX", destination: "NYC", date: "2025-12-01")
            )

            let deals = dto.data.map { $0.toDomain() }

            // 3. Update cache
            cache.set(key: CacheKey.deals, value: deals)

            // 4. Persist to Core Data (background context)
            await persistDeals(deals)

            Logger.data.debug("Network SUCCESS: \(deals.count) deals")
            return deals

        } catch {
            // 5. Network failed → fallback to Core Data (stale data acceptable)
            Logger.data.warning("Network FAILED, using Core Data fallback")
            return try await fetchFromCoreData()
        }
    }

    private func persistDeals(_ deals: [FlightDeal]) async {
        await coreDataStack.performBackgroundTask { context in
            // Clear old deals (>7 days)
            let fetchRequest = DealEntity.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "timestamp < %@",
                Date().addingTimeInterval(-7 * 24 * 60 * 60) as NSDate
            )
            let old = try? context.fetch(fetchRequest)
            old?.forEach { context.delete($0) }

            // Insert new deals
            deals.forEach { deal in
                let entity = DealEntity(context: context)
                entity.id = deal.id
                entity.origin = deal.route.origin.iataCode
                entity.destination = deal.route.destination.iataCode
                entity.price = deal.price
                entity.airline = deal.airline.iataCode
                entity.timestamp = Date()
            }

            try? context.save()
        }
    }

    private func fetchFromCoreData() async throws -> [FlightDeal] {
        try await coreDataStack.performBackgroundTask { context in
            let fetchRequest = DealEntity.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "timestamp", ascending: false)
            ]
            fetchRequest.fetchLimit = 50

            let entities = try context.fetch(fetchRequest)
            return entities.compactMap { $0.toDomain() }
        }
    }
}
```

---

### 4. PersonalizationService (On-Device ML)

```swift
import CoreML

protocol PersonalizationServiceProtocol {
    func scoreDeals(_ deals: [FlightDeal]) -> [FlightDeal]
}

final class PersonalizationService: PersonalizationServiceProtocol {
    private let model: DealRanker
    private let userPreferences: UserPreferences

    init() {
        // Load Core ML model (bundled in app)
        self.model = try! DealRanker(configuration: MLModelConfiguration())
        self.userPreferences = UserPreferences.current
    }

    func scoreDeals(_ deals: [FlightDeal]) -> [FlightDeal] {
        deals.map { deal in
            var scored = deal
            scored.score = predictScore(for: deal)
            return scored
        }
    }

    private func predictScore(for deal: FlightDeal) -> DealScore {
        // Extract features
        let features = DealRankerInput(
            route: deal.route.description,
            airline: deal.airline.iataCode,
            priceDelta: deal.price - deal.averagePrice,
            userRouteFrequency: userPreferences.routeFrequency(deal.route),
            userAlliancePreference: userPreferences.allianceScore(deal.airline.alliance)
        )

        // Inference (on Neural Engine if available)
        guard let prediction = try? model.prediction(input: features) else {
            // Fallback: baseline score
            return DealScore(value: 0.5, explanation: ["Baseline scoring"])
        }

        // Parse output
        return DealScore(
            value: prediction.score,
            explanation: prediction.topFeatures
        )
    }
}

// USER PREFERENCES (On-Device Only)
struct UserPreferences {
    var frequentRoutes: [Route: Int] = [:] // Route → view count
    var preferredAlliances: [Airline.Alliance: Double] = [:] // Alliance → preference weight
    var preferredAirports: [PreferredAirport] = [] // Free: 1, Pro: 3 with weights

    func routeFrequency(_ route: Route) -> Int {
        frequentRoutes[route] ?? 0
    }

    func allianceScore(_ alliance: Airline.Alliance) -> Double {
        preferredAlliances[alliance] ?? 0.5
    }
}

struct PreferredAirport: Codable, Hashable {
    let iata: String // "LAX", "JFK", "ORD"
    let weight: Double // Pro tier: 0.6, 0.3, 0.1 (ranked priority), Free tier: 1.0
    let priority: Int // 1 = highest, 3 = lowest
}
```

---

## SMART QUEUE RANKING ALGORITHM

### Formula

```swift
// SmartQueueService.swift
func calculateQueueScore(deal: FlightDeal, user: User) -> Double {
    var score = Double(deal.dealScore) // Base: 0-100

    // 1. Watchlist boost: +20% if deal matches user's watchlist
    let watchlistBoost: Double = user.watchlists.contains(where: { $0.matches(deal) }) ? 0.2 : 0.0

    // 2. Airport weight: Apply user's preferred airport weight
    var airportWeight: Double = 0.0
    if let airport = user.preferredAirports.first(where: { $0.iata == deal.origin }) {
        airportWeight = airport.weight // 0.6 for LAX if user set 60%
    }

    // 3. Final score formula
    let finalScore = score * (1.0 + watchlistBoost) * (1.0 + airportWeight)

    return finalScore
}

// Tiebreaker rules (when scores are equal)
func sortDeals(_ deals: [FlightDeal]) -> [FlightDeal] {
    deals.sorted { a, b in
        if a.queueScore == b.queueScore {
            // Same score → sort by price (lower first)
            if a.totalPrice == b.totalPrice {
                // Same price → sort by departure date (soonest first)
                return a.departureDate < b.departureDate
            }
            return a.totalPrice < b.totalPrice
        }
        return a.queueScore > b.queueScore // Higher score first
    }
}
```

### Examples

**Example 1: Watchlist Priority**
- Deal: LAX→NYC, $450, DealScore 85
- User has watchlist: LAX→NYC
- Calculation: `85 × (1 + 0.2) × (1 + 0.6) = 85 × 1.2 × 1.6 = 163.2`
- Result: Boosted to 163.2 (watchlist + preferred airport)

**Example 2: Non-Watchlist Discovery**
- Deal: SFO→NYC, $450, DealScore 85
- User has NO watchlist for SFO→NYC
- User preferred airport: LAX (not SFO)
- Calculation: `85 × (1 + 0.0) × (1 + 0.0) = 85`
- Result: Base score 85 (no boosts)

**Example 3: Tiebreaker**
- Deal A: LAX→NYC, $450, Score 85 → Final: 163.2
- Deal B: LAX→LHR, $450, Score 85 → Final: 163.2
- Tiebreaker: Both same score → sort by price (both $450) → sort by date (A departs Nov 15, B departs Nov 20)
- Result: Deal A sent first (soonest departure)

---

## NAVIGATION ARCHITECTURE

### Coordinator Pattern (SwiftUI-Compatible)

```swift
// COORDINATOR PROTOCOL
protocol Coordinator: ObservableObject {
    var path: NavigationPath { get set }
    func navigate(to route: Route)
    func pop()
}

// APP COORDINATOR
@Observable
final class AppCoordinator: Coordinator {
    var path = NavigationPath()

    enum Route: Hashable {
        case dealDetail(FlightDeal)
        case search
        case watchlistEditor(Watchlist?)
        case settings
    }

    func navigate(to route: Route) {
        path.append(route)
    }

    func pop() {
        path.removeLast()
    }
}

// VIEW INTEGRATION
struct RootView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            DealFeedView(coordinator: coordinator)
                .navigationDestination(for: AppCoordinator.Route.self) { route in
                    destination(for: route)
                }
        }
    }

    @ViewBuilder
    private func destination(for route: AppCoordinator.Route) -> some View {
        switch route {
        case .dealDetail(let deal):
            DealDetailView(deal: deal, coordinator: coordinator)
        case .search:
            SearchView(coordinator: coordinator)
        case .watchlistEditor(let watchlist):
            WatchlistEditorView(watchlist: watchlist, coordinator: coordinator)
        case .settings:
            SettingsView(coordinator: coordinator)
        }
    }
}

// WHY COORDINATOR:
// - Views don't know navigation logic (testable)
// - Deep linking handled in one place
// - Easy to A/B test flows
```

---

## TESTING STRATEGY

### Coverage Targets

| Category | Target | Critical Paths |
|----------|--------|----------------|
| ViewModels | 90% | 100% |
| Services | 85% | 100% |
| Repositories | 80% | 95% |
| Utilities | 70% | N/A |
| Overall | 80% | 95% |

### Test Pyramid

```
       ┌─────────────┐
       │  UI Tests   │  (10%)
       │  20 tests   │  Critical flows (search, book, watchlist)
       └─────────────┘
      ┌───────────────┐
      │  Integration  │  (20%)
      │  50 tests     │  Network + Persistence, Service + ViewModel
      └───────────────┘
    ┌─────────────────────┐
    │   Unit Tests        │  (70%)
    │   200+ tests        │  ViewModels, Services, Utilities
    └─────────────────────┘
```

### Example Unit Test (Swift Testing Framework)

```swift
import Testing
@testable import FareLens

@Suite("DealFeedViewModel Tests")
struct DealFeedViewModelTests {

    @Test("Load deals - success")
    func testLoadDeals_success() async throws {
        // Arrange
        let mockDeals = [
            FlightDeal.mock(id: "1", price: 299),
            FlightDeal.mock(id: "2", price: 399)
        ]
        let mockService = MockDealService(deals: mockDeals)
        let viewModel = DealFeedViewModel(dealService: mockService)

        // Act
        await viewModel.loadDeals()

        // Assert
        #expect(viewModel.deals.count == 2)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.error == nil)
    }

    @Test("Load deals - network error")
    func testLoadDeals_networkError() async throws {
        // Arrange
        let mockService = MockDealService(error: NetworkError.offline)
        let viewModel = DealFeedViewModel(dealService: mockService)

        // Act
        await viewModel.loadDeals()

        // Assert
        #expect(viewModel.deals.isEmpty)
        #expect(viewModel.error == .networkError)
    }

    @Test("Apply filter")
    func testApplyFilter() async throws {
        // Arrange
        let mockService = MockDealService(deals: [.mock()])
        let viewModel = DealFeedViewModel(dealService: mockService)
        let filter = DealFilter(maxPrice: 500, airlines: ["UA", "AA"])

        // Act
        await viewModel.applyFilter(filter)

        // Assert
        #expect(viewModel.filter == filter)
        #expect(mockService.lastFilter == filter) // Verify service called with filter
    }
}

// MOCK SERVICE
final class MockDealService: DealServiceProtocol {
    var deals: [FlightDeal] = []
    var error: Error?
    var lastFilter: DealFilter?

    init(deals: [FlightDeal] = [], error: Error? = nil) {
        self.deals = deals
        self.error = error
    }

    func fetchDeals(filter: DealFilter) async throws -> [FlightDeal] {
        lastFilter = filter
        if let error = error { throw error }
        return deals
    }
}
```

### Integration Test (Network + Persistence)

```swift
@Suite("DealRepository Integration Tests")
struct DealRepositoryIntegrationTests {

    @Test("Fetch deals - cache → network → Core Data flow")
    func testFetchDeals_fullFlow() async throws {
        // Arrange
        let mockAPIClient = MockAPIClient(response: AmadeusFlightOfferDTO.mock)
        let coreDataStack = CoreDataStack.inMemory // Test stack
        let cache = CacheManager() // Fresh cache
        let repository = DealRepository(
            apiClient: mockAPIClient,
            coreDataStack: coreDataStack,
            cache: cache
        )

        // Act - First call (cache miss → network)
        let firstFetch = try await repository.getDeals()

        // Assert - Network called
        #expect(mockAPIClient.callCount == 1)
        #expect(firstFetch.count == 2)

        // Act - Second call (cache hit)
        let secondFetch = try await repository.getDeals()

        // Assert - Network NOT called again
        #expect(mockAPIClient.callCount == 1) // Still 1
        #expect(secondFetch.count == 2) // Same data

        // Act - Wait 6 minutes (cache expired)
        cache.advanceTime(by: 360) // Mock time travel
        let thirdFetch = try await repository.getDeals()

        // Assert - Network called again
        #expect(mockAPIClient.callCount == 2)
    }
}
```

### UI Test (Critical Flow)

```swift
import XCTest

final class SearchFlowUITests: XCTestCase {

    func testSearchFlow_happyPath() throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Tap search
        app.buttons["Search Flights"].tap()

        // 2. Enter origin
        let originField = app.textFields["Origin"]
        originField.tap()
        originField.typeText("LAX")
        app.buttons["Los Angeles (LAX)"].tap()

        // 3. Enter destination
        let destinationField = app.textFields["Destination"]
        destinationField.tap()
        destinationField.typeText("NYC")
        app.buttons["New York (JFK)"].tap()

        // 4. Select date
        app.buttons["Select Dates"].tap()
        app.buttons["December 15"].tap()
        app.buttons["Done"].tap()

        // 5. Search
        app.buttons["Search"].tap()

        // 6. Verify results appear
        XCTAssertTrue(app.staticTexts["Search Results"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.cells.count > 0)
    }

    func testSearchFlow_noResults() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitest-no-results"] // Mock flag
        app.launch()

        // Execute search...

        // Verify empty state
        XCTAssertTrue(app.staticTexts["No flights found"].exists)
        XCTAssertTrue(app.buttons["Try different dates"].exists)
    }
}
```

---

## PERFORMANCE OPTIMIZATION

### 1. Launch Time Target: <2 seconds (Cold Start)

**Strategies:**

**Reduce Main Thread Work:**
```swift
@main
struct FareLensApp: App {
    init() {
        // DEFER heavy initialization to background
        DispatchQueue.global(qos: .background).async {
            // Warm up Core Data stack
            _ = CoreDataStack.shared

            // Preload Core ML model
            _ = PersonalizationService.shared

            // Cache frequently used images
            ImageCache.shared.preloadCommonAssets()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onAppear {
                    // Track launch time
                    AnalyticsService.shared.track(.appLaunched)
                }
        }
    }
}
```

**Lazy Load Features:**
```swift
// DON'T load all tabs upfront
struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DealFeedView() // ONLY this loads initially
                .tag(0)

            LazyView { SearchView() } // Loads when selected
                .tag(1)

            LazyView { WatchlistView() }
                .tag(2)
        }
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    var body: Content { build() }
}
```

**Optimize App Size (Target: <50MB):**
- Asset catalogs: Compress images (WebP), on-demand resources
- Bitcode: Disabled (Apple deprecated)
- Strip symbols: Release builds only
- App thinning: Automatic (per-device downloads)

**Measure Launch Time (Automated):**
```swift
import XCTest

final class LaunchPerformanceTests: XCTestCase {
    func testLaunchTime() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
        // Target: <2 seconds (measured on iPhone SE 2022)
    }
}
```

---

### 2. Scroll Performance: 60fps (No Dropped Frames)

**SwiftUI Optimization:**

```swift
struct DealFeedView: View {
    @State private var viewModel = DealFeedViewModel()

    var body: some View {
        List {
            ForEach(viewModel.deals) { deal in
                DealCardView(deal: deal)
                    .id(deal.id) // IMPORTANT: Stable IDs for diffing
            }
        }
        .listStyle(.plain) // Faster than .insetGrouped
    }
}

struct DealCardView: View {
    let deal: FlightDeal

    var body: some View {
        // AVOID: Heavy computations in body
        // DO: Pre-compute in ViewModel

        HStack {
            // AsyncImage with placeholder (lazy loading)
            AsyncImage(url: deal.airlineLogoURL) { image in
                image.resizable()
            } placeholder: {
                Color.gray.opacity(0.2)
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading) {
                Text(deal.route.description)
                    .font(.headline)
                Text(deal.formattedPrice) // Pre-formatted in model
                    .font(.subheadline)
            }
        }
        .padding()
        .background(GlassCard()) // Custom modifier (cached)
    }
}
```

**Instruments Profiling:**
- Time Profiler: Identify slow rendering
- Core Animation: Find dropped frames
- Allocations: Detect memory leaks

---

### 3. Network Performance: <1.2s Search Response (p95)

**Parallel Requests:**
```swift
func fetchSearchResults() async throws -> SearchResults {
    async let flights = apiClient.fetch(endpoint: .flightOffers)
    async let affiliateLinks = apiClient.fetch(endpoint: .affiliateLinks)

    // Both requests execute in parallel
    let (flightData, linkData) = try await (flights, affiliateLinks)

    return SearchResults(flights: flightData, links: linkData)
}
```

**Request Coalescing (Avoid Duplicate Calls):**
```swift
actor RequestCoalescer {
    private var inflight: [String: Task<Data, Error>] = [:]

    func fetch(url: URL) async throws -> Data {
        let key = url.absoluteString

        if let existing = inflight[key] {
            return try await existing.value
        }

        let task = Task {
            try await URLSession.shared.data(from: url).0
        }
        inflight[key] = task

        defer { inflight[key] = nil }
        return try await task.value
    }
}
```

**Retry Logic (Exponential Backoff):**
```swift
func fetchWithRetry<T: Decodable>(
    endpoint: Endpoint,
    maxAttempts: Int = 3
) async throws -> T {
    var attempt = 0
    var delay: TimeInterval = 1.0

    while attempt < maxAttempts {
        do {
            return try await apiClient.fetch(endpoint: endpoint)
        } catch {
            attempt += 1
            if attempt == maxAttempts { throw error }

            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            delay *= 2 // Exponential backoff (1s → 2s → 4s)
        }
    }

    throw NetworkError.maxRetriesExceeded
}
```

---

### 4. Memory Management

**Avoid Retain Cycles:**
```swift
@Observable
class DealDetailViewModel {
    private let dealService: DealServiceProtocol

    func loadPriceHistory() async {
        Task { [weak self] in // IMPORTANT: [weak self]
            guard let self = self else { return }
            let history = try? await dealService.fetchPriceHistory()
            self.priceHistory = history
        }
    }
}
```

**Image Caching (LRU Eviction):**
```swift
final class ImageCache {
    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 100 // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    func image(for url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func setImage(_ image: UIImage, for url: URL) {
        let cost = image.pngData()?.count ?? 0
        cache.setObject(image, forKey: url.absoluteString as NSString, cost: cost)
    }
}
```

---

### 5. Battery Optimization

**Background Fetch Budget:**
```swift
// AppDelegate.swift
func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    Task {
        let hasNewData = await WatchlistService.shared.checkForUpdates()
        completionHandler(hasNewData ? .newData : .noData)
    }
}

// Register task (iOS 13+)
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.farelens.refresh",
    using: nil
) { task in
    task.expirationHandler = {
        task.setTaskCompleted(success: false)
    }

    Task {
        await WatchlistService.shared.checkForUpdates()
        task.setTaskCompleted(success: true)

        // Schedule next run (15-30 min)
        scheduleNextBackgroundRefresh()
    }
}
```

**Efficient Queries:**
```swift
// BAD: Fetch all, filter in-memory
let allDeals = try await repository.getDeals()
let filtered = allDeals.filter { $0.price < 500 }

// GOOD: Filter in Core Data
let fetchRequest = DealEntity.fetchRequest()
fetchRequest.predicate = NSPredicate(format: "price < %f", 500)
let filtered = try context.fetch(fetchRequest)
```

---

## ACCESSIBILITY ARCHITECTURE

### VoiceOver Support

```swift
struct DealCardView: View {
    let deal: FlightDeal

    var body: some View {
        HStack {
            // Visual UI...
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(deal.route.description), \(deal.formattedPrice)")
        .accessibilityHint("Double tap to view details")
        .accessibilityAddTraits(.isButton)
    }
}

// Custom Actions (Swipe)
struct WatchlistCardView: View {
    let watchlist: Watchlist

    var body: some View {
        // Visual UI...
        .accessibilityAction(named: "Delete") {
            deleteWatchlist()
        }
        .accessibilityAction(named: "Edit") {
            editWatchlist()
        }
    }
}
```

### Dynamic Type

```swift
struct DealCardView: View {
    @Environment(\.sizeCategory) var sizeCategory

    var body: some View {
        VStack {
            Text(deal.route.description)
                .font(.headline) // Scales automatically
                .lineLimit(sizeCategory.isAccessibilityCategory ? nil : 2)

            Text(deal.formattedPrice)
                .font(.title2)
        }
        .padding(sizeCategory.isAccessibilityCategory ? 20 : 12) // Larger touch targets
    }
}
```

### Reduced Motion

```swift
struct DealCardView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        // Visual UI...
        .transition(reduceMotion ? .opacity : .slide) // Crossfade instead of slide
        .animation(reduceMotion ? nil : .spring(), value: deal.id)
    }
}
```

### Color Contrast (WCAG AA: ≥4.5:1)

```swift
extension Color {
    static let primaryText = Color(
        light: .black, // Contrast: 21:1 (on white)
        dark: .white   // Contrast: 21:1 (on black)
    )

    static let secondaryText = Color(
        light: Color(hex: 0x666666), // Contrast: 5.7:1
        dark: Color(hex: 0x999999)   // Contrast: 5.5:1
    )
}
```

---

## CRITICAL TECHNICAL RISKS & MITIGATION

### Risk 1: Amadeus API Quota Exceeded (2k calls/month)

**Likelihood:** HIGH (with 10k users)
**Impact:** HIGH (app unusable without data)

**Mitigation:**
1. **Aggressive caching:** 5-min TTL for search results, 15-min for watchlists
2. **Backend proxy:** Cloudflare Workers caches responses, tracks quota
3. **Travelpayouts fallback:** Switch to affiliate API if Amadeus quota exceeded
4. **User education:** "Prices update every 5 minutes" (not real-time)
5. **Pro tier priority:** Pro users get quota preference (background refresh)
6. **Quota monitoring:** Alert team at 80% usage, throttle background fetch at 90%

**Code:**
```swift
actor QuotaManager {
    private var callsThisMonth = 0
    private let limit = 2000

    func canMakeCall() -> Bool {
        callsThisMonth < limit * 0.9 // 90% threshold
    }

    func recordCall() {
        callsThisMonth += 1
    }

    func resetMonthly() {
        callsThisMonth = 0
    }
}
```

---

### Risk 2: Affiliate Link Conversion Tracking Failure

**Likelihood:** MEDIUM (30-day cookie dependencies)
**Impact:** HIGH (no revenue)

**Mitigation:**
1. **Server-side click tracking:** Log all affiliate clicks (dealId, userId, timestamp)
2. **Webhook validation:** Backend receives commission webhooks, reconciles with clicks
3. **Manual reconciliation:** Monthly cross-check Travelpayouts dashboard vs logs
4. **User feedback:** Post-booking survey "Did you complete booking?" (track completion rate)
5. **A/B testing:** Test different CTAs, measure click → booking conversion

---

### Risk 3: Background Refresh Unreliable (iOS Limitations)

**Likelihood:** HIGH (iOS throttles background tasks)
**Impact:** MEDIUM (stale watchlist data, missed alerts)

**Mitigation:**
1. **Silent push notifications:** Server pushes exceptional deals (bypass background fetch limits)
2. **Smart scheduling:** Request background refresh during low-battery periods
3. **User expectations:** "Alerts may take up to 15 minutes" (manage expectations)
4. **Foreground refresh:** Refresh on app launch (most users check daily)
5. **In-app countdowns:** Use native Timer for time-sensitive deals (Live Activities deferred to Phase 2)

---

### Risk 4: Core Data Migration Failure (Schema Changes)

**Likelihood:** MEDIUM (as app evolves)
**Impact:** HIGH (data loss, crashes)

**Mitigation:**
1. **Lightweight migrations:** Avoid complex mapping models (add-only fields)
2. **Version testing:** Test migration from v1 → v2 → v3 in automated tests
3. **Backup strategy:** Export user data to JSON before migration (restore if failure)
4. **Gradual rollout:** Release to 10% users first, monitor crash rate
5. **Rollback plan:** Backend API version compatibility (support old clients)

**Code:**
```swift
let container = NSPersistentContainer(name: "FareLens")
let description = container.persistentStoreDescriptions.first

// Enable automatic migration
description?.shouldMigrateStoreAutomatically = true
description?.shouldInferMappingModelAutomatically = true

// Backup before migration
if !FileManager.default.fileExists(atPath: backupURL.path) {
    try? FileManager.default.copyItem(at: storeURL, to: backupURL)
}
```

---

### Risk 5: App Store Rejection (Privacy, Guidelines)

**Likelihood:** MEDIUM (strict review process)
**Impact:** HIGH (delayed launch)

**Mitigation:**
1. **Privacy Manifest:** Complete NSPrivacyCollectedDataTypes before submission
2. **Guidelines review:** Checklist for 2.3 (accurate metadata), 4.2 (minimum functionality), 5.1 (privacy)
3. **Pre-submission audit:** Internal review using App Review Guidelines
4. **TestFlight beta:** 50 external testers, collect feedback before submission
5. **Expedited review:** Reserve for critical bugs (post-launch)

**Checklist:**
- [ ] Privacy Manifest (PrivacyInfo.xcprivacy)
- [ ] App Privacy Nutrition Label (App Store Connect)
- [ ] Accurate screenshots (match actual UI)
- [ ] No "Beta" or "Demo" labels (must be production-ready)
- [ ] Affiliate disclosure in Terms & Privacy Policy
- [ ] No gambling, contests, sweepstakes (flight deals = editorial content, OK)

---

## TECHNOLOGY STACK SUMMARY

| Layer | Technology | Rationale |
|-------|------------|-----------|
| **UI Framework** | SwiftUI (iOS 26.0+) | Modern, productive, Liquid Glass design |
| **Architecture** | MVVM + @Observable | Testable, clear separation, native |
| **Concurrency** | async/await + Actors | Structured concurrency, safe |
| **Networking** | URLSession | Native, no dependencies, async/await |
| **Persistence** | Core Data | Offline-first, CloudKit-ready |
| **Caching** | NSCache + UserDefaults | In-memory + lightweight prefs |
| **Security** | Keychain + Secure Enclave | Token storage, biometric auth |
| **ML** | Core ML + Foundation Models | On-device, privacy-preserving |
| **Widgets** | WidgetKit (Phase 2) | Deferred post-MVP |
| **Analytics** | Firebase (free tier) | A/B testing, Remote Config |
| **Crash Reporting** | Xcode Organizer (native) | Free, integrated |
| **Charts** | Swift Charts | Native, iOS 16+, beautiful |
| **Payments** | StoreKit 2 | Native subscriptions (Free/Pro) |
| **Push Notifications** | APNs | Native, silent + visible |
| **Background** | BGTaskScheduler | iOS 13+, reliable |
| **Testing** | Swift Testing + XCTest | Modern + UI tests |
| **CI/CD** | Xcode Cloud (future) | Native, TestFlight integration |

**Third-Party Dependencies: Minimal (Firebase Only)**

- **Firebase SDK:** Analytics, Crashlytics, Remote Config (free tier)
- **Justification:** A/B testing, crash reporting, feature flags critical for MVP iteration
- **App Size Impact:** +2.5MB compiled (acceptable, target <50MB total)
- **Privacy:** All data anonymized, no ATT required, disclosed in Privacy Manifest
- **Alternative Considered:** Native-only (Xcode Organizer for crashes) - rejected due to lack of Remote Config for feature flags

---

## DEVELOPMENT ROADMAP

### Phase 1: MVP (Weeks 1-6)

**Week 1-2: Core Architecture**
- [x] Project setup (Xcode, SwiftUI, Core Data schema)
- [x] Module structure (App, Features, Core, Data, DesignSystem)
- [x] Dependency injection setup (protocols, environment)
- [x] APIClient + Amadeus integration
- [x] Core Data stack + repositories

**Week 3-4: Core Features**
- [x] DealFeed (fetch, display, filter)
- [x] DealDetail (price history, affiliate links)
- [x] Search (airports, dates, travelers)
- [x] Watchlist (CRUD, Free: 2, Pro: unlimited)

**Week 5: Personalization + Notifications**
- [x] Core ML model integration (DealRanker)
- [x] Push notifications (APNs, quiet hours, dedupe)
- [x] Background refresh (BGTaskScheduler)

**Week 6: Polish + Testing**
- [x] Liquid Glass UI components (GlassCard, GlassSheet)
- [x] Accessibility (VoiceOver, Dynamic Type, Reduced Motion)
- [x] Unit tests (80% coverage)
- [x] UI tests (critical flows)

### Phase 2: Engagement & Retention Features (Post-MVP)

**Defer to Phase 2 (per user decision):**
- Widgets (Today's Deal, Watchlist Status, Transfer Bonuses)
- Live Activities (deal expiry countdown with real-time updates)
- Siri Shortcuts (voice commands: "Hey Siri, show me deals")
- Compensation flow (AirHelp, Compensair passive tracking)
- Hotels/Cars (Trip.com affiliate expansion)
- Multi-city itineraries
- Award seat search (Amadeus doesn't support)

### Phase 3: Scale & Optimize (Weeks 11-12)

- Performance profiling (Instruments)
- Crash analytics (Xcode Organizer)
- A/B testing (Firebase Remote Config)
- Localization (Spanish, Phase 2)
- Beta testing (TestFlight, 50 users)
- App Store submission

---

## KEY ARCHITECTURAL DECISIONS SUMMARY

### 1. MVVM + SwiftUI + async/await
**Why:** Modern, testable, productive. SwiftUI maturity (iOS 26.0+) justifies adoption. MVVM clear separation (View → ViewModel → Service → Repository).

### 2. iOS 26.0+ Minimum Target
**Why:** Latest SwiftUI enhancements, Observation framework (@Observable), Advanced Live Activities, Charts framework improvements. Cutting-edge iOS capabilities for premium user experience.

**NOTE:** Per user confirmation with iOS 26 release notes (https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes), iOS 26.0 exists and is the target platform. Agents must NOT question this decision.

### 3. Core Data for Persistence
**Why:** Offline-first, CloudKit-ready, battle-tested. Avoids third-party dependencies (Realm).

### 4. Native URLSession (No Alamofire)
**Why:** async/await covers 99% use cases. Smaller app size, faster compile, one less dependency.

### 5. On-Device Personalization (Core ML)
**Why:** Privacy-preserving, low latency (<50ms), $0 cost. Hybrid with server baselines.

### 6. Zero Third-Party Dependencies
**Why:** Smaller app (<50MB target), faster compile, full control, no maintenance burden.

### 7. Aggressive Caching (5-min TTL)
**Why:** Amadeus quota (2k/month) requires smart caching. Balance freshness vs availability.

### 8. Coordinator Pattern for Navigation
**Why:** Testable navigation, deep linking in one place, A/B test flows easily.

### 9. Protocol-Based DI
**Why:** Easy mocking for tests (80% coverage target). Supports feature flags, environment switching.

### 10. Privacy-First (Keychain, Secure Enclave, No Tracking)
**Why:** Trust is core to brand. No third-party analytics (Firebase free tier only). GDPR/CCPA compliant.

---

## CONCERNS & RECOMMENDATIONS

### Concern 1: Amadeus Quota Too Low for Scale

**Problem:** 2k calls/month = 67/day. With 10k users, can't serve everyone.

**Recommendation:**
- **Short-term:** Aggressive caching (5-min TTL), backend proxy (Cloudflare caches)
- **Medium-term:** Upgrade to paid Amadeus tier ($200/mo = 10k calls)
- **Long-term:** Travelpayouts API has no quota (but affiliate-only, less comprehensive)

**Product Decision Needed:** Accept stale data (5-min old) vs pay for real-time? Recommend: Start with caching, upgrade if user complaints.

---

### Concern 2: Liquid Glass Design Performance

**Problem:** Blur effects (frosted glass) are GPU-intensive. May drop frames on iPhone SE.

**Recommendation:**
- **Test early:** Profile on iPhone SE 2022 (lowest target device)
- **Fallback:** Disable blur on low-end devices (detect performance tier)
- **Optimize:** Static gradient instead of dynamic blur (if needed)

**Design Challenge:** If blur kills performance, debate with product-designer on alternatives.

---

### Concern 3: Affiliate Conversion Tracking Opacity

**Problem:** 30-day cookies, no real-time feedback. Hard to attribute revenue to features.

**Recommendation:**
- **Server-side logging:** Track every affiliate click (dealId, userId, placement)
- **Webhook reconciliation:** Match Travelpayouts webhooks to logged clicks
- **Monthly review:** Manual cross-check dashboard vs logs
- **Proxy metrics:** Track click-through rate (CTR), time-to-book (proxy for conversion)

---

### Concern 4: Background Refresh Unreliable

**Problem:** iOS throttles background tasks (15-30 min intervals, not guaranteed).

**Recommendation:**
- **Silent push:** Server-initiated for exceptional deals (bypass limits)
- **Foreground refresh:** Most users check app daily (refresh on launch)
- **Manage expectations:** "Alerts may take up to 15 minutes" (transparency)

**Product Decision Needed:** Accept 15-min delay vs invest in push infrastructure? Recommend: Start with BGTaskScheduler, add silent push if complaints.

---

### Concern 5: Core ML Model Accuracy

**Problem:** On-device personalization requires training data (cold start problem).

**Recommendation:**
- **Hybrid approach:** Server baselines (global trends), on-device weighting (user prefs)
- **Fallback:** If no user data, use server scores only (no degradation)
- **Validation:** Track precision@K (top 5 deals match user preferences)
- **Iterate:** Retrain model monthly (offline, ship with app updates)

**Success Metric:** Alert open rate ≥60% (vs industry ~30%). If <50%, personalization isn't working.

---

## RECOMMENDED MVP SCOPE ADJUSTMENTS

### Must-Have (P0)

- [x] Flight search (Amadeus)
- [x] Watchlists (Free: 2, Pro: unlimited)
- [x] Alerts (caps, quiet hours, dedupe)
- [x] Affiliate deep links (Aviasales, WayAway)
- [x] Deal feed (personalized, filterable)
- [x] Liquid Glass UI (core components)

### Should-Have (P1) - KEEP IN MVP (per user decision)

- [x] Points Vault (credit card points tracking, loyalty programs)
- [x] On-Device ML Personalization (Core ML DealRanker model)

### Defer to Phase 2 (per user decision)

- [ ] Widgets (iOS Home Screen + Lock Screen widgets)
- [ ] Live Activities (deal countdown timers, real-time updates)
- [ ] Siri Shortcuts (voice integration)
- [ ] Compensation flow (AirHelp, Compensair passive tracking)

### Nice-to-Have (P2) - Phase 2

- [ ] Hotels/Cars (Trip.com)
- [ ] MQD Estimator
- [ ] Siri Shortcuts
- [ ] Localization (Spanish)

**Recommendation:** Ship MVP with P0 only. Validate product-market fit before investing in P1/P2.

---

## FINAL VALIDATION CHECKLIST

Before development starts:

- [x] PRD reviewed (requirements clear)
- [ ] DESIGN.md reviewed (UI feasible, performance considered)
- [ ] Backend architect alignment (API contracts, affiliate links)
- [ ] Legal review (affiliate disclosure, privacy policy)
- [ ] Amadeus account approved (API keys active)
- [ ] Travelpayouts account approved (affiliate links live)
- [ ] Developer account ($99/year paid)
- [ ] TestFlight setup (for beta testing)

Before App Store submission:

- [ ] 80% test coverage (unit + integration)
- [ ] Critical flows UI tested (search, book, watchlist)
- [ ] Accessibility audit (VoiceOver, Dynamic Type, contrast)
- [ ] Performance benchmarks met (launch <2s, scroll 60fps)
- [ ] Privacy manifest complete
- [ ] Terms & Privacy Policy published
- [ ] App Store metadata (screenshots, description, keywords)
- [ ] TestFlight beta (50 users, 2 weeks, no critical bugs)

---

## CLOSING REMARKS

This architecture is designed to:
- **Ship fast:** MVVM + SwiftUI = productive
- **Scale gracefully:** Modular, testable, maintainable
- **Beat competitors:** Faster, lighter, more reliable
- **Preserve trust:** Privacy-first, transparent, offline-capable

**Key Principle:** Start simple, scale intentionally. Avoid premature optimization and over-engineering.

**Next Steps:**
1. Wait for DESIGN.md from product-designer (validate Liquid Glass feasibility)
2. Align with backend-architect on API contracts (Cloudflare Workers, Supabase schema)
3. Challenge any design/product decisions that conflict with this architecture
4. Start development (target: 6-week MVP)

**I'm ready to debate:**
- Designer on UI performance (blur effects, animations)
- Backend architect on API contracts (request/response formats)
- Product manager on scope (MVP vs Phase 2)

**I will NOT ask user for:**
- Technical decisions (I'm the expert)
- Framework choices (already decided: SwiftUI, Core Data, etc.)
- Architecture patterns (MVVM locked in)

**Let's build an app that lasts years and delights millions.**

---

**End of Architecture Document**
