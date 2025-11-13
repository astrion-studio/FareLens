"""Deals endpoints referencing API.md section 2."""

from datetime import datetime
from typing import Optional
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status

from ..models.schemas import FlightDeal
from ..services.data_provider import DataProvider
from ..services.provider_factory import get_data_provider

router = APIRouter(prefix="/deals", tags=["deals"])


@router.get("/", summary="List deals")
async def list_deals(
    origin: Optional[str] = Query(None, description="Origin IATA filter"),
    limit: int = Query(20, ge=1, le=100),
    provider: DataProvider = Depends(get_data_provider),
):
    response = await provider.list_deals(origin=origin, limit=limit)
    return response


@router.post("/background-refresh", summary="Trigger background cache refresh")
async def background_refresh(
    api_key: str = Query(..., description="Service account API key"),
    provider: DataProvider = Depends(get_data_provider),
):
    """Trigger background refresh of deal cache (service accounts only).

    Security: Requires SERVICE_ACCOUNT_API_KEY to prevent unauthorized access.
    Rate limiting: Protected by service account key (not public endpoint).
    """
    from ..core.config import settings

    if not settings.service_account_api_key:
        raise HTTPException(
            status_code=status.HTTP_501_NOT_IMPLEMENTED,
            detail="Background refresh not configured (missing SERVICE_ACCOUNT_API_KEY)",
        )

    if api_key != settings.service_account_api_key:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid service account API key",
        )

    # Trigger background refresh (placeholder - would call actual refresh service)
    return {
        "status": "triggered",
        "message": "Background deal cache refresh started",
        "timestamp": _utcnow(),
    }


@router.get("/{deal_id}", response_model=FlightDeal, summary="Deal detail")
async def get_deal(
    deal_id: UUID, provider: DataProvider = Depends(get_data_provider)
) -> FlightDeal:
    try:
        return await provider.get_deal(deal_id)
    except KeyError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Deal not found",
        ) from exc


def _utcnow() -> datetime:
    from datetime import datetime, timezone

    return datetime.now(timezone.utc)
