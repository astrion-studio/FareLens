# User Endpoints Integration Checklist

## Pre-Integration Review

- [ ] Read `USER_ENDPOINTS_SUMMARY.md` - Answers to all 5 questions
- [ ] Read `WORKER_USER_ENDPOINTS.md` - Complete endpoint specification
- [ ] Review `USER_API_REFERENCE.md` - Quick API reference
- [ ] Review `USER_ENDPOINTS_IMPLEMENTATION.ts` - TypeScript code

---

## Step 1: Update Worker Code

### 1.1 Backup Current Worker
```bash
cd /Users/Parvez/Projects/FareLens/cloudflare-workers
cp src/index.ts src/index.ts.backup
```

### 1.2 Add New Schemas (After line 415)
```typescript
// Copy from USER_ENDPOINTS_IMPLEMENTATION.ts lines 18-78
// Add after existing SupabaseUserSchema
```

**Add these schemas:**
- [ ] `AlertPreferencesUpdateSchema`
- [ ] `PreferredAirportInputSchema`
- [ ] `UserUpdateRequestSchema`
- [ ] `SupabaseUserRowSchema`

### 1.3 Add Transformation Functions (After line 457)
```typescript
// Copy from USER_ENDPOINTS_IMPLEMENTATION.ts lines 89-158
```

**Add these functions:**
- [ ] `transformSupabaseUserToAPI()`
- [ ] `transformAPIUserToSupabase()`

### 1.4 Add Validation Functions (After transformation functions)
```typescript
// Copy from USER_ENDPOINTS_IMPLEMENTATION.ts lines 166-235
```

**Add these functions:**
- [ ] `validateTierLimits()`
- [ ] `validateAirportWeights()`
- [ ] `validateNoDuplicateAirports()`

### 1.5 Replace handleUser() Function (Lines 978-1075)
```typescript
// DELETE lines 978-1075 (old handleUser implementation)
// Copy from USER_ENDPOINTS_IMPLEMENTATION.ts lines 247-398
```

**Replace with:**
- [ ] `handleGetUser()`
- [ ] `handlePatchUser()`
- [ ] `handleUser()` (main router)

### 1.6 Update Routing (Lines 84-96)
```typescript
// REPLACE lines 85-96 with:

// Alert preferences endpoints (keep for backwards compatibility)
if (path === '/api/alert-preferences' || path === '/alert-preferences') {
  if (request.method === 'GET') {
    return await handleGetAlertPreferences(request, env);
  } else if (request.method === 'PUT') {
    return await handlePutAlertPreferences(request, env);
  }
  return jsonResponse({ error: 'Method not allowed' }, 405, {}, env);
}

if (path === '/api/alert-preferences/airports' || path === '/alert-preferences/airports') {
  if (request.method === 'PUT') {
    return await handlePutPreferredAirports(request, env);
  }
  return jsonResponse({ error: 'Method not allowed' }, 405, {}, env);
}

// User endpoint (new consolidated endpoint)
if (path === '/api/user' || path === '/user') {
  return await handleUser(request, env);
}
```

### 1.7 Add Backwards Compatibility Handlers (After handleUser)
```typescript
// Copy from USER_ENDPOINTS_IMPLEMENTATION.ts lines 410-501
```

**Add these functions:**
- [ ] `handleGetAlertPreferences()`
- [ ] `handlePutAlertPreferences()`
- [ ] `handlePutPreferredAirports()`

### 1.8 Remove Old Implementations
```typescript
// DELETE old alert preferences implementation (lines 785-876)
// DELETE old preferred airports implementation (lines 882-972)
```

**Remove:**
- [ ] Old `handleAlertPreferences()` function
- [ ] Old `handlePreferredAirports()` function

---

## Step 2: Verify Worker Code

### 2.1 Type Check
```bash
cd /Users/Parvez/Projects/FareLens/cloudflare-workers
npx tsc --noEmit
```

