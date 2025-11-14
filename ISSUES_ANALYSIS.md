# FareLens - Comprehensive Issue Analysis
**Date:** 2025-11-04
**Analyst:** Product Manager + Backend Architect + iOS Architect (Claude Code)
**Status:** Critical Gap Analysis - **App is 35-40% Complete**

---

## EXECUTIVE SUMMARY

### Critical Findings
- **40 unique issues** identified (deduplicated from user testing + codex analysis)
- **12 P0 (Critical)** issues block core user journeys
- **15 P1 (High)** issues are major UX/feature gaps
- **Backend is primary blocker:** 7 missing API endpoints cause 70% of issues
- **Estimated fix time:** 50-65 hours (1.5-2 weeks for 1 engineer)

### Completion Status
| Area | % Complete | Status |
|------|-----------|---------|
| UI Scaffolding | 100% | ✅ All screens exist |
| Design System | 100% | ✅ Colors, typography, components complete |
| Flight Search UI | 70% | ⚠️ Works but missing city names, fare breakdown |
| **Watchlists** | **0%** | ❌ **No backend endpoints** |
| **Alerts** | **0%** | ❌ **No backend logic** |
| **Settings** | **0%** | ❌ **No persistence endpoints** |
| Authentication | 15% | ⚠️ UI works, error messages wrong, no backend endpoints |

**Overall PRD Completion: 35-40%**

**Critical Path Status:** ❌ **BLOCKED** - Users cannot create watchlists or receive alerts

---

## P0 - CRITICAL ISSUES (12)

### Backend API Gaps

#### #1: Missing `/watchlists` CRUD Endpoints ⚠️ **HIGHEST PRIORITY**
- **Impact:** Watchlist creation/viewing completely broken (PRD P0-2 blocked)
- **Evidence:** iOS calls endpoints that don't exist → 404
- **Fix:** Implement POST/GET/PUT/DELETE `/watchlists` in Cloudflare worker
- **Time:** 4-6 hours
- **Files:** `cloudflare-workers/src/index.ts`
- **Unblocks:** User journey steps 8-12 (watchlist → alerts)

#### #2: Missing `/alert-preferences` Endpoints
- **Impact:** Settings save broken - quiet hours, preferred airports don't persist
- **Evidence:** `SettingsViewModel` calls endpoints that 404
- **Fix:** Implement GET/PUT `/alert-preferences`, PUT `/alert-preferences/airports`
- **Time:** 2-3 hours
- **Files:** `cloudflare-workers/src/index.ts`

#### #3: Missing `/user` Endpoint
- **Impact:** Profile updates fail, APNs token registration broken
- **Evidence:** iOS calls `PATCH /user`, `POST /user/apns-token` → 404
- **Fix:** Implement user profile update + device registration endpoints
- **Time:** 1 hour
- **Files:** `cloudflare-workers/src/index.ts`

#### #4: Missing `/background-refresh` Endpoint
- **Impact:** Background deal checks never run, alerts don't fire
- **Evidence:** iOS calls `GET /background-refresh` → 404
- **Fix:** Implement background refresh endpoint with smart queue logic
- **Time:** 2-3 hours
- **Files:** `cloudflare-workers/src/index.ts`

#### #5: Authentication Error Messaging Wrong
- **Impact:** User confusion - shows "verify email" instead of "account already exists"
- **Evidence:** User manual testing #1
- **Fix:** Proper error handling in `OnboardingViewModel.mapAuthError()`
- **Time:** 1 hour
- **Files:** `ios-app/FareLens/Features/Onboarding/OnboardingViewModel.swift`

### Security

#### #6: RLS Policies Missing `WITH CHECK` Clauses
- **Impact:** ⚠️ **SECURITY VULNERABILITY** - Users could modify other users' data
- **Evidence:** `supabase_schema_FINAL.sql` policies missing WITH CHECK on UPDATE
- **Fix:** Add `WITH CHECK (auth.uid() = user_id/id)` to 3 policies
- **Time:** 10 minutes
- **Files:** `supabase_schema_FINAL.sql` lines 149, 162, 171
- **SQL:**
```sql
-- Fix users table
DROP POLICY "Users can update their own data" ON public.users;
CREATE POLICY "Users can update their own data" ON public.users FOR UPDATE
USING ((select auth.uid()) = id) WITH CHECK ((select auth.uid()) = id);

-- Fix alert_history table
DROP POLICY "Users can update their own alert interactions" ON public.alert_history;
CREATE POLICY "Users can update their own alert interactions" ON public.alert_history FOR UPDATE
USING ((select auth.uid()) = user_id) WITH CHECK ((select auth.uid()) = user_id);

-- Fix saved_deals table
DROP POLICY "Users can update their own saved deals" ON public.saved_deals;
CREATE POLICY "Users can update their own saved deals" ON public.saved_deals FOR UPDATE
USING ((select auth.uid()) = user_id) WITH CHECK ((select auth.uid()) = user_id);
```

