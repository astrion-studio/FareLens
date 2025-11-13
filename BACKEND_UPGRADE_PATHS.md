# Backend Upgrade Paths & Future Improvements

**Reference:** Recommendations from BACKEND_REVIEW.md
**Timeline:** Phase 1 (MVP) → Phase 2 (10K+ users) → Phase 3 (50K+ users)

---

## Fix #2: TypedDict Upgrade Path (Priority: Medium)

**Current Status:** Uses `Dict[str, Any]` (acceptable for MVP)

**Why upgrade:** Better type checking, IDE support, self-documenting code

### Step 1: Create TypedDict

**File:** `/Users/Parvez/Projects/FareLens/backend/app/models/schemas.py`

```python
# Add to imports (after line 7):
from typing_extensions import TypedDict

# Add new class (after line 11):
class PreferredAirportDict(TypedDict):
    """Type definition for preferred airport data structure."""
    iata: str
    weight: float
```

### Step 2: Update InMemoryProvider

**File:** `/Users/Parvez/Projects/FareLens/backend/app/services/inmemory_provider.py`

```python
# Change line 6 import:
from typing import Any, Dict, List, Optional, Tuple
# To:
from typing import Dict, List, Optional, Tuple

# Change line 33:
self._preferred_airports: Dict[UUID, List[Dict[str, Any]]] = {}
# To:
self._preferred_airports: Dict[UUID, List[PreferredAirportDict]] = {}

# Add import at top (line 10):
from ..models.schemas import (
    # ... existing imports ...
    PreferredAirportDict,  # <- ADD THIS
)
```

### Step 3: Verify No Breaking Changes

```bash
# Type check
mypy app/services/inmemory_provider.py

# Tests still pass
pytest tests/ -v
```

**Migration effort:** 10 minutes | **Risk:** None (backward compatible)

---

## Validation Tests (Priority: High)

**Current Status:** Basic happy-path tests exist
**Why needed:** Ensure auth is actually enforced, not just in tests

### Add to test_watchlists.py

```python
# Add new test function (after test_watchlist_crud_flow):

def test_watchlist_requires_auth():
    """Verify watchlist endpoint rejects requests without JWT token."""
    # Temporarily remove auth override to test real behavior
    from app.core.auth import get_current_user_id
    app.dependency_overrides.clear()

    # Should fail with 403 Forbidden
    response = client.get("/v1/watchlists")
    assert response.status_code == 403

    # Restore override for remaining tests
    app.dependency_overrides[get_current_user_id] = override_get_current_user_id


def test_create_watchlist_validates_inputs():
    """Verify POST validates required fields."""
    # Missing required field: origin
    payload = {
        "name": "Test",
        "destination": "CDG",
    }
    response = client.post("/v1/watchlists", json=payload)
    assert response.status_code == 422  # Validation error


def test_watchlist_update_prevents_idor():
    """Verify users can't update other users' watchlists."""
    # Create watchlist with TEST_USER_ID
    initial = client.post(
        "/v1/watchlists",
        json={
            "name": "User A Watchlist",
            "origin": "SFO",
            "destination": "CDG",
        }
    )
    watchlist_id = initial.json()["id"]

    # Try to update with different user ID
    other_user = uuid4()
    app.dependency_overrides[get_current_user_id] = lambda: other_user

    response = client.put(
        f"/v1/watchlists/{watchlist_id}",
        json={"max_price": 999}
    )
    assert response.status_code == 404  # User can't see other's watchlist

    # Restore original user
    app.dependency_overrides[get_current_user_id] = override_get_current_user_id
```

**Testing effort:** 30 minutes | **Coverage gain:** +3 edge cases

---

## Structured Error Codes (Priority: Medium)

**Current Status:** Basic HTTP errors
**Why needed:** iOS client needs consistent error structure for handling

### Step 1: Create Error Schema

**File:** `/Users/Parvez/Projects/FareLens/backend/app/models/schemas.py`

