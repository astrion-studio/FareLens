# User Endpoints Design - Executive Summary

## Answers to Your Questions

### 1. Should we use PATCH or PUT for user updates?

**Answer: PATCH**

**Rationale:**
- iOS already uses PATCH (APIEndpoint.swift line 174)
- User updates are **partial** - iOS sends only changed fields
- PUT requires sending entire resource (all fields)
- PATCH is semantically correct for partial updates

**Example:**
```swift
// iOS sends only timezone update
{
  "timezone": "America/New_York"
}

// PATCH updates only timezone, preserves other fields
// PUT would require sending ALL user fields
```

---

### 2. How should weight validation work (must sum to 1.0)?

**Answer: Validate in Worker with 0.1% tolerance for floating point errors**

**Validation Logic:**
```typescript
const totalWeight = airports.reduce((sum, a) => sum + a.weight, 0);

if (Math.abs(totalWeight - 1.0) > 0.001) {
  return error("Airport weights must sum to 1.0 (current: {totalWeight})");
}
```

**Why 0.001 tolerance:**
- Floating point arithmetic: 0.6 + 0.3 + 0.1 may not exactly equal 1.0
- 0.001 = 0.1% error tolerance (reasonable for weights)
- Prevents false validation failures

**Example valid weights:**
```json
// Free tier (1 airport)
[{"iata": "LAX", "weight": 1.0}]

// Pro tier (3 airports)
[
  {"iata": "LAX", "weight": 0.6},
  {"iata": "JFK", "weight": 0.3},
  {"iata": "ORD", "weight": 0.1}
]
// Sum = 1.0 ✓

// Invalid
[
  {"iata": "LAX", "weight": 0.5},
  {"iata": "JFK", "weight": 0.3}
]
// Sum = 0.8 ✗ Returns 400 error
```

**Auto-normalization (optional future enhancement):**
```typescript
// If weights don't sum to 1.0, auto-normalize
const normalized = airports.map(a => ({
  ...a,
  weight: a.weight / totalWeight
}));
```

---

### 3. Should quiet_hours be nested or flattened in alert_preferences?

**Answer: Nested in API, flattened in database**

**iOS Format (Nested):**
```json
{
  "alert_preferences": {
    "enabled": true,
    "quiet_hours_enabled": true,
    "quiet_hours_start": 22,
    "quiet_hours_end": 7,
    "watchlist_only_mode": false
  }
}
```

**Supabase Schema (Flattened):**
```sql
alert_enabled BOOLEAN
quiet_hours_enabled BOOLEAN
quiet_hours_start INTEGER
quiet_hours_end INTEGER
watchlist_only_mode BOOLEAN
```

**Rationale:**
- **iOS:** Nested object matches Swift model (AlertPreferences struct)
- **Supabase:** Flat columns enable database constraints (CHECK quiet_hours_start < 24)
- **Worker:** Transforms between formats (cheap operation, happens once per request)

**Transformation Example:**
```typescript
// iOS → Supabase (flatten)
{
  "alert_preferences": {
    "quiet_hours_start": 22
  }
}
↓
{
  "quiet_hours_start": 22
}

// Supabase → iOS (nest)
{
  "quiet_hours_start": 22,
  "quiet_hours_end": 7
}
↓
{
  "alert_preferences": {
    "quiet_hours_start": 22,
    "quiet_hours_end": 7
  }
}
```

---

### 4. Tier limits: Free=1 airport, Pro=3 airports - enforce in Worker or RLS?

**Answer: Enforce in Worker (not RLS)**

**Validation in Worker (BEFORE hitting database):**
```typescript
const MAX_AIRPORTS = { free: 1, pro: 3 };

if (airports.length > MAX_AIRPORTS[user.subscription_tier]) {
  return {
    error: "free tier allows maximum 1 preferred airport(s)",
    upgrade_required: true
  };
}
```

**Why Worker, not RLS:**
1. **Business logic vs data integrity**
   - RLS enforces data access (who can read/write)
   - Tier limits are business rules (how many items allowed)

