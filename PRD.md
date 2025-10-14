FARELENS — PRODUCT REQUIREMENTS DOCUMENT v2.0
Company: Astrion Studio
App: FareLens
Date: 2025-10-06
Owner: Product Manager
Status: Ready for Design & Architecture

## EXECUTIVE SUMMARY

**Problem**: Travelers waste hours searching multiple sites for flight deals, miss price drops, and can't distinguish between genuinely good deals vs marketing hype.

**Solution**: FareLens is an AI-powered flight price intelligence app that monitors flights, identifies truly exceptional deals, and sends personalized alerts when the right deal appears.

**Success**: MVP is successful when 70%+ of users save at least one watchlist in week 1, and 60%+ open alerts within 1 hour.

---

## TARGET AUDIENCE

**Primary Users**: Savvy leisure travelers (ages 28-45)
- **Demographics**: Middle to upper-middle income ($75k-$150k), urban/suburban, tech-literate
- **Behaviors**: Book 3-6 personal trips/year, flexible dates, research extensively before booking
- **Pain Points**:
  - "I spend hours comparing prices across sites"
  - "I missed a great deal because I didn't check at the right time"
  - "I don't know if $400 is actually a good price for this route"
- **Motivations**: Save money without sacrificing time; confidence they got a fair deal

**Secondary Users**: Frequent business travelers who book personal travel
- Looking to maximize points/status for personal trips
- Need alerts that respect work hours (quiet hours critical)

---

## PRODUCT VISION

**Vision**: Become the most trusted flight price intelligence platform — users check FareLens first, always.

**Mission**: Deliver transparent, personalized flight deals that save users time and money.

**Positioning**: "The flight app that tells you the truth" — no fake urgency, no hidden partners, just honest deal intelligence.

---

## SUCCESS METRICS

**North Star Metric**: Time to a great booking
- Target: 70% of users see a "deal of the week" alert within 7 days of creating a watchlist

**Activation Metrics** (Week 1):
- 70% create at least 1 watchlist
- 50% enable notifications
- 30% complete a search

**Engagement Metrics** (Week 2-4):
- Alert open rate ≥ 60% (industry avg: 20-30%)
- 40% return to app within 48h of alert
- DAU/MAU ≥ 0.25

**Monetization Metrics** (Month 1-3):
- Affiliate CTR ≥ 15% (baseline: 10-12%)
- Pro conversion ≥ 8% within 30 days
- Churn < 10%/month

**Trust Metrics**:
- Precision@K > 0.5 (alerts users actually care about)
- 4.5+ App Store rating
- < 5% negative reviews mentioning "spam" or "fake deals"

**Operational SLOs** (Service Level Objectives):
- **Alert Delivery:** ≥99% of push-eligible exceptional deals delivered within 60 seconds
- **Watchlist Checks:** ≥95% of scheduled watchlist checks executed within window (9am ±15min, 6pm ±15min)
- **Affiliate Accuracy:** ≤0.1% dead links on affiliate CTAs (validate before showing to user)
- **API Uptime:** ≥99.5% backend availability (measured as successful responses / total requests)
- **Search Latency:** p95 search response time <1.2 seconds (measured from request to first result displayed)

---

## CORE FEATURES — MVP SCOPE (P0)

### P0-1: Live Flight Search
**User Story**: As a traveler, I want to search flights and see live prices so I can understand current market rates.

**Requirements**:
- Search by origin, destination, dates (one-way or round-trip)
- Display results sorted by total price (fare + taxes + typical bag fees)
- Show airline, duration, stops, departure/arrival times
- Powered by Amadeus Flight Offers API (2k calls/month free tier)
- Cache results 15 minutes to minimize API calls

**Acceptance Criteria**:
- ✅ Search returns results in < 2 seconds (p95)
- ✅ Prices include all mandatory fees (no surprise fees at checkout)
- ✅ Handles 0 results gracefully (suggest nearby dates/airports)
- ✅ Works offline with cached results (shows "last updated" timestamp)

