# Worker API User Endpoints Design

## Architecture Decision: Consolidated User Endpoint

**Rationale:**
- iOS models show `AlertPreferences` and `PreferredAirport` as properties of `User`
- Supabase stores these as columns on `users` table (not separate tables)
- Single `/user` endpoint reduces round-trips (1 request vs 3)
- Simpler state management in iOS (single source of truth)

**Pattern:** PostgREST passthrough with Worker-side validation and transformation

---

## Endpoint 1: GET /user

**Purpose:** Fetch current user profile with all settings

### Request
```http
GET /user HTTP/1.1
Authorization: Bearer <jwt_token>
```

### Response (200 OK)
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
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
      {
        "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
        "iata": "LAX",
        "weight": 0.6
      },
      {
        "id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
        "iata": "JFK",
        "weight": 0.3
      },
      {
        "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",
        "iata": "ORD",
        "weight": 0.1
      }
    ]
  }
}
```

### Field Mapping: Supabase → iOS

| Supabase Column | iOS Property | Transformation |
|----------------|--------------|----------------|
| `id` | `user.id` | Direct |
| `email` | `user.email` | Direct |
| `created_at` | `user.createdAt` | ISO8601 → Date |
| `timezone` | `user.timezone` | Direct |
| `subscription_tier` | `user.subscriptionTier` | String → Enum |
| `alert_enabled` | `alertPreferences.enabled` | Nest into object |
| `quiet_hours_enabled` | `alertPreferences.quietHoursEnabled` | Nest into object |
| `quiet_hours_start` | `alertPreferences.quietHoursStart` | Nest into object |
| `quiet_hours_end` | `alertPreferences.quietHoursEnd` | Nest into object |
| `watchlist_only_mode` | `alertPreferences.watchlistOnlyMode` | Nest into object |
| `preferred_airports` (JSONB) | `preferredAirports` | Parse JSONB array |

### Transformation Logic

**Supabase stores:**
```json
{
  "preferred_airports": [
    {"id": "uuid", "iata": "LAX", "weight": 0.6},
    {"id": "uuid", "iata": "JFK", "weight": 0.3}
  ]
}
```

**Worker returns:**
```json
{
  "preferred_airports": [
    {"id": "uuid", "iata": "LAX", "weight": 0.6},
    {"id": "uuid", "iata": "JFK", "weight": 0.3}
  ]
}
```
(Same structure - direct passthrough after JSONB parse)

### Error Responses

```json
// 401 Unauthorized
{
  "error": "Unauthorized"
}

// 404 Not Found (user deleted)
{
  "error": "User not found"
}

// 500 Internal Server Error
{
  "error": "Failed to fetch user data"
}
```

---

## Endpoint 2: PATCH /user

**Purpose:** Update user profile (timezone, alert preferences, preferred airports)

**Design Decision:** Use PATCH (not PUT) for partial updates - iOS only sends changed fields

### Request
```http
PATCH /user HTTP/1.1
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
  "timezone": "America/New_York",
  "alert_preferences": {
    "enabled": true,
    "quiet_hours_enabled": false,
    "watchlist_only_mode": true
  },
  "preferred_airports": [
    {
      "iata": "JFK",
      "weight": 0.7
    },
    {
      "iata": "BOS",
      "weight": 0.3
    }
  ]
}
```

### Field Mapping: iOS → Supabase

| iOS Request Field | Supabase Column | Transformation |
|-------------------|-----------------|----------------|
| `timezone` | `timezone` | Direct (validate IANA format) |
| `alert_preferences.enabled` | `alert_enabled` | Flatten from object |
| `alert_preferences.quiet_hours_enabled` | `quiet_hours_enabled` | Flatten from object |
| `alert_preferences.quiet_hours_start` | `quiet_hours_start` | Flatten from object |
| `alert_preferences.quiet_hours_end` | `quiet_hours_end` | Flatten from object |
| `alert_preferences.watchlist_only_mode` | `watchlist_only_mode` | Flatten from object |
| `preferred_airports` | `preferred_airports` | Generate IDs, validate, store as JSONB |

### Validation Rules

#### 1. Timezone Validation
```typescript
// Validate IANA timezone format (e.g., "America/Los_Angeles")
const timezoneRegex = /^[A-Z][a-zA-Z_]+\/[A-Z][a-zA-Z_]+$/;
if (timezone && !timezoneRegex.test(timezone)) {
  return error("Invalid timezone format. Use IANA format (e.g., America/Los_Angeles)");
}
```

#### 2. Quiet Hours Validation
```typescript
if (quiet_hours_start !== undefined) {
  if (quiet_hours_start < 0 || quiet_hours_start >= 24) {
    return error("quiet_hours_start must be 0-23");
  }
}