**Expected:** No type errors
- [ ] No TypeScript errors

### 2.2 Lint
```bash
npm run lint
```

**Expected:** Pass (or only warnings)
- [ ] Linting passes

### 2.3 Review Changes
```bash
git diff src/index.ts
```

**Verify:**
- [ ] New schemas added
- [ ] New transformation functions added
- [ ] New validation functions added
- [ ] handleUser() replaced
- [ ] Routing updated
- [ ] Backwards compatibility handlers added
- [ ] Old implementations removed

---

## Step 3: Test Locally

### 3.1 Start Local Worker
```bash
cd /Users/Parvez/Projects/FareLens/cloudflare-workers
npm run dev
```

**Expected:** Worker starts on http://localhost:8787
- [ ] Worker starts without errors

### 3.2 Get JWT Token
```bash
# Option 1: From iOS app (copy from network inspector)
# Option 2: From Supabase dashboard (SQL editor)
SELECT auth.sign(
  payload := json_build_object(
    'sub', '<user-uuid>',
    'role', 'authenticated'
  ),
  secret := '<supabase-jwt-secret>'
);
```

- [ ] JWT token obtained

### 3.3 Test GET /user
```bash
curl -H "Authorization: Bearer <jwt>" \
  http://localhost:8787/user | jq
```

**Expected response:**
```json
{
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "timezone": "...",
    "subscription_tier": "free" | "pro",
    "alert_preferences": { ... },
    "preferred_airports": [ ... ]
  }
}
```

**Verify:**
- [ ] 200 OK status
- [ ] User object returned
- [ ] alert_preferences nested correctly
- [ ] preferred_airports array present
- [ ] No TypeScript runtime errors

### 3.4 Test PATCH /user (Timezone)
```bash
curl -X PATCH \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{"timezone":"America/New_York"}' \
  http://localhost:8787/user | jq
```

**Expected:**
- [ ] 200 OK status
- [ ] timezone updated to "America/New_York"
- [ ] Other fields unchanged

### 3.5 Test PATCH /user (Alert Preferences)
```bash
curl -X PATCH \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_preferences": {
      "quiet_hours_enabled": false
    }
  }' \
  http://localhost:8787/user | jq
```

**Expected:**
- [ ] 200 OK status
- [ ] alert_preferences.quiet_hours_enabled = false
- [ ] Other alert_preferences fields unchanged

### 3.6 Test PATCH /user (Preferred Airports - Valid)
```bash
curl -X PATCH \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "preferred_airports": [
      {"iata": "LAX", "weight": 1.0}
    ]
  }' \
  http://localhost:8787/user | jq
```

**Expected:**
- [ ] 200 OK status
- [ ] preferred_airports updated
- [ ] UUIDs generated for airports
- [ ] weight = 1.0

### 3.7 Test PATCH /user (Weight Validation - Invalid)
```bash
curl -X PATCH \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{
    "preferred_airports": [
      {"iata": "LAX", "weight": 0.5},
      {"iata": "JFK", "weight": 0.3}
    ]
  }' \
  http://localhost:8787/user | jq
```

**Expected:**
- [ ] 400 Bad Request status
- [ ] Error: "Airport weights must sum to 1.0 (current: 0.800)"

### 3.8 Test PATCH /user (Tier Limit - Free)
```bash
# Requires user to be on Free tier
curl -X PATCH \
  -H "Authorization: Bearer <jwt-free-user>" \
  -H "Content-Type: application/json" \
  -d '{
    "preferred_airports": [
      {"iata": "LAX", "weight": 0.5},
      {"iata": "JFK", "weight": 0.5}
    ]
  }' \
  http://localhost:8787/user | jq
```

**Expected:**
- [ ] 403 Forbidden status
- [ ] Error: "free tier allows maximum 1 preferred airport(s)"
- [ ] upgrade_required: true

