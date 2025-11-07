"""User endpoints."""

from fastapi import APIRouter, Depends

from ..models.schemas import APNsRegistration, User, UserUpdate
from ..services.data_provider import DataProvider
from ..services.provider_factory import get_data_provider

router = APIRouter(prefix="/user", tags=["user"])


@router.patch("/", response_model=User)
async def update_user(
    payload: UserUpdate,
    provider: DataProvider = Depends(
        get_data_provider
    ),  # noqa: ARG001 - provider reserved for future use
) -> User:
    user = _mock_user()
    if payload.timezone:
        user = user.model_copy(update={"timezone": payload.timezone})
    return user


@router.post("/apns-token")
async def register_apns_token(
    payload: APNsRegistration,
    provider: DataProvider = Depends(get_data_provider),
) -> dict:
    # Store tokens keyed by a synthetic device id.
    device_id = _mock_user().id
    await provider.register_device_token(
        device_id,
        payload.token,
        payload.platform,
    )
    return {
        "status": "registered",
        "device_id": str(device_id),
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