2. **Better error messages**
   - Worker: "free tier allows maximum 1 airport. Upgrade to Pro."
   - RLS: Generic "Permission denied" (unhelpful to user)

3. **Flexibility**
   - Change tier limits without database migration
   - Different limits per tier (free=1, pro=3, enterprise=10)

4. **Performance**
   - Fail fast in Worker (don't hit database if validation fails)
   - RLS would require database round-trip before rejection

**Supabase schema only enforces:**
```sql
-- Array type validation (data integrity)
CONSTRAINT users_preferred_airports_valid
  CHECK (jsonb_typeof(preferred_airports) = 'array')
```

**Worker enforces:**
- Tier limits (free=1, pro=3)
- Weight sum = 1.0
- No duplicate IATA codes
- Pro-only features (watchlist_only_mode)

---

### 5. Should we consolidate alert_preferences into the main user object (not a separate endpoint)?

**Answer: Yes, consolidate into `/user` endpoint**

**Current State (Broken):**
```
GET /alert-preferences → 404 (not implemented)
PUT /alert-preferences → Wrong schema
PUT /alert-preferences/airports → Expects strings, gets objects
PATCH /user → Ignores timezone
```

**New Design (Consolidated):**
```
GET /user → Returns user with alert_preferences + preferred_airports nested
PATCH /user → Updates any user field (timezone, alert_preferences, preferred_airports)
```

**Rationale:**

1. **iOS model structure**
   ```swift
   struct User {
     let id: UUID
     var timezone: String
     var alertPreferences: AlertPreferences  // Property of User
     var preferredAirports: [PreferredAirport]  // Property of User
   }
   ```
   Alert preferences are properties of User, not separate resources.

2. **Database structure**
   ```sql
   CREATE TABLE users (
     id UUID,
     timezone TEXT,
     alert_enabled BOOLEAN,  -- Part of users table
     preferred_airports JSONB  -- Part of users table
   );
   ```
   No separate `alert_preferences` table - fields are columns on `users`.

3. **Atomic updates**
   ```json
   // Single request updates multiple fields atomically
   PATCH /user {
     "timezone": "America/New_York",
     "alert_preferences": { "enabled": false },
     "preferred_airports": [{"iata": "JFK", "weight": 1.0}]
   }

   // vs 3 separate requests (what if one fails?)
   PATCH /user { "timezone": "..." }
   PUT /alert-preferences { "enabled": false }
   PUT /alert-preferences/airports { "preferred_airports": [...] }
   ```

4. **Simpler iOS code**
   ```swift
   // Before (3 network calls)
   await api.updateTimezone(timezone)
   await api.updateAlertPreferences(prefs)
   await api.updateAirports(airports)

   // After (1 network call)
   await api.updateUser(user)
   ```

5. **Backwards compatibility**
   Keep old endpoints for compatibility:
   ```
   GET /alert-preferences → Redirects to GET /user, extracts alert_preferences
   PUT /alert-preferences → Transforms to PATCH /user
   ```
   Add `X-Deprecated` header to signal iOS to migrate.

---

## REST Endpoint Design Summary

### Endpoint 1: GET /user

**Purpose:** Fetch complete user profile

**Request:**
```http
GET /user HTTP/1.1
Authorization: Bearer <jwt>
```

**Response (200 OK):**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "created_at": "2025-01-15T10:30:00Z",
    "timezone": "America/Los_Angeles",
    "subscription_tier": "pro",
    "alert_preferences": {
      "enabled": true,
      "quiet_hours_enabled": true,
      "quiet_hours_start": 22,
      "quiet_hours_end": 7,
      "watchlist_only_mode": false
    },
    "preferred_airports": [
      {"id": "uuid", "iata": "LAX", "weight": 0.6},
      {"id": "uuid", "iata": "JFK", "weight": 0.4}
    ]
  }
}
```

**Errors:**
- 401 Unauthorized - Invalid/missing JWT
- 404 Not Found - User deleted
- 500 Internal Server Error

---

### Endpoint 2: PATCH /user

**Purpose:** Update user profile (partial update)

**Request:**
```http
PATCH /user HTTP/1.1
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "timezone": "America/New_York",
  "alert_preferences": {
    "quiet_hours_enabled": false
  },
  "preferred_airports": [
    {"iata": "JFK", "weight": 1.0}
  ]
}
```

**Response (200 OK):**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "timezone": "America/New_York",
    "subscription_tier": "free",
    "alert_preferences": {
      "enabled": true,
      "quiet_hours_enabled": false,
      "quiet_hours_start": 22,
      "quiet_hours_end": 7,
      "watchlist_only_mode": false
    },
    "preferred_airports": [
      {"id": "generated-uuid", "iata": "JFK", "weight": 1.0}
    ]
  }
}
```