if (quiet_hours_end !== undefined) {
  if (quiet_hours_end < 0 || quiet_hours_end >= 24) {
    return error("quiet_hours_end must be 0-23");
  }
}
```

#### 3. Watchlist-Only Mode Validation
```typescript
if (watchlist_only_mode === true) {
  // Fetch user tier from database
  if (user.subscription_tier === 'free') {
    return error("Watchlist-only mode is a Pro feature. Upgrade to enable.");
  }
}
```

#### 4. Preferred Airports Validation

**Tier Limits:**
```typescript
const MAX_AIRPORTS = {
  free: 1,
  pro: 3
};

if (preferred_airports.length > MAX_AIRPORTS[user.subscription_tier]) {
  return error(
    `${user.subscription_tier} tier allows maximum ${MAX_AIRPORTS[user.subscription_tier]} preferred airport(s)`
  );
}
```

**Weight Validation:**
```typescript
// Each airport weight must be 0.0-1.0
for (const airport of preferred_airports) {
  if (airport.weight < 0 || airport.weight > 1.0) {
    return error("Airport weight must be between 0.0 and 1.0");
  }
}

// Sum of weights must equal 1.0 (tolerance 0.001 for floating point)
const totalWeight = preferred_airports.reduce((sum, a) => sum + a.weight, 0);
if (Math.abs(totalWeight - 1.0) > 0.001) {
  return error(
    `Airport weights must sum to 1.0 (current: ${totalWeight.toFixed(3)})`
  );
}
```

**IATA Code Validation:**
```typescript
const iataRegex = /^[A-Z]{3}$/;
for (const airport of preferred_airports) {
  if (!iataRegex.test(airport.iata)) {
    return error(`Invalid IATA code: ${airport.iata}. Must be 3 uppercase letters.`);
  }
}

// Check for duplicates
const iataSet = new Set(preferred_airports.map(a => a.iata));
if (iataSet.size !== preferred_airports.length) {
  return error("Duplicate airport codes detected");
}
```

**ID Generation:**
```typescript
// iOS sends: [{"iata": "LAX", "weight": 0.6}]
// Worker generates UUIDs and stores: [{"id": "uuid", "iata": "LAX", "weight": 0.6}]

const airportsWithIds = preferred_airports.map(airport => ({
  id: airport.id || crypto.randomUUID(), // Keep existing ID or generate new
  iata: airport.iata,
  weight: airport.weight
}));
```

### Response (200 OK)
```json
{
  "user": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "email": "user@example.com",
    "timezone": "America/New_York",
    "subscription_tier": "pro",
    "alert_preferences": {
      "enabled": true,
      "quiet_hours_enabled": false,
      "quiet_hours_start": 22,
      "quiet_hours_end": 7,
      "watchlist_only_mode": true
    },
    "preferred_airports": [
      {
        "id": "generated-uuid-1",
        "iata": "JFK",
        "weight": 0.7
      },
      {
        "id": "generated-uuid-2",
        "iata": "BOS",
        "weight": 0.3
      }
    ]
  }
}
```

### Error Responses

```json
// 400 Bad Request - Invalid timezone
{
  "error": "Invalid timezone format. Use IANA format (e.g., America/Los_Angeles)"
}

