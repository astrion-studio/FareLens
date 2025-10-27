"""Alert endpoints (API.md section 4)."""

from uuid import UUID

from fastapi import APIRouter, Depends, status

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
    provider: DataProvider = Depends(get_data_provider),
) -> DeviceRegistrationResponse:
    await provider.register_device_token(
        payload.device_id, payload.token, payload.platform
    )
    return DeviceRegistrationResponse(status="registered", message="Device token saved")


@alerts_router.get("/history", response_model=AlertHistoryResponse)
async def get_history(
    page: int = 1,
    per_page: int = 20,
    provider: DataProvider = Depends(get_data_provider),
) -> AlertHistoryResponse:
    alerts, total = await provider.list_alert_history(page=page, per_page=per_page)
    return AlertHistoryResponse(
        alerts=alerts, page=page, per_page=per_page, total=total
    )


@preferences_router.put("/alert-preferences", response_model=AlertPreferences)
async def update_alert_preferences(
    payload: AlertPreferences,
    provider: DataProvider = Depends(get_data_provider),
) -> AlertPreferences:
    return await provider.update_alert_preferences(payload)


@preferences_router.put("/alert-preferences/airports")
async def update_airport_weights(
    payload: PreferredAirportsUpdate,
    provider: DataProvider = Depends(get_data_provider),
) -> dict:
    return await provider.update_preferred_airports(payload)