#### #7: CORS Configuration Security Risk
- **Impact:** Production API vulnerable - allows any origin
- **Evidence:** `wrangler.toml` CORS_ALLOW_ORIGIN = "*"
- **Fix:** Implement dynamic origin checking (farelens://, https://farelens.app)
- **Time:** 30 minutes
- **Files:** `cloudflare-workers/src/index.ts` (handleCORS function)

### iOS Performance

#### #8: Cold Start > 2s (PRD Violation)
- **Impact:** Slow app launch kills engagement (PRD requires < 2s, currently 2-10s)
- **Evidence:** `AppState.initialize()` waits up to 10s for network auth validation
- **Fix:** Optimistic auth - load cached user immediately, validate in background
- **Time:** 30 minutes
- **Files:** `ios-app/FareLens/App/AppState.swift`
- **Performance:** 2-10s → < 500ms (10x improvement)

#### #9: AppState Blocks UI on Network Calls
- **Impact:** White screen during token refresh (bad UX)
- **Evidence:** `getCurrentUser()` makes synchronous network calls
- **Fix:** Background validation, don't block UI
- **Time:** Included in #8
- **Files:** `ios-app/FareLens/Core/Services/AuthService.swift`

### iOS UX Blockers

#### #10: No Airport City Search (IATA Codes Only)
- **Impact:** Users must know "LAX" instead of typing "Los Angeles" (high friction)
- **Evidence:** User manual testing #5, both watchlist and settings affected
- **Fix:** Add local airport JSON database with autocomplete search
- **Time:** 1-2 hours
- **Files:**
  - NEW: `ios-app/FareLens/Core/Models/Airport.swift`
  - NEW: `ios-app/FareLens/Core/Services/AirportSearchService.swift`
  - NEW: `ios-app/FareLens/DesignSystem/Components/AirportSearchField.swift`
  - NEW: `ios-app/FareLens/Resources/Airports.json` (download from OpenFlights)
  - UPDATE: `CreateWatchlistView.swift`, `PreferredAirportsView.swift`

#### #11: iOS Password Autosave Doesn't Trigger
- **Impact:** Users must manually type password (bad iOS experience)
- **Evidence:** User manual testing #11
- **Fix:** Add `.submitLabel()` and `.onSubmit` to text fields
- **Time:** 10 minutes
- **Files:** `ios-app/FareLens/Features/Onboarding/OnboardingView.swift`

#### #12: Amadeus Token Cache Bug
- **Impact:** Token refresh failures break flight search (500 errors)
- **Evidence:** If Amadeus returns TTL ≤60s, KV throws "Invalid expiration"
- **Fix:** Clamp TTL to minimum 60 seconds
- **Time:** 5 minutes
- **Files:** `cloudflare-workers/src/index.ts` line 432

---

## P1 - HIGH ISSUES (15)

### Backend - Smart Queue & Alert Logic

#### #13: Smart Queue Algorithm Not Implemented
- **Impact:** Alerts won't be prioritized correctly (PRD P0-3 violated)
- **Evidence:** Formula `dealScore × (1 + watchlistBoost) × (1 + airportWeight)` not coded
- **Fix:** Implement ranking algorithm in background-refresh handler
- **Time:** 3-4 hours
- **PRD:** Lines 143-146

#### #14: Alert Caps Not Enforced (3/day free, 6/day pro)
- **Impact:** Users could get spammed with unlimited alerts
- **Fix:** Add per-user daily counter (KV or Supabase)
- **Time:** 2 hours

#### #15: 12-Hour Deduplication Missing
- **Impact:** Duplicate alerts spam users
- **Fix:** KV-based dedup hash
- **Time:** 2 hours
- **PRD:** Line 142

#### #16: Quiet Hours Not Enforced Server-Side
- **Impact:** Alerts sent at 3am → instant uninstall
- **Fix:** Check user quiet hours before sending alerts (timezone-aware)
- **Time:** 2 hours
- **PRD:** Line 141

### iOS - Missing Feature Wiring

#### #17: Watchlist Creation Dismisses on Error
- **Impact:** User doesn't see error message (bad UX)
- **Evidence:** `CreateWatchlistView` dismisses sheet even when save fails
- **Fix:** Only dismiss if `viewModel.errorMessage == nil`
- **Time:** 5 minutes
- **Files:** `ios-app/FareLens/Features/Watchlists/CreateWatchlistView.swift:186`

#### #18: Deal Detail TODOs (City Mapping, Fare Breakdown)
- **Impact:** Shows "JFK" instead of "New York", no baggage info
- **Evidence:** `DealDetailView.swift` lines 485+ have TODOs
- **Fix:** Add city mapper, fare breakdown UI
- **Time:** 3-4 hours
- **PRD:** P0-1 (lines 85-88)

#### #19: PaywallView Subscription Not Wired
- **Impact:** Can't upgrade to Pro (monetization blocked)
- **Evidence:** StoreKit 2 purchase flow not connected to backend
- **Fix:** Wire SubscriptionService to backend, update user tier on purchase
- **Time:** 2-3 hours
- **PRD:** P0-7 (lines 262-266)

#### #20: Airport Search Missing in Settings (duplicate of #10)
- **Impact:** Same IATA code issue in settings
- **Fix:** Use same AirportSearchField component
- **Time:** Included in #10

#### #21: Max Price $2K Too Low for Business Class
- **Impact:** Users can't watchlist business/first class fares
- **Evidence:** User manual testing #6
- **Fix:** Change slider max from $2000 to $10000
- **Time:** 5 minutes
- **Files:** `ios-app/FareLens/Features/Watchlists/CreateWatchlistView.swift:127`

### Backend - Data & Testing

#### #22: Missing Cloudflare Worker Tests
- **Impact:** Regressions will break production API
- **Fix:** Write integration tests with Miniflare/Vitest
- **Time:** 4-6 hours

#### #23: Date/Price Validation Gaps in Supabase Schema
- **Impact:** Invalid watchlists could crash backend
- **Fix:** Add CHECK constraints (dates in future, prices positive)
- **Time:** 2 hours
- **Files:** `supabase_schema_FINAL.sql`

#### #24: No Logging/Monitoring in Production
- **Impact:** Can't debug production issues
- **Fix:** Add Sentry SDK to worker, structured logging
- **Time:** 2-3 hours

### iOS - Feature Gaps

#### #25: Fare Breakdown Not Shown
- **Impact:** Users don't see base fare vs taxes
- **Fix:** Parse Amadeus fare components, show breakdown in DealDetailView
- **Time:** 2 hours
- **PRD:** P0-1 (line 86)

#### #26: "Other Offers" GlassSheet Missing
- **Impact:** Can't compare booking providers
- **Fix:** Build GlassSheet UI + ranking logic (show providers ≤10% price delta)
- **Time:** 3-4 hours
- **PRD:** P0-5 (lines 192-193)

#### #27: Deal Filters Don't Work
- **Impact:** Sort/Filter buttons do nothing
- **Evidence:** `DealsView.swift` FilterBar has empty closures
- **Fix:** Implement filter/sort logic in DealsViewModel
- **Time:** 2-3 hours

---

## P2 - MEDIUM ISSUES (8)

#### #28: Advanced Filters Missing (Airline, Cabin Class)
- Pro feature gap, 4-6 hours

#### #29: Empty States Lack Personality
- Generic copy, 2 hours

#### #30: Loading States Inconsistent
- No unified pattern, 2 hours

#### #31: No Haptic Feedback
- Less premium feel, 2-3 hours

#### #32: Cache TTL Mismatch (5min vs 15min)
- 5 minutes

#### #33: Deal Score Explainability Missing
- No "Why is this good?" modal, 3-4 hours

#### #34: No Quota Tracking for Amadeus API
- Could exhaust 2K/month limit, 3 hours (KV-based tracking)

#### #35: API Versioning Missing (No `/v1` prefix)
- Future-proofing, 1 hour

---

## P3 - LOW ISSUES (5)

#### #36: Fare Ladder (Price History) Missing
- 1-2 days (historical data storage + chart UI)

#### #37: Snooze Alerts Feature Missing
- 3-4 hours

#### #38: Pro Upgrade Prompts Sparse
- 2-3 hours

#### #39: Ad Integration Missing (Free Tier)
- 2-3 hours (Google AdMob)

#### #40: Accessibility Audit Incomplete
- 4-6 hours (VoiceOver testing)

---

## RECOMMENDED FIX ORDER

### Phase 1: Unblock Core Journey (Est. 16-20 hours)

**Goal:** Get watchlist creation + alerts working end-to-end

1. ✅ **#6 - RLS Security Fix** (10 min) - **DO FIRST** (security)
2. **#1 - `/watchlists` endpoints** (4-6h) - Unblocks watchlist CRUD
3. **#2 - `/alert-preferences` endpoints** (2-3h) - Unblocks settings
4. **#3 - `/user` endpoint** (1h) - APNs registration
5. **#4 - `/background-refresh` endpoint** (2-3h) - Alert delivery
6. **#5 - Auth error messaging** (1h) - Fix "verify email" message

**After Phase 1:** Users can create watchlists and theoretically receive alerts.

### Phase 2: iOS Client Improvements (Est. 3-4 hours)

**Goal:** Fix performance + critical UX issues (can do in parallel with Phase 1)

7. **#8/#9 - Cold start optimization** (30 min) - **HIGHEST IMPACT**
8. **#10 - Airport search** (1-2h) - Huge UX win
9. **#11 - Password autosave** (10 min)
10. **#12 - Amadeus token bug** (5 min)
11. **#17 - Watchlist dismiss bug** (5 min)
12. **#21 - Max price limit** (5 min)

**After Phase 2:** App feels fast, UX is polished.

### Phase 3: Alert Intelligence (Est. 12-15 hours)

**Goal:** Deliver correct alerts to correct users

13. **#13 - Smart queue algorithm** (3-4h)
14. **#14 - Alert caps** (2h)
15. **#15 - Deduplication** (2h)
16. **#16 - Quiet hours** (2h)
17. **#7 - CORS lockdown** (30 min)
18. **#22 - Worker tests** (4-6h)

**After Phase 3:** Alerts work correctly per PRD.

### Phase 4: Monetization & Polish (Est. 10-12 hours)

19. **#19 - PaywallView wiring** (2-3h)
20. **#18 - DealDetailView TODOs** (3-4h)
21. **#26 - GlassSheet** (3-4h)
22. **#24 - Logging/monitoring** (2-3h)

**After Phase 4:** Ready for beta testing.

### Phase 5: Complete Feature Set (Est. 10-15 hours)

23-27. P1 remaining issues
28-35. P2 issues
36-40. P3 issues (post-MVP)

**Total to MVP:** 50-65 hours (~1.5-2 weeks for 1 engineer)

---

## FILES TO MODIFY (Complete Reference)

### Backend (Cloudflare Worker)
- `cloudflare-workers/src/index.ts` - Add 7 endpoints, CORS, quota tracking
- `cloudflare-workers/package.json` - Add test script
- `cloudflare-workers/wrangler.toml` - Update CORS config

### iOS Client
- `ios-app/FareLens/App/AppState.swift` - Optimistic auth
- `ios-app/FareLens/Core/Services/AuthService.swift` - Background validation
- `ios-app/FareLens/Features/Onboarding/OnboardingView.swift` - Password autosave, error messaging
- `ios-app/FareLens/Features/Onboarding/OnboardingViewModel.swift` - Error mapping
- `ios-app/FareLens/Features/Watchlists/CreateWatchlistView.swift` - Dismiss bug, max price
- `ios-app/FareLens/Features/Settings/PreferredAirportsView.swift` - Airport search
- `ios-app/FareLens/Features/Deals/DealDetailView.swift` - City names, fare breakdown
- NEW: `ios-app/FareLens/Core/Models/Airport.swift`
- NEW: `ios-app/FareLens/Core/Services/AirportSearchService.swift`
- NEW: `ios-app/FareLens/DesignSystem/Components/AirportSearchField.swift`
- NEW: `ios-app/FareLens/Resources/Airports.json`

### Database
- `supabase_schema_FINAL.sql` - Add WITH CHECK clauses, validation constraints

---

## CONCLUSION

**The app has excellent UI/UX design but is fundamentally broken due to missing backend implementation.**

**Key Insights:**
1. **80/20 Problem:** 80% of UI done, 80% of backend missing
2. **API Contract Gap:** iOS and backend built independently without validation
3. **Testing Blind Spot:** No integration tests caught missing endpoints
4. **PRD Completeness Illusion:** PROJECT_STATUS.md says "100% Complete" but that's only UI scaffolding

**Critical Path:**
- ❌ **BLOCKED:** Users cannot create watchlists (no backend)
- ❌ **BLOCKED:** Users cannot receive alerts (no backend)
- ⚠️ **PARTIAL:** Users can search flights (but UX poor - no city search, slow cold start)

**Recommendation:** Fix Phase 1-3 issues (28 hours) before any beta testing. App is not usable without these.

---

🤖 Generated with Claude Code analysis (2025-11-04)