**Success Metric**: 80% of searches return ≥ 3 results

---

### P0-2: Price Watchlists
**User Story**: As a traveler, I want to save a flight route/date so I can be notified when prices drop.

**Requirements**:
- Add search to watchlist (route + date range)
- Free tier: 5 watchlists max
- Pro tier: Unlimited watchlists (but only top 6/day by DealScore alerted if cap reached)
- Background monitoring: Free 1x/day (9am local time), Pro 2x/day (9am, 6pm local time)
- Edit/delete watchlists

**Acceptance Criteria**:
- ✅ User can create watchlist in ≤ 3 taps from search results
- ✅ Watchlist persists across app restarts
- ✅ User sees clear "5/5 watchlists used" warning in free tier
- ✅ Editing a watchlist preserves price history

**Success Metric**: 70% of users create ≥ 1 watchlist in week 1

---

### P0-3: Smart Price Alerts
**User Story**: As a traveler, I want to be notified only when there's a genuinely good deal so I don't waste time on false alarms.

**Requirements**:

**Free Tier Alert Strategy:**
- **3 alerts/day** (smart-ranked: watchlists prioritized first, then best deals from preferred airport)
- **Timing:** Immediate when deals found (same as Pro, just lower cap)
- **Rationale:** Simple, fair, no complex scheduling needed
- **In-app deals:** 20 deals visible (algorithm: show all ≥80 DealScore, if >20 remove lowest scores to cap at 20, if <20 backfill ≥70)

**Pro Tier Alert Strategy:**
- **6 alerts/day TOTAL** (watchlists + discoveries both count toward cap)
- **Timing:** Immediate when deals found
- **Watchlist-only mode:** Option to disable discovery alerts entirely (only get watchlist drops)
- **Spam prevention:** If user has 20 watchlists and 8 drop simultaneously, only top 6 by DealScore sent
- **Rationale:** More alerts, unlimited watchlists, but cap prevents spam

**Universal Rules:**
- **Alert delivery:** Immediate when deal found (both Free and Pro, cap is only difference)
- Quiet hours: 10pm-7am local time (customizable in Settings > Notifications)
- Deduplication: No repeat alerts for same deal within 12 hours
- **Smart queue formula:** `finalScore = dealScore × (1 + watchlistBoost) × (1 + airportWeight)` where:
  - `watchlistBoost = 0.2` if deal matches user's watchlist (20% boost)
  - `airportWeight = userAirportWeight` (e.g., 0.6 for LAX if user set 60% weight)
  - Tiebreaker: If same score → sort by price ASC, then departure date ASC
- **Preferred airports:** Free users select 1 (weight = 1.0), Pro users select 3 (weights must sum to 1.0, e.g., LAX 0.6, JFK 0.3, ORD 0.1)
- Alert anatomy: "NYC → Paris dropped to $420 (24% below avg)" + Deal Score (0-100)
- Actions: Book Now, Snooze Alerts, Pause Alerts, Undo (toast)
- **Snooze options:** 1 day, 1 week, 1 month, Custom date

**Acceptance Criteria**:
- ✅ Alert includes price, % vs average, Deal Score, and booking CTA
- ✅ Tapping alert opens deal detail screen with fare breakdown
- ✅ Both Free and Pro alerts sent immediately when deals found (only cap differs: 3 vs 6)
- ✅ Smart queue selects top N alerts when >cap deals drop simultaneously
- ✅ No duplicate alerts for same price/route within 12h dedup window
- ✅ Snooze Alerts shows picker (1 day/week/month/custom), displays banner "Snoozed until [date]" with Resume button
- ✅ Quiet hours customizable in Settings, defaults to 10pm-7am
- ✅ Preferred airports selectable in onboarding, changeable in Settings
- ✅ Preferred airport weights validated (Free: 1 airport weight=1.0, Pro: 3 airports sum=1.0)

**Success Metric**: Alert open rate ≥ 60% (4-hour window)

---