**Errors:**
- 400 Bad Request - Invalid data (timezone format, weight sum, etc.)
- 401 Unauthorized - Invalid/missing JWT
- 403 Forbidden - Tier limit exceeded (free user trying to add 3 airports)
- 500 Internal Server Error

**Specific Error Examples:**
```json
// Too many airports on Free tier
{
  "error": "free tier allows maximum 1 preferred airport(s)",
  "upgrade_required": true
}

// Weights don't sum to 1.0
{
  "error": "Airport weights must sum to 1.0 (current: 0.850)"
}

// Pro feature on Free tier
{
  "error": "Watchlist-only mode is a Pro feature. Upgrade to enable.",
  "upgrade_required": true
}

// Invalid IATA code
{
  "error": "Invalid IATA code: LAX1. Must be 3 uppercase letters."
}

// Duplicate airports
{
  "error": "Duplicate airport codes detected"
}
```

---

## Field Mappings

### iOS → Worker → Supabase

| iOS Request | Worker Validation | Supabase Column |
|-------------|-------------------|-----------------|
| `timezone` | IANA format regex | `timezone` |
| `alert_preferences.enabled` | None | `alert_enabled` |
| `alert_preferences.quiet_hours_enabled` | None | `quiet_hours_enabled` |
| `alert_preferences.quiet_hours_start` | 0-23 range | `quiet_hours_start` |
| `alert_preferences.quiet_hours_end` | 0-23 range | `quiet_hours_end` |
| `alert_preferences.watchlist_only_mode` | Pro tier check | `watchlist_only_mode` |
| `preferred_airports[].iata` | IATA regex, duplicates | `preferred_airports[].iata` (JSONB) |
| `preferred_airports[].weight` | 0-1 range, sum=1.0 | `preferred_airports[].weight` (JSONB) |
| `preferred_airports[].id` | Generate if missing | `preferred_airports[].id` (JSONB) |

### Supabase → Worker → iOS

| Supabase Column | Worker Transform | iOS Property |
|-----------------|------------------|--------------|
| `id` | Direct | `user.id` |
| `email` | Direct | `user.email` |
| `created_at` | Direct (ISO8601) | `user.createdAt` |
| `timezone` | Direct | `user.timezone` |
| `subscription_tier` | Direct | `user.subscriptionTier` |
| `alert_enabled` | Nest into object | `alertPreferences.enabled` |
| `quiet_hours_enabled` | Nest into object | `alertPreferences.quietHoursEnabled` |
| `quiet_hours_start` | Nest into object | `alertPreferences.quietHoursStart` |
| `quiet_hours_end` | Nest into object | `alertPreferences.quietHoursEnd` |
| `watchlist_only_mode` | Nest into object | `alertPreferences.watchlistOnlyMode` |
| `preferred_airports` (JSONB string) | Parse JSON | `preferredAirports` array |

---

## Validation Rules

### 1. Timezone
```typescript
// IANA format: America/Los_Angeles, Europe/London
const timezoneRegex = /^[A-Z][a-zA-Z_]+\/[A-Z][a-zA-Z_]+$/;
```

