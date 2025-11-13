"""Authentication endpoints (see API.md section 1)."""

import os
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Request, status
from slowapi import Limiter
from slowapi.util import get_remote_address

from ..models.schemas import (
    AuthRequest,
    AuthResponse,
    ResetPasswordRequest,
    SubscriptionInfo,
    User,
)

router = APIRouter(prefix="/auth", tags=["auth"])

# Rate limiter to prevent brute force attacks and spam
# Production: Requires REDIS_URL environment variable for distributed deployments
# Development: Use REDIS_URL=memory:// for local testing (single instance only)
# WARNING: memory:// storage is NOT shared across instances - use Redis in production
redis_url = os.getenv("REDIS_URL")
if not redis_url:
    raise RuntimeError(
        "REDIS_URL environment variable is required for rate limiting. "
        "Set REDIS_URL=memory:// for development (single instance) or "
        "REDIS_URL=redis://host:port for production (distributed)."
    )
limiter = Limiter(key_func=get_remote_address, storage_uri=redis_url)


def _mock_user(email: str) -> User:
    now = datetime.now(timezone.utc)
    return User(
        id=uuid4(),
        email=email,
        subscription_tier="free",
        timezone="America/Los_Angeles",
        created_at=now,
        subscription=SubscriptionInfo(
            tier="free",
            max_watchlists=5,
            max_alerts_per_day=3,
            trial_ends_at=now + timedelta(days=14),
        ),
    )


@router.post(
    "/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED
)
@limiter.limit("5/hour")  # Prevent spam account creation
async def signup(request: Request, payload: AuthRequest) -> AuthResponse:
    """Create a new account and return JWT (placeholder implementation).

    Rate limit: 5 requests per hour to prevent spam account creation.
    """
    user = _mock_user(payload.email)
    token = f"mock-signup-token-{user.id}"
    return AuthResponse(user=user, token=token)


@router.post("/signin", response_model=AuthResponse)
@limiter.limit("10/minute")  # Prevent brute force attacks
async def signin(request: Request, payload: AuthRequest) -> AuthResponse:
    """Authenticate user and return JWT (placeholder implementation).

    Rate limit: 10 requests/minute per IP to prevent brute force attacks.

    Note: Per-email rate limiting would provide additional protection against
    distributed attacks but requires middleware to cache request body.
    TODO: Add per-email rate limiting when implementing request body caching middleware.
    """
    user = _mock_user(payload.email)
    token = f"mock-signin-token-{user.id}"
    return AuthResponse(user=user, token=token)


@router.post("/reset-password", status_code=status.HTTP_202_ACCEPTED)
@limiter.limit("3/hour")  # Prevent email bombing
async def reset_password(request: Request, payload: ResetPasswordRequest) -> dict:
    """Send password reset email (mock).

    Rate limit: 3 requests per hour to prevent email bombing and abuse.
    Note: Email validation handled by Pydantic (EmailStr type) - no manual check needed.
    """
    return {
        "status": "accepted",
        "message": "Password reset instructions sent",
    }
