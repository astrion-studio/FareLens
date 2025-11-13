"""User endpoints."""

from uuid import UUID

from fastapi import APIRouter, Depends

from ..core.auth import get_current_user_id
from ..models.schemas import DeviceRegistrationRequest, User, UserUpdate
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
    Note: Currently returns mock data - real implementation pending.
    """
    # TODO: Implement real user update logic when user service is added
    user = _mock_user()
    if payload.timezone:
        user = user.model_copy(update={"timezone": payload.timezone})
    return user


@router.post("/apns-token")
async def register_apns_token(
    payload: DeviceRegistrationRequest,
    user_id: UUID = Depends(get_current_user_id),
    provider: DataProvider = Depends(get_data_provider),
) -> dict:
    """Register APNS device token for authenticated user.

    Security: Associates device with authenticated user for push notifications.
    Prevents unauthorized device registrations and ensures notifications go to correct user.
    """
    await provider.register_device_token(
        user_id=user_id,
        device_id=payload.device_id,
        token=payload.token,
        platform=payload.platform,
    )
    return {
        "status": "registered",
        "device_id": str(payload.device_id),
    }


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