### 2. Quiet Hours
```typescript
// Hours must be 0-23
quiet_hours_start >= 0 && quiet_hours_start < 24
quiet_hours_end >= 0 && quiet_hours_end < 24

// Allowed: 22-7 (spans midnight)
// Allowed: 9-17 (normal range)
```

### 3. Preferred Airports

**Tier Limits:**
```typescript
const MAX_AIRPORTS = {
  free: 1,
  pro: 3
};
```

**IATA Code:**
```typescript
const iataRegex = /^[A-Z]{3}$/;
// Valid: LAX, JFK, ORD
// Invalid: lax, LAX1, LA
```

**Weight:**
```typescript
// Each weight: 0.0-1.0
airport.weight >= 0 && airport.weight <= 1.0

// Sum: 1.0 ± 0.001
Math.abs(totalWeight - 1.0) <= 0.001
```

**No Duplicates:**
```typescript
// Cannot have same airport twice
new Set(airports.map(a => a.iata)).size === airports.length
```

### 4. Pro Features
```typescript
// watchlist_only_mode requires Pro tier
if (watchlist_only_mode === true && tier === 'free') {
  return error("Pro feature");
}
```

---

## Implementation Pattern

### PostgREST Passthrough

**Worker acts as transformation layer:**
```
iOS (nested)
    ↓
Worker (validate + flatten)
    ↓
Supabase PostgREST (flat columns)
    ↓
Worker (nest + transform)
    ↓
iOS (nested)
```

**Why not direct PostgREST:**
- iOS needs nested format (User.alertPreferences.enabled)
- Supabase has flat columns (users.alert_enabled)
- Worker transforms between formats
- Worker validates business rules (tier limits, weights)

**Benefits:**
- Single source of truth (Supabase schema)
- iOS gets clean API (nested, typed)
- Worker enforces business logic
- Database enforces data integrity

---

## Zod Schemas

### Request Validation
```typescript
const UserUpdateRequestSchema = z.object({
  timezone: z.string()
    .regex(/^[A-Z][a-zA-Z_]+\/[A-Z][a-zA-Z_]+$/)
    .optional(),
  alert_preferences: z.object({
    enabled: z.boolean().optional(),
    quiet_hours_enabled: z.boolean().optional(),
    quiet_hours_start: z.number().int().min(0).max(23).optional(),
    quiet_hours_end: z.number().int().min(0).max(23).optional(),
    watchlist_only_mode: z.boolean().optional(),
  }).strict().optional(),
  preferred_airports: z.array(
    z.object({
      id: z.string().uuid().optional(),
      iata: z.string().regex(/^[A-Z]{3}$/),
      weight: z.number().min(0).max(1.0),
    })
  ).max(3).optional(),
}).strict();
```

### Response Validation
```typescript
const SupabaseUserRowSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  created_at: z.string(),
  timezone: z.string(),
  subscription_tier: z.enum(['free', 'pro']),
  alert_enabled: z.boolean(),
  quiet_hours_enabled: z.boolean(),
  quiet_hours_start: z.number().int().min(0).max(23),
  quiet_hours_end: z.number().int().min(0).max(23),
  watchlist_only_mode: z.boolean(),
  preferred_airports: z.string(), // JSONB as string
});
```

---

## Integration Steps

### Step 1: Update Worker (cloudflare-workers/src/index.ts)

**Replace `handleUser()` function:**
```typescript
// Copy entire handleUser() from USER_ENDPOINTS_IMPLEMENTATION.ts
// Replace lines 978-1075 in src/index.ts
```

**Update routing:**
```typescript
// Line 94-96: Replace with
if (path === '/api/user' || path === '/user') {
  return await handleUser(request, env);
}
```

**Add backwards compatibility:**
```typescript
// After line 96, add
if (path === '/api/alert-preferences' || path === '/alert-preferences') {
  if (request.method === 'GET') {
    return await handleGetAlertPreferences(request, env);
  } else if (request.method === 'PUT') {
    return await handlePutAlertPreferences(request, env);
  }
}

if (path === '/api/alert-preferences/airports' || path === '/alert-preferences/airports') {
  if (request.method === 'PUT') {
    return await handlePutPreferredAirports(request, env);
  }
}
```