### P0-4: Deal Intelligence (DealScore)
**User Story**: As a traveler, I want to know if a price is actually good so I can book with confidence.

**Requirements**:
- DealScore: 0-100 scale (≥ 80 = "Exceptional", 60-79 = "Good", < 60 = hidden)
- Factors: historical price, route average, seasonality, time-to-departure
- Display: "24% below 90-day average" or "Lowest in 6 months"
- Fare ladder: show 3-day price trend (visual graph)

**Acceptance Criteria**:
- ✅ DealScore calculated server-side (not client-side to prevent gaming)
- ✅ Score visible on deal card and detail screen
- ✅ Explainability: tap "Why is this good?" → shows breakdown
- ✅ Fare ladder shows min 3 days of history (when available)

**Success Metric**: Precision@K > 0.5 (users rate alerts as "useful")

---

### P0-5: Transparent Booking
**User Story**: As a traveler, I want to see all booking options ranked honestly so I can choose the best one for me.

**Requirements**:
- Always show lowest verified fare first (even if non-affiliate)
- If affiliate (Aviasales/WayAway) within 7% of lowest → show 2nd CTA
- "Other offers" → GlassSheet with all providers ≤ 10% delta
- Ranking: Airline Direct > Top OTA > Affiliates > Others
- No "Partner" labels (just provider names: "Book on Delta" or "Book with Aviasales")
- Global disclosure in Terms: "FareLens may earn commission at no extra cost"

**Acceptance Criteria**:
- ✅ Lowest fare always displayed first (validated in tests)
- ✅ Affiliate links only shown if price ≤ lowest × 1.07
- ✅ GlassSheet sorted by total cost (taxes + bags included)
- ✅ Deep link format validated (includes marker, sub_id, campaign_id)
- ✅ Tapping CTA opens Safari in-app (not external browser)

**Success Metric**: Affiliate CTR ≥ 15%, < 5% complaints about "hidden fees"

---

### P0-6: Liquid Glass Design System
**User Story**: As a user, I want an iOS-native experience that feels premium and fast.

**Requirements**:
- iOS 26.0+ design language (translucent materials, frosted glass)
- Components: GlassList, GlassCard, GlassPillFilters, GlassSheet
- Dark mode + Light mode (system default)
- Dynamic Type support (accessibility)
- 60 fps scrolling, cold start < 2s

**Acceptance Criteria**:
- ✅ Passes Accessibility Inspector (VoiceOver, Dynamic Type)
- ✅ Contrast ratio ≥ 4.5:1 (WCAG AA)
- ✅ 60 fps on iPhone SE (3rd gen) under CPU throttling
- ✅ Cold start < 2s on iPhone 13 Pro

**Success Metric**: 4.5+ App Store rating, 0 reviews citing "slow" or "laggy"

---

### P0-7: Free + Pro Tiers
**User Story**: As a free user, I want to try the app with limited features; as a power user, I want unlimited watchlists and instant alerts.

**Free Tier**:
- 5 watchlists cap
- 3 instant alerts/day (immediate when deals found)
- 20 deals visible in-app (algorithm: show all ≥80 DealScore, if >20 remove lowest scores to cap, if <20 backfill ≥70)
- Basic filters only (price, stops, date)
- 1 preferred airport
- Tasteful native banner ad (60pt, bottom of deal feed, Google AdMob)
- All core features (search, DealScore, booking)

**Pro Tier** ($6.99/month or $49.99/year):
- Unlimited watchlists
- 6 instant alerts/day (immediate when deals found, watchlists count toward cap)
- Option to disable discovery alerts (watchlist-only mode)
- ALL deals visible (no 20-deal cap, no score filtering)
- Advanced filters (airlines, cabin class, duration, layovers)
- 3 preferred airports (ranked by priority for smart queue)
- Ad-free experience
- Priority support

**14-Day Free Trial** (ALL new users):
- Full Pro access for 14 days before payment begins
- Standard iOS StoreKit 2 trial flow
- After trial ends: subscribe to Pro or downgrade to Free tier