### 3.9 Test PATCH /user (Pro Feature on Free)
```bash
# Requires user to be on Free tier
curl -X PATCH \
  -H "Authorization: Bearer <jwt-free-user>" \
  -H "Content-Type: application/json" \
  -d '{
    "alert_preferences": {
      "watchlist_only_mode": true
    }
  }' \
  http://localhost:8787/user | jq
```

**Expected:**
- [ ] 403 Forbidden status
- [ ] Error: "Watchlist-only mode is a Pro feature..."
- [ ] upgrade_required: true

### 3.10 Test Backwards Compatibility (GET /alert-preferences)
```bash
curl -H "Authorization: Bearer <jwt>" \
  http://localhost:8787/alert-preferences | jq
```

**Expected:**
- [ ] 200 OK status
- [ ] alert_preferences object returned
- [ ] Header: X-Deprecated present

### 3.11 Test Backwards Compatibility (PUT /alert-preferences)
```bash
curl -X PUT \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{"quiet_hours_enabled": false}' \
  http://localhost:8787/alert-preferences | jq
```

**Expected:**
- [ ] 200 OK status
- [ ] alert_preferences updated
- [ ] Header: X-Deprecated present

---

## Step 4: Update iOS (Optional - Add GET /user)

### 4.1 Add GET /user Endpoint
```swift
// In APIEndpoint.swift, add:
static func getUser() -> APIEndpoint {
    APIEndpoint(
        path: "/user",
        method: .get
    )
}
```

### 4.2 Update User Fetch Logic
```swift
// In AuthService.swift or UserService.swift
func fetchCurrentUser() async throws -> User {
    let endpoint = APIEndpoint.getUser()
    let response = try await apiClient.request(endpoint)
    let userData = try JSONDecoder().decode(
        UserResponse.self,
        from: response
    )
    return userData.user
}
```

### 4.3 Test iOS Integration
- [ ] iOS can fetch user with GET /user
- [ ] iOS can update timezone with PATCH /user
- [ ] iOS can update alert preferences
- [ ] iOS can update preferred airports

---

## Step 5: Deploy to Production

### 5.1 Commit Changes
```bash
cd /Users/Parvez/Projects/FareLens
git add cloudflare-workers/src/index.ts
git commit -m "feat: Implement consolidated /user endpoint with tier validation

- Add GET /user endpoint (fetch complete user profile)
- Add PATCH /user endpoint (update timezone, alert_preferences, preferred_airports)
- Transform between iOS nested format and Supabase flat schema
- Validate tier limits (Free=1 airport, Pro=3 airports)
- Validate airport weights sum to 1.0
- Validate Pro-only features (watchlist_only_mode)
- Add backwards compatibility for deprecated endpoints
- Add comprehensive error messages

Fixes: Schema mismatches identified by Codex
- iOS expects GET /alert-preferences → Now supported via GET /user
- iOS sends PreferredAirport objects → Now correctly validated
- iOS tries to update timezone → Now supported via PATCH /user"
```

- [ ] Changes committed

### 5.2 Deploy Worker
```bash
cd /Users/Parvez/Projects/FareLens/cloudflare-workers
npm run deploy
```

**Expected:** Deployment succeeds
- [ ] Worker deployed successfully
- [ ] Deployment URL logged

### 5.3 Verify Production GET /user
```bash
curl -H "Authorization: Bearer <production-jwt>" \
  https://api.farelens.com/user | jq
```

- [ ] Production GET /user works

### 5.4 Verify Production PATCH /user
```bash
curl -X PATCH \
  -H "Authorization: Bearer <production-jwt>" \
  -H "Content-Type: application/json" \
  -d '{"timezone":"America/New_York"}' \
  https://api.farelens.com/user | jq
```

- [ ] Production PATCH /user works

---

## Step 6: Monitor and Validate

