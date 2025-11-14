"""User endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends

from ..core.auth import get_current_user_id
from ..models.schemas import User, UserUpdate
from ..services.data_provider import DataProvider
from ..services.provider_factory import get_data_provider

router = APIRouter(prefix="/user", tags=["user"])


@router.patch("/", response_model=User)
async def update_user(
    payload: UserUpdate,
    user_id: UUID = Depends(get_current_user_id),
    provider: DataProvider = Depends(get_data_provider),
) -> User:
    """Update user settings for authenticated user only.

    Security: Requires JWT authentication, prevents unauthorized access.
    """
    try:
        return await provider.update_user(user_id, payload)
    except KeyError:
        # User not found in database, return mock for now
        # This will be removed once authentication is fully implemented
        user = _mock_user()
        if payload.timezone:
            user = user.model_copy(update={"timezone": payload.timezone})
        return user


# Duplicate endpoint removed - use POST /v1/alerts/register instead
# The /apns-token endpoint was redundant with /alerts/register (same functionality)
# Keeping only the canonical endpoint defined in API.md


def _mock_user() -> User:
    from datetime import datetime, timezone
    from uuid import uuid4

    return User(
        id=uuid4(),
        email="mock@farelens.com",
        subscription_tier="free",
        timezone="America/Los_Angeles",
        created_at=datetime.now(timezone.utc),
    )