**Pricing Rationale**:
- Undercuts competitors by $1/mo ($8/mo industry standard) and $10/yr ($60/yr industry standard)
- $6.99 < $7 psychological threshold (impulse purchase)
- Annual = $4.17/mo (41% savings → incentivizes yearly commitment)
- Revenue projection (3K MAU, 5% conversion): ~$833/mo = $10K/yr + $2.5K affiliate = $12.5K/yr Year 1

**Acceptance Criteria**:
- ✅ Paywall shown when user tries to add 3rd watchlist or exceed alert cap
- ✅ StoreKit 2 integration (sandbox tested)
- ✅ Subscription status synced via iCloud (multi-device)
- ✅ Banner ad loads asynchronously (doesn't block UI)

**Success Metric**: Pro conversion ≥ 8% within 30 days

---

## SHOULD-HAVE FEATURES (P1 — Post-MVP)

### P1-1: iOS Widgets
- "Today's Top Deal" widget (Small/Medium)
- "Watchlist Status" widget (shows price changes)
- Live Activity for deal expiry countdown

**Rationale**: Increases engagement (users see deals without opening app), but not critical for MVP validation.

---

### P1-2: Siri Shortcuts
- "Hey Siri, show me deals to Europe"
- "Hey Siri, add this flight to my watchlist"

**Rationale**: Power user feature, low adoption expected in MVP phase.

---

### P1-3: Points Vault
- Store credit card points balances (Amex, Chase, Citi)
- Transfer bonus alerts (e.g., "Amex → Aeroplan 30% bonus today")
- Card recommendation engine ("Use Chase Sapphire for 3x points")

**Rationale**: Differentiator for frequent flyers, but adds significant complexity (requires OCR or manual entry). Defer until core product validated.

---

### P1-4: Advanced Personalization (On-Device ML)
- Use Core ML to adapt DealScore per user
- Learn route preferences, alliance bias, price tolerance
- Feedback loop: "Why did I get this alert?" → improves future alerts

**Rationale**: Enhances precision, but serverside baselines sufficient for MVP.

**Implementation Strategy**:
- **Phase 1 (MVP):** Rule-based DealScore only (weighted formula: discount %, route popularity, time-to-departure)
- **Phase 2 (3-6 months post-launch, 500+ users):** Collect real user interaction data (clicks, bookings, dismissals)
- **Phase 3:** Train custom Core ML model using CreateML or Python → Core ML converter
- **Training data:** Aggregated anonymized user interactions (not Apple Foundation Models, which are for general language/reasoning tasks)
- **Deployment:** Ship model updates via Firebase Remote Config

**Why deferred**: Need real user behavior data (ground truth) to train meaningful model. Synthetic/competitor data insufficient for personalization accuracy.

---

## NICE-TO-HAVE FEATURES (P2 — Future)

### P2-1: Post-Booking Compensation
- Monitor bookings for delays ≥ 3 hours or cancellations
- Email/push with AirHelp or Compensair affiliate link
- "Claims & Delays" tab (shows eligibility)

**Rationale**: Monetization upside (15-16% commission), but requires calendar/email access (privacy friction). Phase 2.

---

### P2-2: Hotels, Cars, Activities
- Expand to Trip.com (5% commission) for hotels
- Rental car aggregation via Booking.com or Duffel

**Rationale**: Phase 2 roadmap item (post flight validation).

---

### P2-3: Duffel Direct Bookings
- Book flights directly in-app (no redirect)
- Store receipt in app ("Wallet" feature)

**Rationale**: Requires Duffel enterprise tier ($$$), deferred to Phase 3.

---

## OUT OF SCOPE (MVP)

**Explicitly NOT building**:
- ❌ Social features (sharing deals, user reviews) — adds moderation burden
- ❌ Group booking tools — niche use case, low ROI
- ❌ In-app chat support — use email for MVP
- ❌ Multi-city or complex itineraries — defer to Phase 2
- ❌ Award seat search — Amadeus doesn't support, requires separate APIs
- ❌ Price prediction ("Will this go lower?") — too risky (liability if wrong)

---

## USER JOURNEYS

### Critical Path: New User → First Watchlist → First Alert
1. User downloads app (from App Store search or referral)
2. Opens app → sees onboarding (3 screens: "Find deals", "Get alerts", "Book transparent")
3. Skips sign-up (optional) → lands on Search screen
4. Searches "New York → London" for next month
5. Sees results sorted by price + DealScore badges
6. Taps "Watch this route" → creates watchlist (1/2 used)
7. Enables notifications (system prompt)
8. Closes app
9. **6 hours later**: Price drops 15% → receives alert "NYC → LON dropped to $420 (Exceptional Deal)"
10. Opens alert → sees deal detail with fare ladder + booking CTAs
11. Taps "Book on Delta" → opens Safari → completes booking
12. **Success**: User booked a flight they feel confident about

---

### Edge Cases

**New User (No History)**:
- DealScore uses market baselines (90-day avg for route)
- Onboarding explains "We'll learn your preferences over time"

**Returning User (2+ Watchlists)**:
- Personalization kicks in (prefers nonstop, European carriers)
- DealScore weighted toward user's historical behavior

**Power User (Pro Subscriber)**:
- Creates 10 watchlists for different date ranges
- Receives 6 instant alerts/day (immediate when deals found, watchlists count toward cap)
- Can enable watchlist-only mode (disables discovery alerts)
- Uses widgets to monitor watchlists

**Offline User**:
- Cached search results still visible (with "Last updated" timestamp)
- Watchlists sync when back online
- Alerts queued (delivered when connected)

**API Failure (Amadeus Down)**:
- App shows cached results with warning banner
- Fallback to WayAway/Aviasales search (if available)
- Error logged to Firebase (silent to user)

---

## TECHNICAL CONSTRAINTS

### Performance Requirements
- Cold start: < 2 seconds (iPhone SE 3rd gen)
- Search results: < 1.5 seconds p95 (TTFI)
- 60 fps scrolling (even with 50+ results)
- Battery drain: < 1% per hour of background monitoring

### Platform Requirements
- iOS 26.0+ (latest SwiftUI, Observation framework, advanced Live Activities)
- iPhone and iPad (universal app)
- Offline mode: cached results valid for 15 minutes
- Accessibility: VoiceOver, Dynamic Type, reduced motion

### API/Infrastructure Limits
- Amadeus: 2,000 calls/month free tier
- Caching strategy: 15-min cache per route/date pair
- Expected usage: ~100 users × 5 searches/user/week = 500 searches/week = ~2k/month
- Cloudflare Workers: Edge API proxy (free tier)
- Supabase: Postgres + Auth (free ≤ 500 MB)
- Firebase: Analytics + Remote Config (free tier)

### Security Requirements
- API provider secrets (Amadeus, Travelpayouts) stored server-side only
- User session tokens stored in Keychain (iOS device)
- TLS SPKI pinning for backend endpoints (dual-pin rotation strategy)
- No PII shared with third parties (anonymized device IDs only)
- Privacy Manifest required (App Store, includes Firebase disclosures)

---

## OPEN QUESTIONS (Need User/Stakeholder Input)

### Q1: Brand Identity (Product Decision)
Should FareLens feel:
- **A) Playful & Accessible**: Bright colors, friendly copy, animations (appeals to broader audience)
- **B) Premium & Sophisticated**: Muted tones, minimal UI, elegant (appeals to affluent travelers)

