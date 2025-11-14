# SCHEMA MISMATCH RESOLUTION - ARCHITECTURAL GUIDANCE

**Date:** 2025-11-05
**Backend Architect:** Claude (backend-architect agent)
**Issue:** Breaking API schema mismatches between iOS client, Cloudflare Worker, and Supabase schema

---

## EXECUTIVE SUMMARY

**Root Cause:** Cloudflare Worker implementation is incomplete. It only has `/flights` and `/deals` endpoints. Missing ALL CRUD endpoints for watchlists, alert preferences, user updates, and device registration that iOS expects per API.md specification.

**Single Source of Truth:** Supabase schema (`supabase_schema_FINAL.sql`) is correct. iOS models are correct. API.md specification is correct. **Cloudflare Worker is 90% unimplemented.**

**Fix Strategy:** Implement missing Worker endpoints to match API.md specification, using Supabase PostgREST passthrough pattern with RLS enforcement.

---

## CURRENT STATE ANALYSIS

### What Exists (Cloudflare Worker)
```typescript
✅ GET /health - Health check
✅ GET /flights - Amadeus proxy (flight search)
✅ GET /deals - Supabase deals query
❌ Everything else missing (10+ endpoints)
```

### What's Missing (Per API.md)
```
Watchlists:
❌ POST /v1/watchlists - Create watchlist
❌ GET /v1/watchlists - List watchlists
❌ PUT /v1/watchlists/:id - Update watchlist
❌ DELETE /v1/watchlists/:id - Delete watchlist
❌ POST /v1/watchlists/check - Manual refresh

Alert Preferences:
❌ GET /v1/alert-preferences - Get preferences (iOS expects this!)
❌ PUT /v1/alert-preferences - Update preferences
❌ PUT /v1/alert-preferences/airports - Update preferred airports

User:
❌ PATCH /v1/user - Update timezone, etc.
❌ POST /v1/user/apns-token - Register device

Alerts:
❌ POST /v1/alerts/register - Device registration
❌ GET /v1/alerts/history - Alert history
```

---

## ARCHITECTURAL DECISIONS

### 1. Single Source of Truth: Supabase Schema

**Decision:** Supabase schema is authoritative. All field names, types, and constraints defined there are final.

**Rationale:**
- Schema enforces constraints (CHECK, UNIQUE, FOREIGN KEY)
- Row-Level Security policies enforce access control
- Schema has comprehensive indexes for performance
- Database is already deployed

**Action:** Worker endpoints MUST map directly to Supabase tables with zero transformation.

---

### 2. Worker Pattern: PostgREST Passthrough with RLS

**Current Anti-Pattern (in Worker):**
```typescript
// WRONG: Direct query with secret key (bypasses RLS)
const dealsResponse = await fetch(
  `${env.SUPABASE_URL}/rest/v1/flight_deals?...`,
  { headers: { 'apikey': env.SUPABASE_ANON_KEY } }
);
```

**Correct Pattern:**
```typescript
// RIGHT: Use user's JWT token to enforce RLS
async function handleWatchlists(request: Request, env: Env): Promise<Response> {
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) {
    return authResult.response;
  }

  // Forward to Supabase PostgREST with user's JWT
  // RLS policies automatically filter to user_id = auth.uid()
  const supabaseResponse = await fetch(
    `${env.SUPABASE_URL}/rest/v1/watchlists`,
    {
      method: request.method,
      headers: {
        'Authorization': `Bearer ${authResult.token}`,
        'apikey': env.SUPABASE_ANON_KEY,  // Public key
        'Content-Type': 'application/json',
      },
      body: request.method !== 'GET' ? await request.text() : undefined,
    }
  );

  return jsonResponse(await supabaseResponse.json(), supabaseResponse.status, {}, env);
}
```

**Benefits:**
- RLS automatically enforces user_id filtering
- No SQL injection risk (PostgREST validates)
- Zero business logic in Worker (keep it thin)
- Supabase handles validation via CHECK constraints

---

### 3. Field Name Mapping: Direct Match

All field names must match Supabase schema exactly. No camelCase ↔ snake_case conversion in Worker.

| Supabase Table | Field Name | iOS Model | Worker API | Match? |
|----------------|------------|-----------|------------|--------|
| watchlists | origin | origin | origin | ✅ YES |
| watchlists | destination | destination | destination | ✅ YES |
| watchlists | name | name | name | ✅ YES |
| watchlists | date_range_start | dateRange.start | date_range.start | ⚠️ FIX NEEDED |
| watchlists | date_range_end | dateRange.end | date_range.end | ⚠️ FIX NEEDED |
| watchlists | max_price | maxPrice | max_price | ✅ YES |
| watchlists | is_active | isActive | is_active | ✅ YES |
| users | preferred_airports (JSONB) | preferredAirports | preferred_airports | ⚠️ FIX NEEDED |