### 6.1 Check Cloudflare Dashboard
- [ ] No 5xx errors in last hour
- [ ] Response time < 500ms (p95)
- [ ] All requests succeeding

### 6.2 Test from iOS App
- [ ] Fetch user profile works
- [ ] Update timezone persists
- [ ] Update alert preferences persists
- [ ] Update preferred airports validates weights

### 6.3 Verify Database State
```sql
-- In Supabase SQL editor
SELECT
  id,
  email,
  timezone,
  subscription_tier,
  alert_enabled,
  quiet_hours_enabled,
  quiet_hours_start,
  quiet_hours_end,
  watchlist_only_mode,
  preferred_airports
FROM users
WHERE id = '<test-user-uuid>';
```

- [ ] Timezone updated correctly
- [ ] Alert preferences flattened correctly
- [ ] Preferred airports stored as JSONB array

---

## Step 7: Deprecation Notice (Optional)

### 7.1 Add Deprecation Warnings to iOS
```swift
// In APIEndpoint.swift, mark old endpoints as deprecated
@available(*, deprecated, message: "Use getUser() instead")
static func getAlertPreferences() -> APIEndpoint { ... }

@available(*, deprecated, message: "Use updateUser() instead")
static func updateAlertPreferences() -> APIEndpoint { ... }

@available(*, deprecated, message: "Use updateUser() instead")
static func updatePreferredAirports() -> APIEndpoint { ... }
```

### 7.2 Update iOS to Use New Endpoints
- [ ] Replace GET /alert-preferences with GET /user
- [ ] Replace PUT /alert-preferences with PATCH /user
- [ ] Replace PUT /alert-preferences/airports with PATCH /user

### 7.3 Remove Old Endpoints from Worker (After iOS Migration)
```typescript
// After all iOS users migrate (6 months), remove:
// - handleGetAlertPreferences()
// - handlePutAlertPreferences()
// - handlePutPreferredAirports()
```

---

## Rollback Plan

### If Issues Found in Production

1. **Rollback Worker:**
   ```bash
   cd /Users/Parvez/Projects/FareLens/cloudflare-workers
   git revert HEAD
   npm run deploy
   ```

2. **Restore Backup:**
   ```bash
   cp src/index.ts.backup src/index.ts
   npm run deploy
   ```

3. **Check Logs:**
   - Cloudflare dashboard → Logs
   - Identify error pattern
   - Fix and redeploy

---

## Success Criteria

All checkboxes marked:
- [ ] Worker code updated (Steps 1-2)
- [ ] Local tests pass (Step 3)
- [ ] iOS integration works (Step 4)
- [ ] Production deployment successful (Step 5)
- [ ] Monitoring shows no errors (Step 6)

**Schema mismatches resolved:**
- ✅ Alert preferences: GET now supported via GET /user
- ✅ Preferred airports: Objects correctly validated and transformed
- ✅ User timezone: PATCH /user now updates timezone field

---

## Files Reference

| File | Purpose |
|------|---------|
| `USER_ENDPOINTS_SUMMARY.md` | Answers to questions, quick reference |
| `WORKER_USER_ENDPOINTS.md` | Complete endpoint specification (19KB) |
| `USER_API_REFERENCE.md` | Quick API reference card |
| `USER_ENDPOINTS_IMPLEMENTATION.ts` | TypeScript implementation (19KB) |
| `INTEGRATION_CHECKLIST.md` | This file - step-by-step integration |

---

## Support

**If issues encountered:**
1. Check Cloudflare logs for Worker errors
2. Check Supabase logs for database errors
3. Verify JWT token is valid (not expired)
4. Verify RLS policies allow user updates
5. Review transformation logic (console.log debug)

**Common issues:**
- "User not found" → JWT user_id doesn't exist in users table
- "Permission denied" → RLS policy blocking update
- "Invalid weight sum" → Floating point precision issue
- "Tier limit exceeded" → User on Free tier, trying Pro features
