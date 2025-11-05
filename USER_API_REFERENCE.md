# User API Quick Reference

## GET /user

**Fetch complete user profile**

```http
GET /user HTTP/1.1
Authorization: Bearer <jwt>
```

**Response 200:**
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
        "weight": 0.4
      }
    ]
  }
}
```

**Errors:**
- 401: Unauthorized (invalid/missing JWT)
- 404: User not found
- 500: Internal server error

---

## PATCH /user

**Update user profile (partial)**

```http
PATCH /user HTTP/1.1
Authorization: Bearer <jwt>
Content-Type: application/json

{
  "timezone": "America/New_York",
  "alert_preferences": {
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

**All fields optional (partial update)**

**Response 200:**
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

**Errors:**

```json
// 400: Invalid timezone
{
  "error": "Invalid timezone format. Use IANA format (e.g., America/Los_Angeles)"
}

// 400: Invalid quiet hours
{
  "error": "quiet_hours_start must be 0-23"
}

// 400: Weight sum invalid
{
  "error": "Airport weights must sum to 1.0 (current: 0.850)"
}

// 400: Invalid IATA
{
  "error": "Invalid IATA code: LAX1. Must be 3 uppercase letters."
}

// 400: Duplicate airports
{
  "error": "Duplicate airport codes detected"
}

// 403: Tier limit exceeded
{
  "error": "free tier allows maximum 1 preferred airport(s)",
  "upgrade_required": true
}

// 403: Pro feature on Free tier
{
  "error": "Watchlist-only mode is a Pro feature. Upgrade to enable.",
  "upgrade_required": true
}

// 401: Unauthorized
{
  "error": "Unauthorized"
}

// 500: Internal error
{
  "error": "Failed to update user data"
}
```

---

## Request Fields

### timezone
- **Type:** String
- **Format:** IANA timezone (e.g., "America/Los_Angeles", "Europe/London")
- **Validation:** Must match regex `/^[A-Z][a-zA-Z_]+\/[A-Z][a-zA-Z_]+$/`
- **Optional:** Yes

### alert_preferences
- **Type:** Object
- **Optional:** Yes

#### alert_preferences.enabled
- **Type:** Boolean
- **Optional:** Yes

#### alert_preferences.quiet_hours_enabled
- **Type:** Boolean
- **Optional:** Yes

#### alert_preferences.quiet_hours_start
- **Type:** Integer (0-23)
- **Validation:** Must be 0-23
- **Optional:** Yes

#### alert_preferences.quiet_hours_end
- **Type:** Integer (0-23)
- **Validation:** Must be 0-23
- **Optional:** Yes

#### alert_preferences.watchlist_only_mode
- **Type:** Boolean
- **Validation:** Pro tier only
- **Optional:** Yes

### preferred_airports
- **Type:** Array of objects
- **Max Length:** 3 (Pro tier), 1 (Free tier)
- **Validation:**
  - Weights must sum to 1.0 (±0.001 tolerance)
  - No duplicate IATA codes
  - All IATA codes must be 3 uppercase letters
- **Optional:** Yes

#### preferred_airports[].id
- **Type:** String (UUID)
- **Optional:** Yes (Worker generates if missing)

#### preferred_airports[].iata
- **Type:** String
- **Format:** 3 uppercase letters (e.g., "LAX", "JFK")
- **Validation:** Must match regex `/^[A-Z]{3}$/`
- **Required:** Yes

#### preferred_airports[].weight
- **Type:** Number (0.0-1.0)
- **Validation:** Must be 0.0-1.0, all weights must sum to 1.0
- **Required:** Yes

---

## Response Fields

### user.id
- **Type:** String (UUID)
- **Example:** "550e8400-e29b-41d4-a716-446655440000"

### user.email
- **Type:** String (email)
- **Example:** "user@example.com"

### user.created_at
- **Type:** String (ISO8601 datetime)
- **Example:** "2025-01-15T10:30:00Z"

### user.timezone
- **Type:** String (IANA timezone)
- **Example:** "America/Los_Angeles"

### user.subscription_tier
- **Type:** String (enum)
- **Values:** "free" | "pro"

### user.alert_preferences
- **Type:** Object
- **Contains:** enabled, quiet_hours_enabled, quiet_hours_start, quiet_hours_end, watchlist_only_mode

### user.preferred_airports
- **Type:** Array of objects
- **Max Length:** 3 (Pro), 1 (Free)
- **Each object contains:** id (UUID), iata (String), weight (Number)

---

## Validation Rules Summary

| Field | Rule | Error |
|-------|------|-------|
| timezone | IANA format | "Invalid timezone format" |
| quiet_hours_start | 0-23 | "must be 0-23" |
| quiet_hours_end | 0-23 | "must be 0-23" |
| watchlist_only_mode | Pro tier only | "Pro feature. Upgrade to enable." |
| preferred_airports (Free) | Max 1 | "free tier allows maximum 1 airport" |
| preferred_airports (Pro) | Max 3 | "pro tier allows maximum 3 airports" |
| airport.iata | 3 uppercase letters | "Must be 3 uppercase letters" |
| airport.weight | 0.0-1.0 | "Weight must be 0.0-1.0" |
| airports.sum(weight) | 1.0 ± 0.001 | "Weights must sum to 1.0" |
| airports.iata | No duplicates | "Duplicate airport codes detected" |

---

## Tier Limits

| Feature | Free | Pro |
|---------|------|-----|
| Preferred Airports | 1 | 3 |
| Watchlist-Only Mode | ❌ | ✅ |

---

## Examples

### Example 1: Update timezone only
```http
PATCH /user
{
  "timezone": "America/New_York"
}
```

### Example 2: Disable quiet hours
```http
PATCH /user
{
  "alert_preferences": {
    "quiet_hours_enabled": false
  }
}
```

### Example 3: Set 1 preferred airport (Free tier)
```http
PATCH /user
{
  "preferred_airports": [
    {
      "iata": "LAX",
      "weight": 1.0
    }
  ]
}
```

### Example 4: Set 3 preferred airports (Pro tier)
```http
PATCH /user
{
  "preferred_airports": [
    {
      "iata": "LAX",
      "weight": 0.6
    },
    {
      "iata": "JFK",
      "weight": 0.3
    },
    {
      "iata": "ORD",
      "weight": 0.1
    }
  ]
}
```

### Example 5: Enable watchlist-only mode (Pro tier)
```http
PATCH /user
{
  "alert_preferences": {
    "watchlist_only_mode": true
  }
}
```

### Example 6: Update multiple fields atomically
```http
PATCH /user
{
  "timezone": "Europe/London",
  "alert_preferences": {
    "quiet_hours_start": 23,
    "quiet_hours_end": 8
  },
  "preferred_airports": [
    {
      "iata": "LHR",
      "weight": 0.5
    },
    {
      "iata": "LGW",
      "weight": 0.5
    }
  ]
}
```

---

## Deprecated Endpoints (Backwards Compatibility)

These endpoints are deprecated but still supported. They redirect to the new `/user` endpoint.

### GET /alert-preferences
**Status:** Deprecated (use `GET /user` instead)
**Response:** Extracts `alert_preferences` from user object
**Header:** `X-Deprecated: Use GET /user instead`

### PUT /alert-preferences
**Status:** Deprecated (use `PATCH /user` instead)
**Request:** Old format `{ "enabled": true, ... }`
**Transform:** Worker converts to `{ "alert_preferences": { ... } }`
**Header:** `X-Deprecated: Use PATCH /user instead`

### PUT /alert-preferences/airports
**Status:** Deprecated (use `PATCH /user` instead)
**Request:** Old format `{ "preferred_airports": [...] }`
**Transform:** Worker passes through to `PATCH /user`
**Header:** `X-Deprecated: Use PATCH /user instead`

**Migration timeline:**
1. New iOS app uses `GET /user` and `PATCH /user`
2. Old endpoints remain for backwards compatibility (6 months)
3. Remove deprecated endpoints after all clients migrate

---

## Implementation Notes

### UUID Generation
Worker auto-generates UUIDs for new airports:
```typescript
// iOS sends
{ "iata": "LAX", "weight": 1.0 }

// Worker generates ID
{ "id": "generated-uuid", "iata": "LAX", "weight": 1.0 }

// iOS can send existing ID to preserve
{ "id": "existing-uuid", "iata": "LAX", "weight": 1.0 }
```

### Partial Updates
PATCH updates only specified fields:
```typescript
// iOS sends (only updating quiet_hours_enabled)
{
  "alert_preferences": {
    "quiet_hours_enabled": false
  }
}

// Other fields unchanged:
// - enabled: remains current value
// - quiet_hours_start: remains current value
// - quiet_hours_end: remains current value
// - watchlist_only_mode: remains current value
```

### Weight Tolerance
Floating point arithmetic tolerance:
```typescript
// Valid (sum = 1.0 exactly)
0.6 + 0.4 = 1.0 ✓

// Valid (sum within tolerance)
0.333333 + 0.333333 + 0.333334 = 1.000000 ✓

// Invalid (sum outside tolerance)
0.5 + 0.3 = 0.8 ✗
```

---

## Testing

### cURL Examples

```bash
# GET /user
curl -H "Authorization: Bearer <jwt>" \
  https://api.farelens.com/user

# PATCH /user (timezone)
curl -X PATCH \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{"timezone":"America/New_York"}' \
  https://api.farelens.com/user

# PATCH /user (preferred airports)
curl -X PATCH \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "preferred_airports": [
      {"iata":"LAX","weight":0.6},
      {"iata":"JFK","weight":0.4}
    ]
  }' \
  https://api.farelens.com/user
```

### Swift Examples

```swift
// GET /user
let endpoint = APIEndpoint(
  path: "/user",
  method: .get
)

// PATCH /user (timezone)
let endpoint = APIEndpoint(
  path: "/user",
  method: .patch,
  body: [
    "timezone": "America/New_York"
  ]
)

// PATCH /user (alert preferences)
let endpoint = APIEndpoint(
  path: "/user",
  method: .patch,
  body: [
    "alert_preferences": [
      "quiet_hours_enabled": false,
      "watchlist_only_mode": true
    ]
  ]
)

// PATCH /user (preferred airports)
let endpoint = APIEndpoint(
  path: "/user",
  method: .patch,
  body: [
    "preferred_airports": [
      ["iata": "LAX", "weight": 0.6],
      ["iata": "JFK", "weight": 0.4]
    ]
  ]
)
```