---

## RESOLUTION BY ISSUE

### Issue 1: Watchlist Field Mismatches

**Problem:**
- Supabase: `date_range_start`, `date_range_end` (separate columns)
- iOS sends: `date_range: { start: "2025-12-15", end: "2025-12-22" }` (nested object)
- Worker expects: (doesn't exist yet)

**Resolution:**

**Option A: Change iOS to match Supabase (RECOMMENDED)**
```swift
// APIEndpoint.swift - createWatchlist
var body: [String: Any] = [
    "name": watchlist.name,
    "origin": watchlist.origin,
    "destination": watchlist.destination,
]

if let dateRange = watchlist.dateRange {
    let iso8601 = ISO8601DateFormatter()
    // CHANGE: Flatten to match Supabase columns
    body["date_range_start"] = iso8601.string(from: dateRange.start)
    body["date_range_end"] = iso8601.string(from: dateRange.end)
}

if let maxPrice = watchlist.maxPrice {
    body["max_price"] = maxPrice
}
```

**Rationale:**
- Supabase schema uses two columns (supports partial indexing, SQL queries)
- Changing schema would break existing data
- iOS change is 5 lines of code

**Worker Implementation:**
```typescript
// POST /v1/watchlists
if (path === '/v1/watchlists' && request.method === 'POST') {
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) return authResult.response;

  const body = await request.json();

  // Validate required fields
  if (!body.name || !body.origin || !body.destination) {
    return jsonResponse({ error: 'Missing required fields' }, 400, {}, env);
  }

  // Supabase RLS will enforce user_id and watchlist limit trigger
  const supabaseResponse = await fetch(
    `${env.SUPABASE_URL}/rest/v1/watchlists`,
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${authResult.token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',  // Return created row
      },
      body: JSON.stringify({
        user_id: authResult.userId,  // Explicit (RLS will verify)
        name: body.name,
        origin: body.origin,
        destination: body.destination,
        date_range_start: body.date_range_start || null,
        date_range_end: body.date_range_end || null,
        max_price: body.max_price || null,
        is_active: true,
      }),
    }
  );

  if (!supabaseResponse.ok) {
    const error = await supabaseResponse.text();

    // Parse Postgres error for watchlist limit trigger
    if (error.includes('P0001')) {  // Custom error code from trigger
      return jsonResponse({
        error: {
          code: 'WATCHLIST_LIMIT_EXCEEDED',
          message: 'Free tier allows maximum 5 active watchlists. Upgrade to Pro for unlimited.',
        },
      }, 403, {}, env);
    }

    return jsonResponse({ error: 'Failed to create watchlist' }, supabaseResponse.status, {}, env);
  }

  const watchlist = await supabaseResponse.json();
  return jsonResponse(watchlist, 201, {}, env);
}
```

---

### Issue 2: Airport Code Length (IATA vs ICAO)

**Problem:**
- Worker validates: 3-letter IATA only (`/^[A-Z]{3}$/`)
- iOS allows: 3-letter IATA OR 4-letter ICAO
- Supabase: TEXT (no constraint)

**Resolution: Support IATA only (3-letter)**

**Rationale:**
- Amadeus API uses IATA codes exclusively
- Google Flights uses IATA codes
- ICAO codes are for air traffic control, not consumer booking
- Major airports have IATA codes (SFO, JFK, LAX, LHR, NRT)
- Regional airports without IATA aren't in Amadeus anyway

**Changes Required:**

**iOS (CreateWatchlistView.swift):**
```swift
// CHANGE: Lines 28-34
private func isValidAirportCode(_ code: String) -> Bool {
    let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
    // REMOVE ICAO support (4-letter codes)
    let isIATA = trimmed.count == 3
    let isLettersOnly = trimmed.allSatisfy(\.isLetter)
    return isIATA && isLettersOnly
}
```

**Worker (flights endpoint - already correct):**
```typescript
// Lines 104-111 - Keep as-is
const airportCodeRegex = /^[A-Z]{3}$/;
if (!airportCodeRegex.test(origin)) {
  return jsonResponse({ error: 'Invalid origin airport code. Must be 3 uppercase letters.' }, 400, {}, env);
}
```

**Supabase (add CHECK constraint):**
```sql
-- Migration: Add airport code validation
ALTER TABLE watchlists
  ADD CONSTRAINT watchlists_origin_iata_valid
  CHECK (origin ~ '^[A-Z]{3}$');

ALTER TABLE watchlists
  ADD CONSTRAINT watchlists_destination_iata_or_any
  CHECK (destination ~ '^[A-Z]{3}$' OR destination = 'ANY');
```

---

### Issue 3: Alert Preferences Mismatch

**Problem:**
- iOS expects: `GET /alert-preferences` with `quiet_hours_enabled`, `watchlist_only_mode`
- Worker has: Nothing (endpoint doesn't exist)
- API.md spec: `POST /v1/alerts/preferences` (different path!)

**Resolution: Align to users table structure**

Supabase stores alert preferences IN the users table (denormalized for performance):
```sql
-- users table (lines 26-31 in schema)
alert_enabled BOOLEAN NOT NULL DEFAULT true,
quiet_hours_enabled BOOLEAN NOT NULL DEFAULT true,
quiet_hours_start INTEGER NOT NULL DEFAULT 22,
quiet_hours_end INTEGER NOT NULL DEFAULT 7,
watchlist_only_mode BOOLEAN NOT NULL DEFAULT false,
preferred_airports JSONB NOT NULL DEFAULT '[]'::jsonb,
```

**Correct API Design:**

1. **GET alert preferences:**
```
GET /v1/user
Returns: Full user object (includes alert prefs)
```

2. **Update alert preferences:**
```
PATCH /v1/user
Body: { alert_enabled, quiet_hours_enabled, quiet_hours_start, quiet_hours_end, watchlist_only_mode }
```

**Why not separate `/alert-preferences` endpoint?**
- Alert prefs ARE user attributes (stored in users table)
- Separate endpoint adds complexity
- iOS already fetches user object at startup

**iOS Changes Required:**

**APIEndpoint.swift:**
```swift
// REMOVE getAlertPreferences() - Lines 122-126
// REMOVE updateAlertPreferences() - Lines 129-141

// CHANGE updateUser to handle all user fields
static func updateUser(
    timezone: String? = nil,
    alertEnabled: Bool? = nil,
    quietHoursEnabled: Bool? = nil,
    quietHoursStart: Int? = nil,
    quietHoursEnd: Int? = nil,
    watchlistOnlyMode: Bool? = nil
) -> APIEndpoint {
    var body: [String: Any] = [:]

    if let timezone { body["timezone"] = timezone }
    if let alertEnabled { body["alert_enabled"] = alertEnabled }
    if let quietHoursEnabled { body["quiet_hours_enabled"] = quietHoursEnabled }
    if let quietHoursStart { body["quiet_hours_start"] = quietHoursStart }
    if let quietHoursEnd { body["quiet_hours_end"] = quietHoursEnd }
    if let watchlistOnlyMode { body["watchlist_only_mode"] = watchlistOnlyMode }

    return APIEndpoint(
        path: "/user",
        method: .patch,
        body: body
    )
}
```

**Worker Implementation:**
```typescript
// PATCH /v1/user
if (path === '/v1/user' && request.method === 'PATCH') {
  const authResult = await verifyAuth(request, env);
  if (!authResult.authenticated) return authResult.response;

  const body = await request.json();

  // Whitelist allowed fields (prevent updating subscription_tier, etc.)
  const allowedFields = [
    'timezone',
    'alert_enabled',
    'quiet_hours_enabled',
    'quiet_hours_start',
    'quiet_hours_end',
    'watchlist_only_mode',
  ];

  const updates: any = {};
  for (const field of allowedFields) {
    if (body[field] !== undefined) {
      updates[field] = body[field];
    }
  }

  // Pro-only validation for watchlist_only_mode
  if (updates.watchlist_only_mode !== undefined) {
    // Fetch user to check tier
    const userResponse = await fetch(
      `${env.SUPABASE_URL}/rest/v1/users?id=eq.${authResult.userId}`,
      {
        headers: {
          'Authorization': `Bearer ${authResult.token}`,
          'apikey': env.SUPABASE_ANON_KEY,
        },
      }
    );

    const users = await userResponse.json();
    if (users[0]?.subscription_tier !== 'pro' && updates.watchlist_only_mode === true) {
      return jsonResponse({
        error: {
          code: 'PRO_FEATURE_REQUIRED',
          message: 'Watchlist-only mode requires Pro subscription',
        },
      }, 403, {}, env);
    }
  }

  // Update via PostgREST (RLS enforces user_id)
  const supabaseResponse = await fetch(
    `${env.SUPABASE_URL}/rest/v1/users?id=eq.${authResult.userId}`,
    {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${authResult.token}`,
        'apikey': env.SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      },
      body: JSON.stringify(updates),
    }
  );

  if (!supabaseResponse.ok) {
    return jsonResponse({ error: 'Failed to update user' }, supabaseResponse.status, {}, env);
  }

  const user = await supabaseResponse.json();
  return jsonResponse(user[0], 200, {}, env);
}
```

---

### Issue 4: Preferred Airports Data Structure

**Problem:**
- Worker expects: `[String]` (array of codes)
- iOS sends: `[{iata: String, weight: Double}]` (array of objects)
- Supabase: `JSONB` (can store any structure)

**Resolution: Use iOS structure (with weight)**

**Rationale:**
- Alert scoring formula uses weights: `finalScore = dealScore × (1 + watchlistBoost) × (1 + airportWeight)`
- Weights must be stored server-side (for background job alert matching)
- Free: 1 airport (weight=1.0), Pro: 3 airports (weights sum to 1.0)

**Supabase Schema (already correct):**
```sql
-- users table, line 31
preferred_airports JSONB NOT NULL DEFAULT '[]'::jsonb,