```python
# Add after line 179:

class ErrorCode:
    """Error code constants for API responses."""
    VALIDATION_ERROR = "VALIDATION_ERROR"
    AUTHENTICATION_REQUIRED = "AUTHENTICATION_REQUIRED"
    FORBIDDEN = "FORBIDDEN"
    WATCHLIST_NOT_FOUND = "WATCHLIST_NOT_FOUND"
    DEVICE_ALREADY_REGISTERED = "DEVICE_ALREADY_REGISTERED"
    RATE_LIMITED = "RATE_LIMITED"
    INTERNAL_SERVER_ERROR = "INTERNAL_SERVER_ERROR"


class ErrorResponse(BaseModel):
    """Structured error response for API failures."""
    code: str = Field(..., description="Machine-readable error code")
    message: str = Field(..., description="Human-readable error message")
    details: Optional[dict] = Field(None, description="Additional context")
    timestamp: datetime = Field(default_factory=datetime.utcnow)
```

### Step 2: Update Watchlist Error Handling

**File:** `/Users/Parvez/Projects/FareLens/backend/app/api/watchlists.py`

```python
# Replace line 60-64:
try:
    return await provider.update_watchlist(
        user_id=user_id, watchlist_id=watchlist_id, payload=payload
    )
except KeyError as exc:
    raise HTTPException(
        status_code=404,
        detail="Watchlist not found",
    ) from exc

# With:
from ..models.schemas import ErrorCode, ErrorResponse

try:
    return await provider.update_watchlist(
        user_id=user_id, watchlist_id=watchlist_id, payload=payload
    )
except KeyError as exc:
    error = ErrorResponse(
        code=ErrorCode.WATCHLIST_NOT_FOUND,
        message="Watchlist not found or not owned by user",
        details={"watchlist_id": str(watchlist_id)}
    )
    raise HTTPException(
        status_code=404,
        detail=error.model_dump()
    ) from exc
```

### Step 3: iOS Client Handling

**iOS integration example:**

```swift
// Safely decode error response
if let data = error.response?.data,
   let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
    switch errorResponse.code {
    case "WATCHLIST_NOT_FOUND":
        showAlert("Watchlist deleted")
    case "AUTHENTICATION_REQUIRED":
        triggerReauth()
    case "RATE_LIMITED":
        showAlert("Too many requests. Please wait a moment.")
    default:
        showAlert(errorResponse.message)
    }
}
```

**Implementation effort:** 1-2 hours | **Value:** Better error handling for iOS

---

## Debug Logging (Priority: Medium)

**Current Status:** No logging
**Why needed:** Troubleshoot production issues without errors

### Step 1: Add Logging Configuration

**File:** `/Users/Parvez/Projects/FareLens/backend/app/core/logging.py` (new file)

```python
"""Logging configuration for FareLens API."""

import logging
import sys
from pythonjsonlogger import jsonlogger

# Production: JSON logs for log aggregation
# Development: Pretty logs to console


def setup_logging():
    """Configure logging with environment-aware formatting."""
    import os

    # Get logger
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG if os.getenv("DEBUG") else logging.INFO)

    # Remove default handlers
    for handler in logger.handlers[:]:
        logger.removeHandler(handler)

    # Create handlers
    if os.getenv("ENVIRONMENT") == "production":
        # JSON format for production (log aggregation)
        handler = logging.StreamHandler(sys.stdout)
        formatter = jsonlogger.JsonFormatter()
    else:
        # Pretty format for development
        handler = logging.StreamHandler(sys.stdout)
        formatter = logging.Formatter(
            "[%(asctime)s] %(levelname)s [%(name)s] %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S"
        )

    handler.setFormatter(formatter)
    logger.addHandler(handler)

    return logger


logger = setup_logging()
```

### Step 2: Add Logging to Services

**File:** `/Users/Parvez/Projects/FareLens/backend/app/services/inmemory_provider.py`