// 400 Bad Request - Invalid quiet hours
{
  "error": "quiet_hours_start must be 0-23"
}

// 403 Forbidden - Pro feature on Free tier
{
  "error": "Watchlist-only mode is a Pro feature. Upgrade to enable.",
  "upgrade_required": true
}

// 400 Bad Request - Too many airports
{
  "error": "free tier allows maximum 1 preferred airport(s)"
}

// 400 Bad Request - Invalid weight sum
{
  "error": "Airport weights must sum to 1.0 (current: 0.850)"
}

// 400 Bad Request - Invalid IATA code
{
  "error": "Invalid IATA code: LAX1. Must be 3 uppercase letters."
}

// 400 Bad Request - Duplicate airports
{
  "error": "Duplicate airport codes detected"
}

// 401 Unauthorized
{
  "error": "Unauthorized"
}

// 500 Internal Server Error
{
  "error": "Failed to update user data"
}
```

---

## Zod Schemas

### UserUpdateRequestSchema
```typescript
import { z } from 'zod';

const AlertPreferencesUpdateSchema = z.object({
  enabled: z.boolean().optional(),
  quiet_hours_enabled: z.boolean().optional(),
  quiet_hours_start: z.number().int().min(0).max(23).optional(),
  quiet_hours_end: z.number().int().min(0).max(23).optional(),
  watchlist_only_mode: z.boolean().optional(),
}).strict(); // Reject unknown fields

const PreferredAirportInputSchema = z.object({
  id: z.string().uuid().optional(), // Client can send existing ID
  iata: z.string().regex(/^[A-Z]{3}$/, 'IATA code must be 3 uppercase letters'),
  weight: z.number().min(0).max(1.0, 'Weight must be 0.0-1.0'),
});

const UserUpdateRequestSchema = z.object({
  timezone: z.string()
    .regex(/^[A-Z][a-zA-Z_]+\/[A-Z][a-zA-Z_]+$/, 'Invalid IANA timezone format')
    .optional(),
  alert_preferences: AlertPreferencesUpdateSchema.optional(),
  preferred_airports: z.array(PreferredAirportInputSchema)
    .max(3, 'Maximum 3 preferred airports allowed')
    .optional(),
}).strict();

type UserUpdateRequest = z.infer<typeof UserUpdateRequestSchema>;
```

### SupabaseUserRowSchema
```typescript
// Schema for Supabase users table row
const SupabaseUserRowSchema = z.object({
  id: z.string().uuid(),
  email: z.string().email(),
  created_at: z.string().datetime(),
  timezone: z.string(),
  subscription_tier: z.enum(['free', 'pro']),
  alert_enabled: z.boolean(),
  quiet_hours_enabled: z.boolean(),
  quiet_hours_start: z.number().int().min(0).max(23),
  quiet_hours_end: z.number().int().min(0).max(23),
  watchlist_only_mode: z.boolean(),
  preferred_airports: z.string(), // JSONB comes as string from PostgREST
});

type SupabaseUserRow = z.infer<typeof SupabaseUserRowSchema>;
```

---

## Implementation Pattern: PostgREST Passthrough

### GET /user Flow
```
iOS → Worker verifyAuth()
    → Worker: GET /rest/v1/users?id=eq.{userId}
    → Supabase: Returns flat row
    → Worker: Transform flat → nested (transformSupabaseUserToAPI)
    → iOS: Receives nested User object
```

### PATCH /user Flow
```
iOS → Worker verifyAuth()
    → Worker: Validate request (Zod)
    → Worker: Check tier limits (preferred_airports, watchlist_only_mode)
    → Worker: Validate weights sum to 1.0
    → Worker: Generate UUIDs for new airports
    → Worker: Transform nested → flat (transformAPIUserToSupabase)
    → Worker: PATCH /rest/v1/users?id=eq.{userId}
    → Supabase: Updates row (RLS enforces user can only update their row)
    → Supabase: Returns updated row
    → Worker: Transform flat → nested
    → iOS: Receives updated User object
