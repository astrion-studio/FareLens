# FareLens Backend: Architecture Decisions

This document captures key architectural decisions made during the P1 code review to guide future development.

---

## 1. Authentication Pattern: User ID from JWT Only

**Decision:** User ID MUST come from `Depends(get_current_user_id)` dependency injection, never from request body or query params.

**Implementation:**
```python
# CORRECT
@router.get("/watchlists")
async def list_watchlists(
    user_id: UUID = Depends(get_current_user_id),  # From JWT token
    provider: DataProvider = Depends(get_data_provider),
) -> list[Watchlist]:
    return await provider.list_watchlists(user_id=user_id)

# WRONG - do not do this
@router.get("/watchlists")
async def list_watchlists(
    user_id: UUID,  # From query param - SECURITY ISSUE!
) -> list[Watchlist]:
    ...
```

**Rationale:**
- User ID is identity credential - must be cryptographically signed
- JWT token is signed by Supabase - trustworthy source
- Query params can be modified by attacker
- Prevents spoofing (attacker can't pretend to be someone else)

**Enforcement:** Python's ABC enforces this at type-check time. All user-scoped methods require `user_id` parameter.

---

## 2. Field Validation: Strict Schema with Explicit Field Lists

**Decision:** Use Zod `.strict()` to reject unknown fields in request bodies.

**Implementation:**
```typescript
// CORRECT - explicitly list updatable fields
const UserUpdateSchema = z.object({
  timezone: z.string().optional(),
  alert_enabled: z.boolean().optional(),
  quiet_hours_enabled: z.boolean().optional(),
  quiet_hours_start: z.number().int().min(0).max(23).optional(),
  quiet_hours_end: z.number().int().min(0).max(23).optional(),
  watchlist_only_mode: z.boolean().optional(),
  preferred_airports: z.array(PreferredAirportSchema).optional(),
}).strict();  // IMPORTANT: Reject unknown fields

// WRONG - would allow malicious fields
const UserUpdateSchema = z.object({
  timezone: z.string().optional(),
  // Missing .strict() - allows subscription_tier, created_at, etc.!
});
```

**Rationale:**
- Immutable fields (subscription_tier, created_at, id) must never be updateable from client
- Fail-fast prevents logic errors
- Zod validation at schema level is DRY (vs manual filtering)
- Clear API contract - easy to understand which fields are updatable

**Trade-offs Considered:**

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Strict validation with `.strict()` | Fail-fast, clear contract, type-safe | Error might leak field names | CHOSEN |
| Silent filtering (remove unwanted fields) | No error to attacker | Security through obscurity | Rejected |
| Runtime validation (manual checks) | Explicit control | Verbose, error-prone | Rejected |

**Enforcement:** Add to code review checklist: All Zod schemas for user input must have `.strict()`.

---

## 3. Validation Patterns: Centralized, Reusable

**Decision:** Extract common validation patterns into shared module.

**Module Structure:**
```typescript
// cloudflare-workers/src/validation.ts
export const IATA_CODE_PATTERN = /^[A-Z]{3}$/;
export const DESTINATION_PATTERN = /^([A-Z]{3}|ANY)$/;

export const originValidation = z.string().regex(IATA_CODE_PATTERN, ...);
export const destinationValidation = z.string().regex(DESTINATION_PATTERN, ...);
```

**Usage:**
```typescript
// In any schema that needs IATA codes
const WatchlistSchema = z.object({
  origin: originValidation,
  destination: destinationValidation,
});
```

**Rationale:**
- DRY principle - one source of truth for validation
- Consistency across all endpoints
- Easy to update validation globally
- Type-safe (Zod schemas prevent misuse)

**When to Centralize:**
- Patterns used in 2+ places (IATA codes, emails, prices)
- Patterns that might change (airport codes could support "ANY" in future)
- Business-critical formats (IATA codes, subscription tiers)

**When to Keep Local:**
- Endpoint-specific validation (watchlist name format)
- Single-use patterns (field length for form input)

---

## 4. IATA Code Handling: Origin vs Destination

**Decision:** Origin must be specific IATA code. Destination can be IATA code OR "ANY" wildcard.

**Implementation:**
```typescript
originValidation = z.string().regex(/^[A-Z]{3}$/, ...)      // LAX, JFK only
destinationValidation = z.string().regex(/^([A-Z]{3}|ANY)$/, ...)  // LAX, JFK, or ANY
```

**Rationale:**

**Origin is always specific:**
- Origin = user's departure airport (where they fly FROM)
- Must always be known (user selects their home airport)
- Example: "Show me flights FROM San Francisco"

**Destination can be flexible:**
- Destination = where user travels TO
- User might search: "Show me deals FROM SFO TO ANYWHERE"
- Enables discovery of unexpected destinations
- Use case: "I'm free to travel, show me all good deals from home"

**Database Schema:**
```sql
CREATE TABLE watchlists (
  origin VARCHAR(3) NOT NULL,        -- Always specific (LAX, SFO, etc.)
  destination VARCHAR(3) NOT NULL,   -- Can be specific (TYO) or "ANY"
  ...
);

-- Valid combinations:
(SFO, LAX)    -- SFO to LAX
(SFO, TYO)    -- SFO to Tokyo
(SFO, ANY)    -- SFO to anywhere
(ANY, LAX)    -- NOT ALLOWED (invalid origin)
```

---

## 5. HTTP Status Codes: Use Constants, Not Integers

**Decision:** Always use `status.HTTP_*` constants from FastAPI/HTTP standards library.

**Implementation:**
```python
# CORRECT
from fastapi import status

raise HTTPException(
    status_code=status.HTTP_404_NOT_FOUND,
    detail="Resource not found"
)

# WRONG - numeric status codes
raise HTTPException(
    status_code=404,
    detail="Resource not found"
)
```

**Rationale:**
- Type safety (IDE autocomplete shows all options)
- Discoverability (grep for `HTTP_404` finds all 404s)
- Readability (clear intent vs magic number)
- Consistency (team agreement on format)

**Common Status Codes:**
| Code | Constant | Use Case |
|------|----------|----------|
| 200 | HTTP_200_OK | Successful GET, PATCH |
| 201 | HTTP_201_CREATED | Successful POST |
| 204 | HTTP_204_NO_CONTENT | Successful DELETE |
| 400 | HTTP_400_BAD_REQUEST | Invalid input validation |
| 401 | HTTP_401_UNAUTHORIZED | Missing/invalid auth token |
| 403 | HTTP_403_FORBIDDEN | User lacks permission |
| 404 | HTTP_404_NOT_FOUND | Resource doesn't exist |
| 409 | HTTP_409_CONFLICT | Duplicate (e.g., watchlist already exists) |
| 500 | HTTP_500_INTERNAL_SERVER_ERROR | Unexpected server error |

**Enforcement:** Lint rule - grep to catch numeric status codes in commits.

---

## 6. Provider Interface: Dual Implementation (Supabase + In-Memory)

**Decision:** Maintain two implementations of DataProvider abstract interface:
1. SupabaseProvider (production, uses PostgreSQL)
2. InMemoryProvider (development, in-memory dict)

**Implementation:**
```python
class DataProvider(ABC):  # Abstract interface
    @abstractmethod
    async def list_alert_history(
        self, user_id: UUID, page: int, per_page: int
    ) -> Tuple[List[AlertHistory], int]: ...

class SupabaseProvider(DataProvider):
    async def list_alert_history(self, user_id, page, per_page):
        # PostgreSQL implementation
        WHERE a.user_id = $1

class InMemoryProvider(DataProvider):
    async def list_alert_history(self, user_id, page, per_page):
        # Dict implementation
        return self._alerts[user_id][offset:offset+per_page]
```

**Rationale:**
- Development doesn't need Docker + Postgres
- InMemoryProvider runs instantly
- Same interface prevents bugs (can't implement one without the other)
- Easy to swap for testing (dependency injection)

**Synchronization Rule:**
If you modify SupabaseProvider, you MUST also modify InMemoryProvider. Python's ABC enforces this at runtime - if signatures don't match, both implementations will fail to instantiate.

**Enforcement:**
```bash
# Run before committing
python -m mypy backend/app/services/
```

---

## 7. Database Filtering: Always Filter at Query Time

**Decision:** Implement user_id filtering at database query level, not in application code.

**Implementation (CORRECT):**
```python
# SupabaseProvider - filters in SQL query
async def list_alert_history(self, user_id: UUID, ...):
    WHERE a.user_id = $1  # Database filters at query time
    ORDER BY a.sent_at DESC

# InMemoryProvider - filters at dict access
async def list_alert_history(self, user_id: UUID, ...):
    return self._alerts[user_id]  # Dict keyed by user_id
```

**Implementation (WRONG):**
```python
# Anti-pattern: Returns all, filters in app
async def list_alert_history(self, ...):
    rows = await conn.fetch("SELECT * FROM alert_history")  # NO!
    # Can't return all users' alerts to application
    return [r for r in rows if r.user_id == current_user]   # Bad!
```

**Rationale:**
- Database filters before data leaves server
- Prevents accidental data leaks
- Scales better (filtering millions of rows in Python is slow)
- Security default (can't leak what you don't fetch)

---

## 8. Error Handling: Fail-Fast with Clear Messages

**Decision:** Validate input at schema level, not in handler logic.

**Implementation:**
```typescript
// CORRECT - validation in schema
const WatchlistSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  origin: originValidation,
  destination: destinationValidation,
});

async function createWatchlist(request: Request, ...) {
  const body = await request.json();
  const result = WatchlistSchema.safeParse(body);  // Validate first
  if (!result.success) {
    return jsonResponse({ error: 'Invalid data', details: result.error.issues }, 400);
  }
  // Handler only processes valid data
}

// WRONG - validation scattered in handler
async function createWatchlist(request: Request, ...) {
  const body = await request.json();
  if (!body.name) throw new Error('Name required');
  if (!body.origin) throw new Error('Origin required');
  if (body.origin.length !== 3) throw new Error('Origin must be 3 chars');
  // ... scattered validation
}
```

**Rationale:**
- Single source of truth for validation rules
- Errors caught before handler logic
- Clear error messages to client
- Type inference (TypeScript knows validated data is correct)

---

## 9. Device Token Registration: User + Device Identification

**Decision:** Store device tokens with composite key (user_id, device_id).

**Schema:**
```sql
CREATE TABLE device_registrations (
  user_id UUID REFERENCES users(id),
  device_id UUID,
  apns_token TEXT,
  platform VARCHAR(20),
  UNIQUE(user_id, device_id)  -- One registration per device per user
);
```

**Implementation:**
```python
async def register_device_token(
    self, user_id: UUID, device_id: UUID, token: str, platform: str
):
    INSERT INTO device_registrations (user_id, device_id, apns_token, platform)
    VALUES ($1, $2, $3, $4)
    ON CONFLICT (user_id, device_id) DO UPDATE SET
        apns_token = EXCLUDED.apns_token
```

**Rationale:**
- User can have multiple devices (iPhone + iPad)
- Each device has unique ID (from iOS UUID)
- UPSERT handles device re-registration (replaces old token)
- Prevents token fragmentation (old tokens cleaned up automatically)

**Example Flow:**
1. User registers iPhone: (user_123, device_456, apns_token_abc)
2. User registers iPad: (user_123, device_789, apns_token_def)
3. iPhone token rotates: UPDATE (user_123, device_456) set token=xyz
4. Database enforces consistency: one row per (user, device) pair

---

## 10. Authentication Flow: JWT from Supabase

**Decision:** Use Supabase Auth for JWT generation. Backend validates JWT without contacting Supabase.

**Architecture:**
```
┌──────────────────────────────────────────────────────┐
│  Client (iOS App)                                    │
│  1. Sign in with Apple                               │
│  2. Supabase Auth exchanges with Apple               │
│  3. Receives JWT token (signed by Supabase)          │
│  4. Stores JWT in secure storage (Keychain)          │
│  5. Sends JWT with every API request                 │
└──────────────┬───────────────────────────────────────┘
               │
               │ Bearer {JWT}
               ↓
┌──────────────────────────────────────────────────────┐
│  Backend API                                         │
│  1. Extract JWT from Authorization header            │
│  2. Validate JWT signature using Supabase public key │
│  3. Extract user_id from "sub" claim                 │
│  4. Proceed with authenticated request               │
│  (No network call to Supabase needed!)               │
└──────────────────────────────────────────────────────┘
```

**Rationale:**
- Supabase signs JWT with private key
- Backend validates signature with public key (no secret needed)
- No need to call Supabase on every request (fast, scalable)
- Standard JWT pattern (OAuth 2.0 compatible)

---

## Implementation Checklist for New Endpoints

Before adding new endpoints, verify:

- [ ] **Authentication:** Does endpoint need user_id? Use `Depends(get_current_user_id)`
- [ ] **Validation:** Does endpoint accept request body? Create Zod schema with `.strict()`
- [ ] **Status Codes:** Use `status.HTTP_*` constants (not integers)
- [ ] **Error Handling:** Return helpful error messages with validation details
- [ ] **Database Filtering:** All user-scoped queries include `WHERE user_id = ?`
- [ ] **Provider Sync:** If modifying DataProvider interface, update both implementations
- [ ] **Tests:** Write at least one test for happy path + error case
- [ ] **Documentation:** Add endpoint to API.md with request/response examples

---

## Performance Considerations

### Database Query Optimization

1. **Indexes:** All frequently-queried columns should be indexed
   ```sql
   CREATE INDEX idx_alert_history_user_id ON alert_history(user_id);
   CREATE INDEX idx_watchlists_user_id ON watchlists(user_id);
   ```

2. **Pagination:** Always paginate large result sets
   ```python
   LIMIT $1 OFFSET $2  # Not LIMIT $1 SKIP $2
   ```

3. **Partial Indexes:** For filtered queries, use partial indexes
   ```sql
   CREATE INDEX idx_active_alerts ON alerts(created_at DESC)
   WHERE is_active = true;
   ```

### Caching

1. **Application Cache:** HTTP response cache in Cloudflare Workers (5-min TTL)
2. **Database Cache:** Postgres query cache (built-in, automatic)
3. **iOS App Cache:** UserDefaults for user preferences, URLCache for responses

### Cloudflare Workers Performance

- Validate input early (before Supabase fetch)
- Use KV cache for Amadeus responses
- Parallel fetch requests with Promise.all()
- Keep Worker code under 1MB (size limit)

---

## Security Checklist

For all endpoints:

- [ ] **Require Authentication:** Unless explicitly public (e.g., GET /deals)
- [ ] **Validate Input:** Zod schema with type coercion
- [ ] **Sanitize Output:** Never return sensitive fields (password hashes, etc.)
- [ ] **Rate Limiting:** Auth endpoints (signup/signin) should have rate limits
- [ ] **Error Messages:** Don't leak internal details (e.g., "user not found" for login)
- [ ] **HTTPS Only:** All API calls must be HTTPS (TLS 1.3)
- [ ] **CORS:** Restrict to iOS app bundle ID
- [ ] **SQL Injection:** Use parameterized queries (asyncpg does this)

---

## When to Revisit These Decisions

These decisions were made with FareLens's current scale (MVP → 10K users). Revisit when:

- **User count > 50K:** Consider sharding database
- **Response time > 500ms:** Add caching layer (Redis)
- **Concurrent users > 1K:** Horizontal scaling of API
- **Data size > 100GB:** Archive old data, consider data warehouse
- **Features > 100:** Consider GraphQL instead of REST

---

## References

- **Authentication:** JWT Best Practices (jwt.io)
- **Validation:** Zod Documentation (zod.dev)
- **API Design:** REST API Best Practices (restfulapi.net)
- **Database:** PostgreSQL Performance Tips (postgresql.org)
- **Security:** OWASP Top 10 (owasp.org)