```python
# Add at top (after imports):
import logging
logger = logging.getLogger(__name__)

# Add logging to key methods:

async def create_watchlist(
    self, user_id: UUID, payload: WatchlistCreate
) -> Watchlist:
    logger.info(f"Creating watchlist for user {user_id}: {payload.name}")
    # ... rest of function ...
    logger.debug(f"Watchlist created: {watchlist.id}")
    return watchlist


async def register_device_token(
    self, user_id: UUID, device_id: UUID, token: str, platform: str
) -> None:
    logger.debug(f"Registering device {device_id} for user {user_id} ({platform})")
    # ... rest of function ...
    logger.info(f"Device registered: user={user_id}, device={device_id}, platform={platform}")
```

### Step 3: Update Main App

**File:** `/Users/Parvez/Projects/FareLens/backend/app/main.py`

```python
# Add import:
from .core.logging import setup_logging

# Call at startup:
setup_logging()

# Add startup event:
@app.on_event("startup")
async def startup():
    logger.info("FareLens API starting up")
```

**Implementation effort:** 1 hour | **Value:** Debugging production issues

---

## Rate Limiting Upgrade Path (Priority: Low for MVP, High for scale)

**Current Status:** slowapi with in-memory storage
**When needed:** At 10K+ users or multiple instances

### Phase 2 Plan: Redis-Backed Rate Limiting

**File:** `/Users/Parvez/Projects/FareLens/backend/app/api/auth.py`

```python
# Replace line 26:
redis_url = os.getenv("REDIS_URL", "memory://")
limiter = Limiter(key_func=get_remote_address, storage_uri=redis_url)

# This already supports Redis! Just set environment variable:
# REDIS_URL=redis://localhost:6379
```

**No code changes needed.** Just set `REDIS_URL` environment variable:

```bash
# Development (in-memory):
export REDIS_URL=memory://

# Staging (Redis Cloud):
export REDIS_URL=redis://:password@host:6379/0

# Production (with Upstash):
export REDIS_URL=redis://:token@host:6379
```

**Implementation effort:** 5 minutes | **Cost:** $5/month (Upstash free tier available)

---

## CORS Hardening (Priority: High for production)

**Current Status:** Allows all origins (line 40)
**When needed:** Before shipping to production

### Update main.py

```python
# Line 40, change:
allow_origins=["*"],  # TODO: Restrict to iOS app domain in production

# To:
allow_origins=[
    "https://farelens.app",  # Production domain
    "http://localhost:3000",  # Local dev only (remove in production)
],
```

**Note:** For native iOS app, CORS doesn't apply (direct HTTP request, not browser). This is for web access only.

**Implementation effort:** 5 minutes | **Security gain:** Prevent unauthorized web access

---

## Migration Checklist for Phase 2 (10K+ users)

When you reach 10K users, execute this migration:

### Week 1: Database Migration

```markdown
- [ ] Provision Supabase PostgreSQL
- [ ] Migrate InMemoryProvider to SupabaseProvider
- [ ] Run data migration (copy existing watchlists/alerts)
- [ ] Test all endpoints with Supabase
- [ ] Rollback plan ready
```

### Week 2: Scalability Hardening

```markdown
- [ ] Enable Redis (Upstash)
- [ ] Update REDIS_URL environment variable
- [ ] Run load tests with redis-backed rate limiting
- [ ] Add database connection pooling (PgBouncer)
- [ ] Monitor query performance (identify slow queries)
```

### Week 3: Monitoring & Observability

```markdown
- [ ] Set up DataDog or New Relic
- [ ] Add structured logging
- [ ] Create alerting rules (CPU >80%, error rate >1%, p95 latency >1s)
- [ ] Set up uptime monitoring
- [ ] Create runbook for common issues
```

---

## Cost Evolution

### MVP Phase (current)

```
Supabase free tier:     $0    (includes Postgres + auth + realtime)
slowapi in-memory:      $0    (built-in)
Total:                  $0/month
```

### Growth Phase (10K users)