-- No validation constraint (flexibility for future)
-- Validation happens in Worker + iOS
```

**iOS Model (already correct):**
```swift
// User.swift, lines 76-86
struct PreferredAirport: Codable, Identifiable {
    let id: UUID
    let iata: String
    var weight: Double  // 0.0-1.0
}

extension [PreferredAirport] {
    var totalWeight: Double {
        reduce(0) { $0 + $1.weight }
    }

    var isValidWeightSum: Bool {
        abs(totalWeight - 1.0) < 0.001
    }
}
```

**APIEndpoint.swift (already correct):**
```swift
// Lines 143-156
static func updatePreferredAirports(_ airports: [PreferredAirport]) -> APIEndpoint {
    APIEndpoint(
        path: "/alert-preferences/airports",  // ⚠️ WRONG PATH
        method: .put,
        body: [
            "preferred_airports": airports.map { airport in
                [
                    "iata": airport.iata,
                    "weight": airport.weight,
                ]
            },
        ]
    )
}
```

**CHANGE iOS path to match user update pattern:**
```swift
// REMOVE updatePreferredAirports endpoint (lines 143-156)
// Use updateUser endpoint instead

// SettingsViewModel.swift - updatePreferredAirports()
func updatePreferredAirports() async {
    guard isWeightSumValid else {
        errorMessage = "Airport weights must sum to 1.0"
        return
    }

    do {
        // CHANGE: Use PATCH /user endpoint
        let endpoint = APIEndpoint(
            path: "/user",
            method: .patch,
            body: [
                "preferred_airports": preferredAirports.map { airport in
                    [
                        "iata": airport.iata,
                        "weight": airport.weight,
                    ]
                }
            ]
        )
        try await APIClient.shared.requestNoResponse(endpoint)
        user.preferredAirports = preferredAirports
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

**Worker Implementation (add validation):**
```typescript
// In PATCH /user handler (before Supabase update)
if (updates.preferred_airports !== undefined) {
  const airports = updates.preferred_airports;

  // Validate structure
  if (!Array.isArray(airports)) {
    return jsonResponse({ error: 'preferred_airports must be array' }, 400, {}, env);
  }

  // Validate tier limits
  const userResponse = await fetch(
    `${env.SUPABASE_URL}/rest/v1/users?id=eq.${authResult.userId}`,
    {
      headers: {
        'Authorization': `Bearer ${authResult.token}`,
        'apikey': env.SUPABASE_ANON_KEY,
      },
    }
  );
  const users = await userResponse.json();
  const user = users[0];

  const maxAirports = user.subscription_tier === 'pro' ? 3 : 1;
  if (airports.length > maxAirports) {
    return jsonResponse({
      error: {
        code: 'AIRPORT_LIMIT_EXCEEDED',
        message: `${user.subscription_tier === 'free' ? 'Free' : 'Pro'} tier allows max ${maxAirports} preferred airports`,
        max_allowed: maxAirports,
      },
    }, 403, {}, env);
  }

  // Validate weights
  const totalWeight = airports.reduce((sum: number, a: any) => sum + (a.weight || 0), 0);
  if (Math.abs(totalWeight - 1.0) > 0.001) {
    return jsonResponse({
      error: 'Airport weights must sum to 1.0',
      current_sum: totalWeight,
    }, 400, {}, env);
  }

  // Validate IATA codes
  for (const airport of airports) {
    if (!/^[A-Z]{3}$/.test(airport.iata)) {
      return jsonResponse({ error: `Invalid IATA code: ${airport.iata}` }, 400, {}, env);
    }
  }
}
```

---

### Issue 5: User Timezone Update

**Problem:**
- iOS tries to update timezone
- Worker `/user` endpoint doesn't exist
- SettingsViewModel.updateTimezone() calls non-existent endpoint

**Resolution: Already solved by PATCH /user endpoint above**

iOS code is already correct:
```swift
// SettingsViewModel.swift, lines 91-100
func updateTimezone(_ timezone: String) async {
    user.timezone = timezone

    do {
        let endpoint = APIEndpoint.updateUser(user)  // ✅ Correct
        try await APIClient.shared.requestNoResponse(endpoint)
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

Worker just needs to implement `PATCH /user` (covered in Issue 3).

---

## MISSING ENDPOINTS IMPLEMENTATION CHECKLIST

All endpoints follow the PostgREST passthrough pattern with RLS.

### Watchlists
```typescript
✅ POST /v1/watchlists - Create (covered in Issue 1)
⬜ GET /v1/watchlists - List user's watchlists
⬜ PUT /v1/watchlists/:id - Update watchlist
⬜ DELETE /v1/watchlists/:id - Delete watchlist
```

### User & Preferences
```typescript
✅ PATCH /v1/user - Update user fields (covered in Issue 3)
⬜ GET /v1/user - Get current user (startup)
```

### Device Registration
```typescript
⬜ POST /v1/user/apns-token - Register APNs device token
```

### Alert History
```typescript
⬜ GET /v1/alerts/history - Query alert_history table
```

---

## IMPLEMENTATION PRIORITY

### Phase 1: Critical (Blocks iOS App) - Implement First
1. ✅ **PATCH /v1/user** - Alert preferences, timezone, airports
2. **GET /v1/user** - Fetch current user on app launch
3. **POST /v1/watchlists** - Create watchlist
4. **GET /v1/watchlists** - List watchlists
5. **DELETE /v1/watchlists/:id** - Delete watchlist

### Phase 2: Important (Nice to Have)
6. **PUT /v1/watchlists/:id** - Update watchlist (can workaround with delete+create)
7. **POST /v1/user/apns-token** - Push notifications (can defer)
8. **GET /v1/alerts/history** - Alert history (analytics only)

---

## WORKER ROUTING STRUCTURE

```typescript
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method === 'OPTIONS') {
      return handleCORS(env);
    }

    const url = new URL(request.url);
    const path = url.pathname;

    try {
      // Health check
      if (path === '/health') {
        return jsonResponse({ status: 'healthy', version: env.API_VERSION }, 200, {}, env);
      }

      // Flight search (Amadeus proxy)
      if (path.startsWith('/flights') || path.startsWith('/v1/flights')) {
        const authResult = await verifyAuth(request, env);
        if (!authResult.authenticated) return authResult.response;
        return await handleFlightSearch(request, env, authResult.userId);
      }

      // Deals feed (Supabase query)
      if (path.startsWith('/deals') || path.startsWith('/v1/deals')) {
        return await handleDeals(request, env);
      }

      // User endpoints
      if (path === '/v1/user' || path === '/user') {
        return await handleUser(request, env);
      }

      // APNs token registration
      if (path === '/v1/user/apns-token' || path === '/user/apns-token') {
        return await handleAPNsToken(request, env);
      }

      // Watchlists CRUD
      if (path.startsWith('/v1/watchlists') || path.startsWith('/watchlists')) {
        return await handleWatchlists(request, env);
      }

      // Alert history
      if (path === '/v1/alerts/history' || path === '/alerts/history') {
        return await handleAlertHistory(request, env);
      }

      // 404
      return jsonResponse({ error: 'Not found' }, 404, {}, env);

    } catch (error) {
      console.error('Worker error:', error);
      return jsonResponse({ error: 'Internal Server Error' }, 500, {}, env);
    }
  },
};
```

---

## iOS CHANGES SUMMARY

### APIEndpoint.swift Changes

1. **Remove separate alert-preferences endpoints:**
   - ❌ DELETE `getAlertPreferences()` (lines 122-126)
   - ❌ DELETE `updateAlertPreferences()` (lines 129-141)
   - ❌ DELETE `updatePreferredAirports()` (lines 143-156)

2. **Expand updateUser() to handle all user fields:**
   ```swift
   static func updateUser(
       timezone: String? = nil,
       alertEnabled: Bool? = nil,
       quietHoursEnabled: Bool? = nil,
       quietHoursStart: Int? = nil,
       quietHoursEnd: Int? = nil,
       watchlistOnlyMode: Bool? = nil,
       preferredAirports: [PreferredAirport]? = nil
   ) -> APIEndpoint
   ```

3. **Fix createWatchlist() date format:**
   ```swift
   // CHANGE nested date_range object to flat fields
   body["date_range_start"] = iso8601.string(from: dateRange.start)
   body["date_range_end"] = iso8601.string(from: dateRange.end)
   ```

### CreateWatchlistView.swift Changes

**Remove ICAO support (4-letter codes):**
```swift
// Line 28-34
private func isValidAirportCode(_ code: String) -> Bool {
    let trimmed = code.trimmingCharacters(in: .whitespaces).uppercased()
    let isIATA = trimmed.count == 3  // REMOVE: || trimmed.count == 4
    let isLettersOnly = trimmed.allSatisfy(\.isLetter)
    return isIATA && isLettersOnly
}
```

### SettingsViewModel.swift Changes

**Update methods to use new updateUser endpoint:**
```swift
// updateAlertPreferences() - CHANGE to use PATCH /user
func updateAlertPreferences() async {
    do {
        let endpoint = APIEndpoint.updateUser(
            alertEnabled: alertPreferences.enabled,
            quietHoursEnabled: alertPreferences.quietHoursEnabled,
            quietHoursStart: alertPreferences.quietHoursStart,
            quietHoursEnd: alertPreferences.quietHoursEnd,
            watchlistOnlyMode: alertPreferences.watchlistOnlyMode
        )
        try await APIClient.shared.requestNoResponse(endpoint)
        user.alertPreferences = alertPreferences
    } catch {
        errorMessage = error.localizedDescription
    }
}