**Impact**: Sets tone for entire design system (colors, typography, voice).

**Recommendation**: User to decide based on target market positioning.

---

### Q2: Monetization Priority (Business Decision)
Which matters more in Year 1:
- **A) Affiliate Revenue**: Optimize for CTR (promote affiliate CTAs, A/B test placement)
- **B) Subscription Revenue**: Optimize for Pro conversion (limit free tier, aggressive paywall)

**Impact**: Affects feature gating (how restrictive is free tier?) and CTA prominence.

**Recommendation**: User to decide based on cash flow needs vs long-term growth strategy.

---

### Q3: Compensation Flow (Product + Privacy Decision)
To monitor bookings for delays, we need:
- Calendar access (to detect booked flights) OR
- Email access (to parse confirmation emails) OR
- Manual entry (user copies booking ref)

**Privacy vs UX tradeoff**:
- Calendar/Email = seamless UX, but raises privacy concerns (App Store reviewers scrutinize)
- Manual entry = privacy-friendly, but adds friction (users forget)

**Recommendation**: Start with manual entry for MVP; add passive monitoring in Phase 2 if users request it.

---

## RISKS & MITIGATION

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|-----------|
| Amadeus API quota exceeded | Medium | High | Implement aggressive caching (15 min); rate limit per-user searches (3/min); fallback to Aviasales API |
| Low alert open rate (< 60%) | Medium | High | A/B test alert copy; add rich notifications (preview deal); respect quiet hours strictly |
| Affiliate CTR < 10% | Medium | Medium | Always show lowest fare first (build trust); only show affiliate if within 7%; test CTA copy |
| App Store rejection (privacy) | Low | High | Submit Privacy Manifest early; no PII tracking; clear consent flows; legal review before submit |
| Competitors (Hopper, Google Flights) clone core features | High | Low | Differentiate on transparency (we show lowest fare, they prioritize partners); Apple-grade design |