```

---

## Transformation Functions

### transformSupabaseUserToAPI
```typescript
function transformSupabaseUserToAPI(supabaseRow: SupabaseUserRow): APIUser {
  // Parse preferred_airports JSONB
  let preferredAirports = [];
  try {
    preferredAirports = JSON.parse(supabaseRow.preferred_airports || '[]');
  } catch (e) {
    console.error('Failed to parse preferred_airports JSONB:', e);
    preferredAirports = [];
  }

  return {
    id: supabaseRow.id,
    email: supabaseRow.email,
    created_at: supabaseRow.created_at,
    timezone: supabaseRow.timezone,
    subscription_tier: supabaseRow.subscription_tier,
    alert_preferences: {
      enabled: supabaseRow.alert_enabled,
      quiet_hours_enabled: supabaseRow.quiet_hours_enabled,
      quiet_hours_start: supabaseRow.quiet_hours_start,
      quiet_hours_end: supabaseRow.quiet_hours_end,
      watchlist_only_mode: supabaseRow.watchlist_only_mode,
    },
    preferred_airports: preferredAirports,
  };
}
```

### transformAPIUserToSupabase
```typescript
function transformAPIUserToSupabase(
  updateRequest: UserUpdateRequest,
  currentUser: SupabaseUserRow
): Partial<SupabaseUserRow> {
  const supabaseUpdate: Record<string, any> = {};

  // Direct field mapping
  if (updateRequest.timezone !== undefined) {
    supabaseUpdate.timezone = updateRequest.timezone;
  }

  // Flatten alert_preferences
  if (updateRequest.alert_preferences) {
    const prefs = updateRequest.alert_preferences;
    if (prefs.enabled !== undefined) {
      supabaseUpdate.alert_enabled = prefs.enabled;
    }
    if (prefs.quiet_hours_enabled !== undefined) {
      supabaseUpdate.quiet_hours_enabled = prefs.quiet_hours_enabled;
    }
    if (prefs.quiet_hours_start !== undefined) {
      supabaseUpdate.quiet_hours_start = prefs.quiet_hours_start;
    }
    if (prefs.quiet_hours_end !== undefined) {
      supabaseUpdate.quiet_hours_end = prefs.quiet_hours_end;
    }
    if (prefs.watchlist_only_mode !== undefined) {
      supabaseUpdate.watchlist_only_mode = prefs.watchlist_only_mode;
    }
  }

  // Transform preferred_airports array to JSONB
  if (updateRequest.preferred_airports !== undefined) {
    // Generate UUIDs for airports without IDs
    const airportsWithIds = updateRequest.preferred_airports.map(airport => ({
      id: airport.id || crypto.randomUUID(),
      iata: airport.iata,
      weight: airport.weight,
    }));

    supabaseUpdate.preferred_airports = JSON.stringify(airportsWithIds);
  }

  return supabaseUpdate;
}
```

---

## Tier Limit Enforcement

**Where:** Worker middleware (BEFORE hitting Supabase)

**Why:**
- Supabase constraints only check data integrity (array type, valid JSON)
- Business logic (tier limits) belongs in application layer
- Better error messages to user

**How:**
```typescript
async function validateTierLimits(
  updateRequest: UserUpdateRequest,
  currentUser: SupabaseUserRow
): Promise<{ valid: boolean; error?: string }> {
  const tier = currentUser.subscription_tier;

  // Check preferred airports limit
  if (updateRequest.preferred_airports !== undefined) {
    const MAX_AIRPORTS = { free: 1, pro: 3 };
    if (updateRequest.preferred_airports.length > MAX_AIRPORTS[tier]) {
      return {
        valid: false,
        error: `${tier} tier allows maximum ${MAX_AIRPORTS[tier]} preferred airport(s)`,
      };
    }
  }

  // Check watchlist-only mode (Pro only)
  if (updateRequest.alert_preferences?.watchlist_only_mode === true) {
    if (tier === 'free') {
      return {
        valid: false,
        error: 'Watchlist-only mode is a Pro feature. Upgrade to enable.',
      };
    }
  }

  return { valid: true };
}
```

---

## Alternative Designs Considered (and Rejected)

### ❌ Option 1: Separate Endpoints
```
GET /alert-preferences
PUT /alert-preferences
PUT /preferred-airports
PATCH /user (timezone only)
```

**Rejected because:**
- iOS models show these as properties of User (not separate resources)
- 4 endpoints vs 2 endpoints (more round-trips)
- Atomicity issues (what if airport update succeeds but alert pref fails?)
- More complex state management in iOS

### ❌ Option 2: Store alert_preferences as JSONB
```sql
-- Supabase schema
alert_preferences JSONB -- Store as nested object
```

**Rejected because:**
- Schema already deployed with flat columns (migration cost)
- Flat columns enable database-level constraints (CHECK quiet_hours_start < 24)
- Flat columns enable efficient indexing (if needed for analytics)
- Worker transformation is cheap (happens once per request)

### ❌ Option 3: Store preferred_airports as separate table
```sql
CREATE TABLE preferred_airports (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  iata TEXT,
  weight NUMERIC
);
```

**Rejected because:**
- Max 3 airports per user (small dataset, doesn't justify separate table)
- JSONB array is simpler (no JOIN needed)
- Atomic updates (replace entire array vs managing rows)
- Schema already deployed

---

## Testing Strategy

### Unit Tests (Worker)
1. `transformSupabaseUserToAPI` - Flat → Nested
2. `transformAPIUserToSupabase` - Nested → Flat
3. `validateTierLimits` - Free/Pro limits enforced
4. `validateWeights` - Sum to 1.0 check

### Integration Tests (Worker → Supabase)
1. GET /user - Returns correctly transformed user
2. PATCH /user (timezone) - Updates timezone field
3. PATCH /user (alert_preferences) - Flattens and updates
4. PATCH /user (preferred_airports) - Validates weights, generates IDs, stores JSONB
5. PATCH /user (too many airports on Free) - Returns 403
6. PATCH /user (watchlist_only_mode on Free) - Returns 403
7. PATCH /user (invalid weight sum) - Returns 400

### iOS Integration Tests
1. Fetch user → Decode into User model
2. Update timezone → Verify persisted
3. Update alert preferences → Verify nested object decoded correctly
4. Update preferred airports → Verify weights validated, IDs generated

---

## Migration Path

### Current State (Broken)
```
iOS → GET /alert-preferences → 404 (not implemented)
iOS → PUT /alert-preferences → Wrong schema
iOS → PUT /alert-preferences/airports → Expects strings, gets objects
iOS → PATCH /user → Ignores timezone
```

### Target State (This Design)
```
iOS → GET /user → Returns full user with nested alert_preferences, preferred_airports
iOS → PATCH /user → Updates timezone, alert_preferences, preferred_airports atomically
```

### Migration Steps
1. **Worker:** Implement GET /user with transformation
2. **Worker:** Implement PATCH /user with validation + transformation
3. **Worker:** Keep old endpoints (GET /alert-preferences, etc.) for backwards compat
4. **iOS:** Update to use GET /user, PATCH /user
5. **Worker:** Remove deprecated endpoints after iOS migration complete

---

## Performance Considerations

### Caching Strategy
**Don't cache GET /user** - User settings change frequently, stale data causes bugs

**Why:**
- User changes timezone → Background refresh uses old timezone
- User disables alerts → Keeps getting alerts (bad UX)
- Cache invalidation on PATCH adds complexity

**Instead:**
- Rely on Supabase RLS query cache (sub-millisecond for indexed queries)
- iOS caches User object in memory (survives app backgrounding)

### Query Optimization
```sql
-- Index on users.id already exists (primary key)
-- No additional indexes needed (single-row lookup by PK)
```

---

## Security Considerations

### Row-Level Security (RLS)
```sql
-- Already enforced in Supabase schema (line 149)
CREATE POLICY "Users can update their own data" ON public.users
  FOR UPDATE USING ((select auth.uid()) = id)
  WITH CHECK ((select auth.uid()) = id);