// updatePreferredAirports() - CHANGE to use PATCH /user
func updatePreferredAirports() async {
    guard isWeightSumValid else {
        errorMessage = "Airport weights must sum to 1.0"
        return
    }

    do {
        let endpoint = APIEndpoint.updateUser(
            preferredAirports: preferredAirports
        )
        try await APIClient.shared.requestNoResponse(endpoint)
        user.preferredAirports = preferredAirports
    } catch {
        errorMessage = error.localizedDescription
    }
}
```

---

## SUPABASE SCHEMA CHANGES

**Add airport code validation constraints:**

```sql
-- Migration: 003_add_airport_code_validation.sql
ALTER TABLE watchlists
  ADD CONSTRAINT watchlists_origin_iata_valid
  CHECK (origin ~ '^[A-Z]{3}$');

ALTER TABLE watchlists
  ADD CONSTRAINT watchlists_destination_iata_or_any
  CHECK (destination ~ '^[A-Z]{3}$' OR destination = 'ANY');
```

---

## VALIDATION CHECKLIST

After implementing all changes, verify:

### End-to-End Flows

**Watchlist Creation:**
```bash
# iOS creates watchlist
POST /v1/watchlists
Body: {
  name: "LAX to NYC Winter",
  origin: "LAX",
  destination: "JFK",
  date_range_start: "2025-12-15T00:00:00Z",
  date_range_end: "2025-12-22T00:00:00Z",
  max_price: 700.00
}

