"""Alert endpoints (API.md section 4)."""

from uuid import UUID

from fastapi import APIRouter, Depends, status

from ..core.auth import get_current_user_id
from ..models.schemas import (
    AlertHistoryResponse,
    AlertPreferences,
    DeviceRegistrationRequest,
    DeviceRegistrationResponse,
    PreferredAirportsUpdate,
)
from ..services.data_provider import DataProvider
from ..services.provider_factory import get_data_provider

alerts_router = APIRouter(prefix="/alerts", tags=["alerts"])
preferences_router = APIRouter(tags=["alerts"])


@alerts_router.post(
    "/register",
    response_model=DeviceRegistrationResponse,
    status_code=status.HTTP_201_CREATED,
)
async def register_device(
    payload: DeviceRegistrationRequest,
    user_id: UUID = Depends(get_current_user_id),
    provider: DataProvider = Depends(get_data_provider),
) -> DeviceRegistrationResponse:
    """Register device for push notifications (requires authentication).

    Security: Only authenticated users can register their own devices.
    The user_id is extracted from the JWT token, preventing unauthorized registration.
    """
    await provider.register_device_token(
        user_id=user_id,
        device_id=payload.device_id,
        token=payload.token,
        platform=payload.platform,
    )
    return DeviceRegistrationResponse(
        status="registered",
        message="Device token saved",
    )


@alerts_router.get("/history", response_model=AlertHistoryResponse)
async def get_history(
    page: int = 1,
    per_page: int = 20,
    user_id: UUID = Depends(get_current_user_id),
    provider: DataProvider = Depends(get_data_provider),
) -> AlertHistoryResponse:
    """Get alert history for authenticated user only.

    Security: Only returns alerts for the authenticated user.
    Prevents users from viewing each other's alert history.
    """
    alerts, total = await provider.list_alert_history(
        user_id=user_id,
        page=page,
        per_page=per_page,
    )
    return AlertHistoryResponse(
        alerts=alerts,
        page=page,
        per_page=per_page,
        total=total,
    )


@preferences_router.put("/alert-preferences", response_model=AlertPreferences)
async def update_alert_preferences(
    payload: AlertPreferences,
    user_id: UUID = Depends(get_current_user_id),
    provider: DataProvider = Depends(get_data_provider),
) -> AlertPreferences:
    """Update alert preferences for authenticated user.

    Security: Only updates preferences for the authenticated user.
    """
    return await provider.update_alert_preferences(user_id=user_id, prefs=payload)


@preferences_router.put("/alert-preferences/airports")
async def update_airport_weights(
    payload: PreferredAirportsUpdate,
    user_id: UUID = Depends(get_current_user_id),
    provider: DataProvider = Depends(get_data_provider),
) -> dict:
    """Update preferred airports for authenticated user.

    Security: Only updates airports for the authenticated user.
    """
    return await provider.update_preferred_airports(user_id=user_id, payload=payload)