---

## TIMELINE (Estimated)

**Week 1-2**: Design System (product-designer creates DESIGN.md)
**Week 3-4**: iOS Architecture (ios-architect creates ARCHITECTURE.md)
**Week 5-6**: Backend Architecture (backend-architect creates API.md)
**Week 7-10**: Core Implementation (P0-1 to P0-5)
**Week 11**: Polish (P0-6: Liquid Glass UI)
**Week 12**: Monetization (P0-7: StoreKit integration)
**Week 13**: Internal Beta (TestFlight, dogfooding)
**Week 14**: Bug Fixes + Performance Tuning
**Week 15**: External Beta (50-100 users)
**Week 16**: App Store Submission

**Target Launch**: 16 weeks from kickoff (~4 months)

---

## APPENDIX: DECISION & ASSUMPTION LOGS

### Decision Log (Preserved from v1.6)
**D1**: Provider stack: Amadeus Self-Service (primary) for live fares; Aviasales + WayAway (affiliate booking); Duffel reserved for Phase 3 direct bookings.
**D2**: Monetization: Affiliate deep links replace Amadeus booking URLs when eligible; Pro removes ads and unlocks instant alerts + advanced nudges.
**D3**: Display: Always show lowest verified fare (even non-affiliate). Two CTAs max: Book at $XXX (lowest) and Book via [AffiliateName] if within 7%. GlassSheet reveals all providers ≤ 10% of lowest fare.
**D4**: Transparency: No "Partner" labels; provider names only; global disclosure in Terms.
**D5**: Alerts: Both Free (3/day) and Pro (6/day) get immediate alerts when deals found (cap is only difference); smart queue formula: `finalScore = dealScore × (1 + watchlistBoost) × (1 + airportWeight)` with tiebreaker rules (price ASC, date ASC); preferred airports (Free: 1 weight=1.0, Pro: 3 weights sum to 1.0); customizable quiet hours (default 10pm–7am); snooze options; dedupe 12h; watchlist-only mode for Pro.
**D6**: Watchlists: Free 5; Pro unlimited (top 6/day alerted if cap reached). Background monitoring: Free 1x/day (9am), Pro 2x/day (9am+6pm).
**D7**: Personalization: Hybrid = server rules + on-device Foundation Models (embeddings, weighting, dedupe, explainability).
**D8**: Compensation flow: Post-booking monitoring → email/push if delay ≥ 3h or cancellation. Integrates AirHelp & Compensair affiliate links.
**D9**: Security: Keychain + Secure Enclave, TLS pinning, STRIDE-lite, least privilege.
**D10**: Roadmap: Phase 2 Hotels/Cars + MQD Estimator • Phase 3 Duffel • Phase 4 Luxury Agency Pack.

