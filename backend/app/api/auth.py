"""Authentication endpoints (see API.md section 1)."""

from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, HTTPException, status

from ..models.schemas import (
    AuthRequest,
    AuthResponse,
    ResetPasswordRequest,
    SubscriptionInfo,
    User,
)

router = APIRouter(prefix="/auth", tags=["auth"])


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
            trial_ends_at=now + (60 * 60 * 24 * 14),
        ),
    )


@router.post(
    "/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED
)
async def signup(payload: AuthRequest) -> AuthResponse:
    """Create a new account and return JWT (placeholder implementation)."""
    user = _mock_user(payload.email)
    token = f"mock-signup-token-{user.id}"
    return AuthResponse(user=user, token=token)


@router.post("/signin", response_model=AuthResponse)
async def signin(payload: AuthRequest) -> AuthResponse:
    """Authenticate user and return JWT (placeholder implementation)."""
    user = _mock_user(payload.email)
    token = f"mock-signin-token-{user.id}"
    return AuthResponse(user=user, token=token)


@router.post("/reset-password", status_code=status.HTTP_202_ACCEPTED)
async def reset_password(payload: ResetPasswordRequest) -> dict:
    """Send password reset email (mock)."""
    if not payload.email:
        raise HTTPException(status_code=400, detail="Email required")
    return {"status": "accepted", "message": "Password reset instructions sent"}
