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


# TODO(#154): Implement background-refresh endpoint with proper authentication
# The endpoint is currently removed due to security concerns (no auth, DoS vector)
# When implementing, use service account JWT or internal-only deployment


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