```

**What this prevents:**
- User A cannot update User B's settings (enforced server-side)
- Even if iOS sends wrong user_id, RLS blocks it

### Input Validation
**All inputs validated in Worker BEFORE hitting database:**
- Timezone: IANA format regex
- Quiet hours: 0-23 range check
- IATA codes: 3 uppercase letters regex
- Weights: 0.0-1.0 range, sum = 1.0
- No SQL injection possible (PostgREST uses parameterized queries)

### Authorization
**Tier-based features enforced in Worker:**
- Free tier: Max 1 airport, watchlist_only_mode blocked
- Pro tier: Max 3 airports, watchlist_only_mode allowed
- Prevents client-side bypass (iOS can't force Pro features on Free account)

---

## Error Handling

### Partial Update Handling
**What happens if iOS sends partial alert_preferences?**

```json
// iOS sends (only updating quiet_hours_enabled)
{
  "alert_preferences": {
    "quiet_hours_enabled": false
  }
}

// Worker flattens to Supabase
{
  "quiet_hours_enabled": false
  // Other fields (alert_enabled, quiet_hours_start, etc.) unchanged
}

// Supabase PATCH updates only specified fields
// Other fields remain at current values
```

**This works because:**
- PATCH updates only specified fields (not full replacement)
- Worker only includes fields iOS sent
- Supabase preserves unspecified fields

### Weight Validation Failure Recovery
**What if user's current weights don't sum to 1.0?**

```typescript
// On GET /user, always validate weights
const airports = JSON.parse(supabaseRow.preferred_airports);
const totalWeight = airports.reduce((sum, a) => sum + a.weight, 0);