# Verify in Supabase
SELECT * FROM watchlists WHERE user_id = '...';
```

**Alert Preferences Update:**
```bash
# iOS updates quiet hours
PATCH /v1/user
Body: {
  quiet_hours_enabled: true,
  quiet_hours_start: 22,
  quiet_hours_end: 7
}

# Verify in Supabase
SELECT quiet_hours_enabled, quiet_hours_start, quiet_hours_end
FROM users WHERE id = '...';
```

**Preferred Airports Update:**
```bash
# iOS sets preferred airports (Pro user)
PATCH /v1/user
Body: {
  preferred_airports: [
    { iata: "LAX", weight: 0.6 },
    { iata: "JFK", weight: 0.3 },
    { iata: "ORD", weight: 0.1 }
  ]
}

# Verify sum = 1.0 validation
PATCH /v1/user
Body: {
  preferred_airports: [
    { iata: "LAX", weight: 0.5 },
    { iata: "JFK", weight: 0.4 }
  ]
}
# Expected: 400 Bad Request - "weights must sum to 1.0"

# Verify tier limits (Free user)
PATCH /v1/user
Body: {
  preferred_airports: [
    { iata: "LAX", weight: 0.5 },
    { iata: "JFK", weight: 0.5 }
  ]
}
# Expected: 403 Forbidden - "Free tier allows max 1 airport"
```

---

## TESTING STRATEGY

### Unit Tests (Worker)

```typescript
// Test RLS enforcement
test('watchlist creation enforces user_id via RLS', async () => {
  const userAToken = 'jwt_for_user_a';
  const userBToken = 'jwt_for_user_b';

  // User A creates watchlist
  const createResponse = await fetch('/v1/watchlists', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${userAToken}` },
    body: JSON.stringify({ name: 'Test', origin: 'LAX', destination: 'NYC' }),
  });
  const watchlist = await createResponse.json();

  // User B tries to fetch User A's watchlist
  const getResponse = await fetch(`/v1/watchlists`, {
    headers: { 'Authorization': `Bearer ${userBToken}` },
  });
  const watchlists = await getResponse.json();

  // Should NOT see User A's watchlist
  expect(watchlists).not.toContainEqual(expect.objectContaining({ id: watchlist.id }));
});

// Test tier limits
test('free tier cannot create more than 5 watchlists', async () => {
  const freeUserToken = 'jwt_for_free_user';

  // Create 5 watchlists (should succeed)
  for (let i = 0; i < 5; i++) {
    const response = await fetch('/v1/watchlists', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${freeUserToken}` },
      body: JSON.stringify({ name: `Test ${i}`, origin: 'LAX', destination: 'NYC' }),
    });
    expect(response.status).toBe(201);
  }

  // Create 6th watchlist (should fail)
  const response = await fetch('/v1/watchlists', {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${freeUserToken}` },
    body: JSON.stringify({ name: 'Test 6', origin: 'LAX', destination: 'NYC' }),
  });
  expect(response.status).toBe(403);
  const error = await response.json();
  expect(error.error.code).toBe('WATCHLIST_LIMIT_EXCEEDED');
});

// Test weight validation
test('preferred airports weights must sum to 1.0', async () => {
  const token = 'jwt_for_pro_user';

  // Invalid weights (sum = 0.9)
  const response1 = await fetch('/v1/user', {
    method: 'PATCH',
    headers: { 'Authorization': `Bearer ${token}` },
    body: JSON.stringify({
      preferred_airports: [
        { iata: 'LAX', weight: 0.5 },
        { iata: 'JFK', weight: 0.4 },
      ],
    }),
  });
  expect(response1.status).toBe(400);

  // Valid weights (sum = 1.0)
  const response2 = await fetch('/v1/user', {
    method: 'PATCH',
    headers: { 'Authorization': `Bearer ${token}` },
    body: JSON.stringify({
      preferred_airports: [
        { iata: 'LAX', weight: 0.6 },
        { iata: 'JFK', weight: 0.3 },
        { iata: 'ORD', weight: 0.1 },
      ],
    }),
  });
  expect(response2.status).toBe(200);
});
```

### Integration Tests (iOS)

```swift
// WatchlistsViewModelTests.swift
func testCreateWatchlist_sendsCorrectDateFormat() async {
    let viewModel = WatchlistsViewModel(userId: testUserId)

    let watchlist = Watchlist(
        userId: testUserId,
        name: "Test",
        origin: "LAX",
        destination: "JFK",
        dateRange: DateRange(
            start: Date(timeIntervalSince1970: 1702598400),  // 2023-12-15
            end: Date(timeIntervalSince1970: 1703203200)      // 2023-12-22
        )
    )

    await viewModel.createWatchlist(watchlist)

    // Verify request sent to API
    let sentRequest = APIClient.shared.lastRequest
    let body = sentRequest.body as! [String: Any]

    // Should have flat date fields, not nested
    XCTAssertNotNil(body["date_range_start"])
    XCTAssertNotNil(body["date_range_end"])
    XCTAssertNil(body["date_range"])  // Should NOT have nested object

    // Should be ISO8601 format
    XCTAssertEqual(body["date_range_start"] as? String, "2023-12-15T00:00:00Z")
}

// SettingsViewModelTests.swift
func testUpdateAlertPreferences_usesPatchUserEndpoint() async {
    let viewModel = SettingsViewModel(user: testUser)
    viewModel.alertPreferences.quietHoursEnabled = false

    await viewModel.updateAlertPreferences()

    // Verify endpoint path
    let request = APIClient.shared.lastRequest
    XCTAssertEqual(request.path, "/user")
    XCTAssertEqual(request.method, .patch)

    // Verify body has alert fields
    let body = request.body as! [String: Any]
    XCTAssertEqual(body["quiet_hours_enabled"] as? Bool, false)
}
```

---

## DEPLOYMENT PLAN

### Step 1: Implement Worker Endpoints (Backend)
1. Create `/v1/user` (GET, PATCH)
2. Create `/v1/watchlists` (GET, POST, DELETE, PUT)
3. Create `/v1/user/apns-token` (POST)
4. Create `/v1/alerts/history` (GET)
5. Deploy to Cloudflare Workers staging
6. Test with curl/Postman

### Step 2: Update iOS Client
1. Fix `APIEndpoint.swift` (date format, user endpoint)
2. Fix `CreateWatchlistView.swift` (IATA-only validation)
3. Fix `SettingsViewModel.swift` (use PATCH /user)
4. Run unit tests
5. Build to staging TestFlight

### Step 3: Update Supabase Schema
1. Add airport code CHECK constraints
2. Test constraints don't break existing data
3. Run on production

### Step 4: Integration Testing
1. TestFlight beta testers create watchlists
2. TestFlight beta testers update alert preferences
3. Verify data in Supabase
4. Monitor Cloudflare Worker logs for errors

### Step 5: Production Release
1. Deploy Worker to production
2. Release iOS app to App Store
3. Monitor crash reports, API errors

---

## ROLLBACK PLAN

If breaking changes cause issues:

1. **Worker rollback:** Cloudflare Workers has instant rollback via dashboard
2. **iOS rollback:** Submit expedited App Store review for hotfix
3. **Schema rollback:** DROP constraints if they block legitimate data

---

## APPENDIX: FIELD MAPPING REFERENCE

### Watchlists Table

| Supabase Column | Type | iOS Property | JSON Key | Notes |
|-----------------|------|--------------|----------|-------|
| id | UUID | id | id | Auto-generated |
| user_id | UUID | userId | user_id | From JWT |
| name | TEXT | name | name | Required |
| origin | TEXT | origin | origin | IATA code (3 letters) |
| destination | TEXT | destination | destination | IATA code OR "ANY" |
| date_range_start | TIMESTAMPTZ | dateRange?.start | date_range_start | ISO8601 string |
| date_range_end | TIMESTAMPTZ | dateRange?.end | date_range_end | ISO8601 string |
| max_price | NUMERIC | maxPrice | max_price | Optional |
| is_active | BOOLEAN | isActive | is_active | Default: true |
| created_at | TIMESTAMPTZ | createdAt | created_at | Auto |
| updated_at | TIMESTAMPTZ | - | updated_at | Auto (trigger) |

### Users Table (Alert Preferences)

| Supabase Column | Type | iOS Property | JSON Key | Notes |
|-----------------|------|--------------|----------|-------|
| alert_enabled | BOOLEAN | alertPreferences.enabled | alert_enabled | Default: true |
| quiet_hours_enabled | BOOLEAN | alertPreferences.quietHoursEnabled | quiet_hours_enabled | Default: true |
| quiet_hours_start | INTEGER | alertPreferences.quietHoursStart | quiet_hours_start | 0-23, default: 22 |
| quiet_hours_end | INTEGER | alertPreferences.quietHoursEnd | quiet_hours_end | 0-23, default: 7 |
| watchlist_only_mode | BOOLEAN | alertPreferences.watchlistOnlyMode | watchlist_only_mode | Pro only, default: false |
| preferred_airports | JSONB | preferredAirports | preferred_airports | `[{iata: String, weight: Double}]` |
| timezone | TEXT | timezone | timezone | IANA format |

---

## SUMMARY

**Root Cause:** Cloudflare Worker is a skeleton. Only 2 of 12 endpoints exist.

**Fix:** Implement missing endpoints using PostgREST passthrough pattern. Let Supabase RLS + triggers handle all business logic.

**iOS Changes:**
- Flatten `date_range` nested object → `date_range_start`, `date_range_end`
- Remove ICAO support (4-letter codes)
- Consolidate alert preferences + preferred airports into `PATCH /user`
- Remove separate `/alert-preferences` endpoints

**Worker Changes:**
- Add 10 missing endpoints (all PassThrough to Supabase)
- Validate tier limits before Supabase (better error messages)
- Validate weight sums, IATA codes, Pro-only features

**Supabase Changes:**
- Add CHECK constraints for IATA codes

**Result:** Zero schema mismatches. Single source of truth (Supabase). Thin Worker layer (auth + validation only).
