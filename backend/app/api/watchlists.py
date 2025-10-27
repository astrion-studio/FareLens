"""Watchlist endpoints matching API.md section 3."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from ..models.schemas import Watchlist, WatchlistCreate, WatchlistUpdate
from ..services.data_provider import DataProvider
from ..services.provider_factory import get_data_provider

router = APIRouter(prefix="/watchlists", tags=["watchlists"])


@router.get("/", response_model=list[Watchlist])
async def list_watchlists(provider: DataProvider = Depends(get_data_provider)) -> list[Watchlist]:
    return await provider.list_watchlists()


@router.post("/", response_model=Watchlist, status_code=status.HTTP_201_CREATED)
async def create_watchlist(
    payload: WatchlistCreate,
    provider: DataProvider = Depends(get_data_provider),
) -> Watchlist:
    return await provider.create_watchlist(payload)


@router.put("/{watchlist_id}", response_model=Watchlist)
async def update_watchlist(
    watchlist_id: UUID,
    payload: WatchlistUpdate,
    provider: DataProvider = Depends(get_data_provider),
) -> Watchlist:
    try:
        return await provider.update_watchlist(watchlist_id, payload)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="Watchlist not found") from exc


@router.delete("/{watchlist_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_watchlist(
    watchlist_id: UUID,
    provider: DataProvider = Depends(get_data_provider),
) -> None:
    await provider.delete_watchlist(watchlist_id)