**Remove old implementations:**
```typescript
// Delete lines 785-876 (old handleAlertPreferences)
// Delete lines 882-972 (old handlePreferredAirports)
```

### Step 2: Test Worker Locally

```bash
cd cloudflare-workers
npm run dev

# Test GET /user
curl -H "Authorization: Bearer <test-jwt>" http://localhost:8787/user

# Test PATCH /user
curl -X PATCH \
  -H "Authorization: Bearer <test-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"timezone":"America/New_York"}' \
  http://localhost:8787/user
```

### Step 3: Update iOS (Optional - iOS already correct)

**Current iOS code already uses correct endpoints:**
```swift
// APIEndpoint.swift line 171
static func updateUser(_ user: User) -> APIEndpoint {
  APIEndpoint(
    path: "/user",
    method: .patch,  // ✓ Correct
    body: [
      "timezone": user.timezone,
    ]
  )
}
```

**No changes needed - iOS already expects:**
- GET /user (add this endpoint to fetch user)
- PATCH /user (already exists)

### Step 4: Deploy Worker

```bash
cd cloudflare-workers
npm run deploy
```

### Step 5: Verify End-to-End

1. iOS → GET /user → Verify nested response
2. iOS → PATCH /user (timezone) → Verify update
3. iOS → PATCH /user (alert_preferences) → Verify flattening
4. iOS → PATCH /user (preferred_airports) → Verify weight validation

---

## Testing Checklist

### Worker Unit Tests
- [ ] `transformSupabaseUserToAPI()` - Flat → Nested
- [ ] `transformAPIUserToSupabase()` - Nested → Flat
- [ ] `validateTierLimits()` - Free=1, Pro=3
- [ ] `validateAirportWeights()` - Sum=1.0, tolerance=0.001
- [ ] `validateNoDuplicateAirports()` - No duplicate IATA codes

### Worker Integration Tests
- [ ] GET /user - Returns correctly transformed user
- [ ] PATCH /user (timezone) - Updates timezone
- [ ] PATCH /user (alert_preferences) - Flattens and updates
- [ ] PATCH /user (preferred_airports) - Generates UUIDs, validates weights
- [ ] PATCH /user (Free + 2 airports) - Returns 403 forbidden
- [ ] PATCH /user (Free + watchlist_only_mode) - Returns 403 forbidden
- [ ] PATCH /user (weight sum 0.8) - Returns 400 bad request
- [ ] PATCH /user (duplicate IATA) - Returns 400 bad request

### iOS Integration Tests
- [ ] Fetch user → Decode into User model
- [ ] Update timezone → Verify persisted
- [ ] Update alert preferences → Verify nested decode
- [ ] Update preferred airports → Verify weight validation

---

## Files Delivered

1. **WORKER_USER_ENDPOINTS.md** (19KB)
   - Complete endpoint specification
   - Field mappings
   - Validation rules
   - Transformation logic
   - Architecture decisions
   - Testing strategy

2. **USER_ENDPOINTS_IMPLEMENTATION.ts** (19KB)
   - Complete TypeScript implementation
   - Zod schemas
   - Transformation functions
   - Validation functions
   - GET /user handler
   - PATCH /user handler
   - Backwards compatibility handlers
   - Full JSDoc comments

3. **USER_ENDPOINTS_SUMMARY.md** (This file)
   - Answers to all 5 questions
   - Quick reference
   - Integration steps
   - Testing checklist

---

## Next Steps

1. **Review** this design document
2. **Copy** implementation from `USER_ENDPOINTS_IMPLEMENTATION.ts` into `cloudflare-workers/src/index.ts`
3. **Test** locally with `npm run dev`
4. **Deploy** with `npm run deploy`
5. **Verify** iOS integration end-to-end

All schema mismatches are now resolved with a clean, validated implementation.