### Assumption Log
**A1**: Amadeus 2k calls/mo + cache suffices for MVP.
**A2**: Airline-direct ranked higher when price ≤ 2% or $10 delta.
**A3**: Exclude Basic Economy sticky per user; default = cheapest.
**A4**: MQD Estimator deferred → Phase 2.

### Search Preference Defaults (Sticky Behavior)

**Basic Economy Toggle:**
- **Default:** Show all fares including Basic Economy (cheapest first)
- **UI:** Visible pill toggle on search results: "Exclude Basic Economy"
- **Behavior:** If toggled ON, persist per user (saved in UserDefaults)
- **Copy:** "Basic Economy excluded. [Show all fares]" (dismissible banner)
- **Rationale:** Transparency first—show cheapest by default, let user opt out

**Prefer Airline Direct Toggle:**
- **Location:** Settings screen (not per-search, global preference)
- **Default:** OFF (show all providers sorted by total price)
- **Behavior:** If enabled and airline direct fare within threshold (≤2% or $10 delta):
  - Elevate airline direct in secondary CTA
  - Badge: "Direct from [Airline]" (small, 10pt)
- **Copy:** "When enabled, we'll suggest booking direct if the price is close (within $10 or 2%)"
- **Rationale:** User preference for loyalty/status, but not forced

**Example Search Result (Prefer Airline Direct = ON):**
```
Primary CTA: "Book on Aviasales for $420" (lowest fare)
Secondary CTA: "Book Direct from United for $425" (badge: "Earn miles")
Threshold: $425 is within 2% of $420 (eligible for elevation)
```

---

## TECHNICAL APPENDIX

### API Credentials (DO NOT COMMIT TO PUBLIC REPOS)

**Amadeus API**
- Key: `ZAYGjO0XPpzlTQgYkUpKex2J1CwXGPkt`
- Secret: `mAp8Le1dFpGpnGQL`
- Quota: 2,000 calls/month (Self-Service free tier)

**Travelpayouts (Affiliate Network)**
- Partner ID: `676763`
- API Token: `83f415b475c5b13b5c8b909120bca790`
- Default Sub-ID: `farelens-app`

**Approved Affiliate Links**:
- Compensair: `https://compensair.tpx.lt/PnPt6COy`
- AirHelp: `https://airhelp.tpx.lt/l0N4G1OD`
- WayAway: `https://wayaway.tpx.lt/glLihRmS`
- Aviasales: `https://aviasales.tpx.lt/En1Fn5Bz`

**Affiliate Deep-Link Template**:
```
https://tp.media/r?campaign_id=<ID>&marker=676763&sub_id=farelens-app&u=<encoded_URL>
```

**Sub-ID Schema**:
```
ios-fl-{dealId}-{wl}-{placement}-{ab}-{tier}
```
Example: `ios-fl-abc123-w1-detail-varA-pro`

---

### Affiliate Ecosystem (2025)

| Provider | Status | Category | Payout | Cookie | Notes |
|----------|--------|----------|--------|--------|-------|
| Amadeus | Approved | Data only | – | – | 2k calls/mo free tier anchor |
| Aviasales | Approved | Flights | 1.1–1.3% | 30d | API + affiliate live |
| WayAway | Approved | Flights | 1.1–1.3% | 30d | Fallback deep link |
| AirHelp | Approved | Compensation | 15–16.6% of fee | 45d | Post-delay emails |
| Compensair | Approved | Compensation | €5–€14/lead | 30d | Post-delay emails |
| Trip.com | Pending | Hotels/Cars | 5% avg | 30d | Phase 2 |
| Booking.com | Declined | Hotels/Cars | 4% | 1 session | Phase 2 resubmit |
| Omio / 12Go / Expedia / Traveloka / CheapOair / Kiwi.com | Pending/Declined | Various | ≤ 6% | varies | Reapply post-launch |

