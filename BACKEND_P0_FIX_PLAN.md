# Backend P0 Security Fixes - Completion Plan

## Status: CRITICAL - 9 New P0 Vulnerabilities Found

Backend-architect agent conducted security audit and found that initial P0 fixes (commit 1cb8c4c) were **INCOMPLETE** with multiple new critical vulnerabilities introduced.

## What Was Fixed Correctly (3/5)

✅ **P0-4:** SQL injection in update_watchlist - Column whitelist properly implemented
✅ **P0-6:** alert_preferences table - Now correctly uses users table columns
✅ **P0-7:** preferred_airports table - Now correctly uses users.preferred_airports JSONB

## What Was Incompletely Fixed (2/5)

⚠️ **P0-5:** Authentication
- ✅ Fixed: /alerts/register, /alerts/history, /alert-preferences endpoints
- ❌ Missing: /watchlists/* endpoints, /user/* endpoints

⚠️ **P0-8:** user_id filtering
- ✅ Fixed: SupabaseProvider (list_watchlists, list_alert_history)
- ❌ Missing: InMemoryProvider (list_alert_history doesn't filter)

## New P0 Vulnerabilities Introduced (9)

### Critical - Authentication Missing

1. **POST /watchlists** - Creates watchlists with RANDOM user_id
   - File: backend/app/api/watchlists.py:32-36
   - Impact: Watchlists not associated with correct user

2. **PUT /watchlists/{id}** - NO authentication, IDOR vulnerability
   - File: backend/app/api/watchlists.py:40-51
   - Impact: Any user can update any watchlist

3. **DELETE /watchlists/{id}** - NO authentication, IDOR vulnerability
   - File: backend/app/api/watchlists.py:54-59
   - Impact: Any user can delete any watchlist

4. **PATCH /user** - NO authentication
   - File: backend/app/api/user.py:12-22
   - Impact: Returns mock data, would be P0 with real data

5. **POST /user/apns-token** - NO authentication
   - File: backend/app/api/user.py:25-40
   - Impact: Device tokens not linked to correct user

### Critical - Interface/Implementation Bugs

6. **DataProvider.create_watchlist()** - FIXED ✅
   - Missing user_id parameter in interface
   - Fixed in commit being prepared

7. **DataProvider.update_watchlist()** - FIXED ✅
   - Missing user_id parameter for ownership validation
   - Fixed in commit being prepared

8. **DataProvider.delete_watchlist()** - FIXED ✅
   - Missing user_id parameter for ownership validation
   - Fixed in commit being prepared

9. **append_alert()** - FIXED ✅
   - Missing user_id in INSERT, violates NOT NULL constraint
   - Fixed in interface, implementations need updating

10. **register_device_token() call** - Wrong arguments
    - File: backend/app/api/user.py:32-35
    - Impact: Will crash at runtime with TypeError

## Fix Plan (Priority Order)

### Phase 1: Interface & Core Fixes (IN PROGRESS)

✅ **Step 1:** Fix DataProvider interface (DONE)
- Added user_id parameter to create_watchlist()
- Added user_id parameter to update_watchlist()
- Added user_id parameter to delete_watchlist()
- Added user_id parameter to append_alert()
- Added comprehensive docstrings

### Phase 2: Update Provider Implementations (NEXT)

⬜ **Step 2:** Update SupabaseProvider to match interface
- create_watchlist(): Use user_id parameter, not random UUID
- update_watchlist(): Add WHERE user_id = $X for ownership check
- delete_watchlist(): Add WHERE user_id = $X for ownership check
- append_alert(): Include user_id in INSERT statement

⬜ **Step 3:** Update InMemoryProvider to match interface
- create_watchlist(): Use user_id parameter
- update_watchlist(): Validate ownership before updating
- delete_watchlist(): Validate ownership before deleting
- append_alert(): Include user_id in alert storage
- list_alert_history(): Filter by user_id

### Phase 3: Add Authentication to Endpoints

⬜ **Step 4:** Add auth to watchlists endpoints
File: backend/app/api/watchlists.py

```python
# Line 32 - POST /watchlists
@router.post("/", ...)
async def create_watchlist(
    payload: WatchlistCreate,
    user_id: UUID = Depends(get_current_user_id),  # ADD THIS
    provider: DataProvider = Depends(get_data_provider),
) -> Watchlist:
    return await provider.create_watchlist(user_id, payload)  # PASS user_id

# Line 40 - PUT /watchlists/{id}
@router.put("/{watchlist_id}", ...)
async def update_watchlist(
    watchlist_id: UUID,
    payload: WatchlistUpdate,
    user_id: UUID = Depends(get_current_user_id),  # ADD THIS
    provider: DataProvider = Depends(get_data_provider),
) -> Watchlist:
    return await provider.update_watchlist(user_id, watchlist_id, payload)  # PASS user_id

# Line 54 - DELETE /watchlists/{id}
@router.delete("/{watchlist_id}", ...)
async def delete_watchlist(
    watchlist_id: UUID,
    user_id: UUID = Depends(get_current_user_id),  # ADD THIS
    provider: DataProvider = Depends(get_data_provider),
) -> None:
    await provider.delete_watchlist(user_id, watchlist_id)  # PASS user_id
```

⬜ **Step 5:** Add auth to user endpoints
File: backend/app/api/user.py

```python
# Line 12 - PATCH /user
@user_router.patch("", ...)
async def update_user(
    payload: UserUpdate,
    user_id: UUID = Depends(get_current_user_id),  # ADD THIS
    provider: DataProvider = Depends(get_data_provider),
) -> User:
    # Remove _mock_user() - use real user_id
    # Implement real user update logic

# Line 25 - POST /user/apns-token
@user_router.post("/apns-token", ...)
async def register_apns_token(
    payload: APNsRegistration,
    user_id: UUID = Depends(get_current_user_id),  # ADD THIS
    provider: DataProvider = Depends(get_data_provider),
) -> dict:
    await provider.register_device_token(
        user_id,          # FIX: Add user_id as first argument
        payload.device_id,
        payload.token,
        payload.platform,
    )
```

### Phase 4: Update Tests

⬜ **Step 6:** Create JWT token helper for tests
File: backend/tests/conftest.py (new or update)

```python
import jwt
from datetime import datetime, timedelta
from uuid import uuid4

def create_test_jwt(user_id: str = None) -> str:
    """Generate a valid JWT token for testing."""
    if user_id is None:
        user_id = str(uuid4())

    payload = {
        "sub": user_id,
        "exp": datetime.utcnow() + timedelta(hours=1),
        "iat": datetime.utcnow(),
    }

    # Use test secret (same as FARELENS_SUPABASE_JWT_SECRET in test env)
    secret = "test-jwt-secret-key"
    return jwt.encode(payload, secret, algorithm="HS256")
```

⬜ **Step 7:** Update all test files to use authentication
Files:
- backend/tests/test_watchlists.py
- backend/tests/test_alerts.py
- backend/tests/test_user.py

Add to all requests:
```python
headers = {"Authorization": f"Bearer {create_test_jwt()}"}
response = client.post("/v1/watchlists", json=payload, headers=headers)
```

### Phase 5: Verification

⬜ **Step 8:** Run all tests
```bash
cd backend
pytest tests/ -v
```

All tests should pass with authentication properly enforced.

⬜ **Step 9:** Manual security testing
```bash
# Try to access without auth - should get 401
curl http://localhost:8000/v1/watchlists

# Try to update someone else's watchlist - should get 404
curl -X PUT http://localhost:8000/v1/watchlists/{other-user-id} \
  -H "Authorization: Bearer {your-token}" \
  -d '{"name": "hacked"}'
```

⬜ **Step 10:** Code review with agent
Use code-reviewer agent to verify all fixes are complete and no new vulnerabilities introduced.

## Files Requiring Changes

### Must Change (Interface & Implementations)
- ✅ backend/app/services/data_provider.py (DONE - interface fixed)
- ⬜ backend/app/services/supabase_provider.py (update implementations)
- ⬜ backend/app/services/inmemory_provider.py (update implementations)

### Must Change (API Endpoints)
- ⬜ backend/app/api/watchlists.py (add auth to 3 endpoints)
- ⬜ backend/app/api/user.py (add auth to 2 endpoints, fix call)

### Must Change (Tests)
- ⬜ backend/tests/conftest.py (add JWT helper)
- ⬜ backend/tests/test_watchlists.py (add auth headers)
- ⬜ backend/tests/test_alerts.py (add auth headers)
- ⬜ backend/tests/test_user.py (add auth headers)

## Bandaid Solutions to Remove

1. **Mock user functions** (backend/app/api/user.py)
   - Lines 43-53: _mock_user() returns fake data
   - Replace with real user lookup

2. **Comments admitting incompleteness** (backend/app/services/inmemory_provider.py)
   - Line 152-153: "In-memory provider doesn't track user_id per alert in demo"
   - Fix the actual code, don't just comment about it

3. **Tests without authentication**
   - All test files assume endpoints work without auth
   - This masks security vulnerabilities

## Security Impact Summary

**Current Status:** CRITICAL - Backend has multiple IDOR vulnerabilities

**Risk Level:**
- Any authenticated user can create/update/delete ANY watchlist
- Device tokens not associated with correct users (push notifications broken)
- Tests don't enforce security (false sense of security)
- Database constraints will be violated (crashes)

**Timeline:** These must be fixed before ANY deployment.

**Next Steps:**
1. Complete Phase 2-5 as outlined above
2. Get code review from backend-architect and code-reviewer agents
3. Deploy ONLY after all P0 fixes are verified complete