```
Supabase Pro:          $25   (50K MAU limit)
Upstash Redis:         $5    (free tier if <10GB)
DataDog APM:           $15   (light monitoring)
Total:                 $45/month
```

### Scale Phase (50K+ users)

```
AWS RDS PostgreSQL:    $50-100  (managed, HA, backups)
Elasticache Redis:     $20      (managed cluster)
Cloudflare Pro:        $20      (rate limiting at edge)
DataDog APM:           $50      (heavy monitoring)
Total:                 $140-190/month
```

---

## Implementation Priority Matrix

| Task | Impact | Effort | When |
|------|--------|--------|------|
| TypedDict upgrade | Medium | 10 min | Phase 2 |
| Validation tests | High | 30 min | Before production |
| Structured errors | High | 2 hours | Phase 2 |
| Debug logging | Medium | 1 hour | Phase 2 |
| Redis rate limiting | Low now, High later | 5 min | Phase 2 |
| CORS hardening | High | 5 min | Before production |
| Database migration | Critical | 1 week | Phase 2 |

---

## Rollback Procedures

### If Rate Limiter Breaks

```bash
# Quickly disable rate limiting:
git revert app/main.py  # Removes rate limit handler
# Then:
# 1. Deploy
# 2. Verify endpoints work
# 3. Investigate slowapi issue
# 4. Redeploy with fix
```

### If TypedDict Upgrade Breaks Types

```bash
# Revert to Dict[str, Any]:
git revert app/services/inmemory_provider.py
# Zero impact on runtime, only on type checking
```

### If Schema Changes Break iOS

```bash
# Add new schema version:
class APNsRegistrationV2(BaseModel):
    device_id: UUID
    token: str
    platform: str

# Support both versions:
@router.post("/apns-token")
async def register_apns_token_v2(payload: APNsRegistrationV2):
    # ...

# Old iOS apps still use /v1/apns-token
# New iOS apps use /v1/apns-token-v2
```

---

## Testing the Upgrades

### TypedDict Test

```python
# Verify no typing issues
mypy app/services/inmemory_provider.py --strict

# Verify runtime still works
provider = InMemoryProvider()
provider._preferred_airports[uuid4()] = [{"iata": "LAX", "weight": 0.6}]
```

### Validation Test

```bash
pytest tests/test_watchlists.py::test_watchlist_requires_auth -v
pytest tests/test_watchlists.py::test_create_watchlist_validates_inputs -v
```

### Logging Test

```python
import logging
logger = logging.getLogger("app.services.inmemory_provider")
logger.setLevel(logging.DEBUG)

# Should see logs
provider.create_watchlist(user_id, payload)
```

### CORS Test

```bash
# Before (should work from any origin):
curl -H "Origin: https://malicious-site.com" http://localhost:8000/health

# After (should fail from unauthorized origins):
curl -H "Origin: https://malicious-site.com" http://localhost:8000/health
```

---

## Questions & Answers

**Q: Should we implement structured errors now or wait for Phase 2?**
A: Implement now if shipping to iOS this month (they need consistent errors). Otherwise, wait for Phase 2 when you have more error scenarios.

**Q: Is TypedDict worth the effort now?**
A: No. Current Dict[str, Any] is fine for MVP. Upgrade in Phase 2 when you have more complex data structures.

**Q: When should we switch from slowapi to Redis?**
A: At 5+ instances or 10K+ MAU. Earlier doesn't help.

**Q: Do we need DataDog from day one?**
A: No. Supabase dashboard is enough for MVP. Add DataDog in Phase 2 when you have real users.

---

## Resources

- FastAPI dependency testing: https://fastapi.tiangolo.com/advanced/testing-dependencies/
- Pydantic TypedDict: https://docs.pydantic.dev/latest/api/types/#pydantic.TypedDict
- slowapi documentation: https://github.com/laurents/slowapi
- Supabase scaling guide: https://supabase.com/docs/guides/scalability
- Python logging: https://docs.python.org/3/library/logging.html
