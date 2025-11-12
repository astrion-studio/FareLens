"""Authentication endpoints (see API.md section 1)."""

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
# Uses in-memory storage by default (can be upgraded to Redis for production)
limiter = Limiter(key_func=get_remote_address)


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

    Rate limit: 10 requests per minute to prevent brute force attacks while allowing retries.
    """
    user = _mock_user(payload.email)
    token = f"mock-signin-token-{user.id}"
    return AuthResponse(user=user, token=token)


@router.post("/reset-password", status_code=status.HTTP_202_ACCEPTED)
@limiter.limit("3/hour")  # Prevent email bombing
async def reset_password(request: Request, payload: ResetPasswordRequest) -> dict:
    """Send password reset email (mock).

    Rate limit: 3 requests per hour to prevent email bombing and abuse.
    """
    if not payload.email:
        raise HTTPException(status_code=400, detail="Email required")
    return {
        "status": "accepted",
        "message": "Password reset instructions sent",
    }