if (Math.abs(totalWeight - 1.0) > 0.001) {
  // Auto-normalize weights to sum to 1.0
  const normalized = airports.map(a => ({
    ...a,
    weight: a.weight / totalWeight
  }));

  console.warn(`Auto-normalized weights for user ${supabaseRow.id}`);

  // Update database with normalized weights
  await updateUserAirports(supabaseRow.id, normalized);
}
```

**Why this is safe:**
- Prevents invalid state from breaking app
- Maintains user intent (relative weights preserved)
- Logs for debugging

---

## Endpoint Summary

| Method | Path | Purpose | Request Body | Response |
|--------|------|---------|--------------|----------|
| GET | /user | Fetch user profile | None | User object with nested alert_preferences, preferred_airports |
| PATCH | /user | Update user profile | Partial user fields | Updated user object |

**Deprecated (backwards compat only):**
| Method | Path | Status |
|--------|------|--------|
| GET | /alert-preferences | Redirect to GET /user |
| PUT | /alert-preferences | Redirect to PATCH /user |
| PUT | /alert-preferences/airports | Redirect to PATCH /user |

---

## Implementation Checklist

- [ ] Implement `transformSupabaseUserToAPI()`
- [ ] Implement `transformAPIUserToSupabase()`
- [ ] Implement `validateTierLimits()`
- [ ] Implement `validateAirportWeights()`
- [ ] Implement GET /user handler
- [ ] Implement PATCH /user handler
- [ ] Add Zod schemas (UserUpdateRequestSchema, SupabaseUserRowSchema)
- [ ] Add unit tests (transformations, validations)
- [ ] Add integration tests (Worker → Supabase round-trip)
- [ ] Update iOS APIEndpoint.swift (remove deprecated endpoints)
- [ ] Test iOS → Worker → Supabase flow end-to-end
- [ ] Deploy Worker
- [ ] Verify in production