---

### Booking Logic Flow (Engineering Reference)

**Goal**: Show lowest verified fare → earn only when affiliate eligible → never sacrifice trust.

**Flow**:
1. Query Amadeus for live fares
2. Normalize & map providers (airline/OTA)
3. If affiliate (Aviasales/WayAway) has matching fare ≤ lowest × 1.07 → eligible for dual display
4. Else show lowest verified fare only
5. Render two CTAs max:
   - (1) Book at $XXX (lowest fare)
   - (2) Book via [AffiliateName] (if eligible)
6. Tap "Other offers" → GlassSheet (sorted by total cost, ≤ 10% delta)
7. Always rank by user total cost after tax/bag

**GlassSheet Tie-Break Ranking**:
1. Airline Direct
2. Top OTA (Expedia > Booking > Trip.com)
3. Affiliates (Aviasales > WayAway)
4. Others by reliability/UX

**Tie-breaker**: Identical price → `trust_score > affiliate_flag > latency`

**Hidden Providers**: Providers > 10% delta hidden behind "Show all providers (may include higher fares)"

---

### Infrastructure Stack (Free Tier MVP)

**Backend**:
- **Cloudflare Workers**: Edge API proxy ($0)
- **Supabase**: Postgres + Auth (free ≤ 500 MB)
- **Redis**: Upstash or Fly.io queue (free tier)
- **Firebase**: Analytics + Remote Config + A/B testing (free tier)

**Expected Usage**:
- ~1 GB database storage
- ~10k monthly active users
- All tiers $0 until subscription revenue

**Caching Strategy**:
- 15-min cache per route/date pair
- Background watchlist checks: 2x/day (9am, 6pm local)
- Rate limit: 3 searches/min per user

---

### Legal & Compliance

**Terms of Service**:
- FareLens aggregates public & affiliate flight data and redirects to providers
- Prices subject to change; always verify on provider site before booking

**Privacy Policy**:
- Minimal data collection (device ID, search history, watchlists)
- Some links may yield commission at no extra cost to user
- No PII shared with third parties (anonymized analytics only)

**Disclaimer**:
- FareLens not liable for airline changes or OTA fulfillment
- Bookings are handled by provider (airline or OTA)
- Flight protection/compensation services are third-party (AirHelp, Compensair)

**Compliance**:
- DOT (US Dept of Transportation): Price transparency, no hidden fees
- GDPR (EU): Right to access, delete, export data
- CCPA (California): Do Not Sell My Personal Information link
- App Store Privacy Nutrition Label: Updated before submission

---

## CHANGE LOG (Historical)

**v2.0** (2025-10-06): Complete PRD restructure by product-manager. Added clear P0/P1/P2 prioritization, user stories, acceptance criteria, success metrics, user journeys, edge cases, open questions, risks, timeline. Preserved all technical details (affiliate ecosystem, credentials, booking logic) in appendix.

**v1.6**: Added final affiliate ecosystem details (Aviasales, WayAway, AirHelp, Compensair). Clarified "show all providers" transparency policy and GlassSheet ranking. Revised labeling (no "Partner" labels; neutral provider names). Updated booking logic to always display the lowest verified fare even if non-affiliate. Added post-booking compensation notifications, credentials block, infra rationale, security hardening, and detailed affiliate table with payout/cookie details.

**v1.5**: Locked provider stack (Amadeus primary, Travelpayouts fallback, Duffel Phase 3). Embedded Amadeus keys. Defined Pro/Free alert caps. Added "Smarter via Partner," Transfer Bonus Collector, Card/Status onboarding, data model, infra, and privacy.

**Earlier**: Liquid Glass design system, Live Activities, Siri Shortcuts, fallback logic, baseline scoring, anomaly detection, privacy-first telemetry.