"""Watchlist endpoints matching API.md section 3."""

from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from ..core.auth import get_current_user_id
from ..models.schemas import Watchlist, WatchlistCreate, WatchlistUpdate
from ..services.data_provider import DataProvider
from ..services.provider_factory import get_data_provider

router = APIRouter(prefix="/watchlists", tags=["watchlists"])


@router.get("/", response_model=list[Watchlist])
async def list_watchlists(
    user_id: UUID = Depends(get_current_user_id),
    provider: DataProvider = Depends(get_data_provider),
) -> list[Watchlist]:
    """List watchlists for authenticated user only.

    Security: Only returns watchlists owned by the authenticated user.
    """
    return await provider.list_watchlists(user_id=user_id)


@router.post(
    "/",
    response_model=Watchlist,
    status_code=status.HTTP_201_CREATED,
)
async def create_watchlist(
    payload: WatchlistCreate,
    user_id: UUID = Depends(get_current_user_id),
    provider: DataProvider = Depends(get_data_provider),
) -> Watchlist:
    """Create watchlist for authenticated user only.

    Security: Associates watchlist with authenticated user from JWT token.
    """
    return await provider.create_watchlist(user_id=user_id, payload=payload)


@router.put("/{watchlist_id}", response_model=Watchlist)
async def update_watchlist(
    watchlist_id: UUID,
    payload: WatchlistUpdate,
    user_id: UUID = Depends(get_current_user_id),
    provider: DataProvider = Depends(get_data_provider),
) -> Watchlist:
    """Update watchlist owned by authenticated user only.

    Security: Only allows updating watchlists owned by the authenticated user.
    Returns 404 if watchlist not found or not owned by user (prevents IDOR).
    """
    try:
        return await provider.update_watchlist(
            user_id=user_id, watchlist_id=watchlist_id, payload=payload
        )
    except KeyError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Watchlist not found",
        ) from exc


@router.delete("/{watchlist_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_watchlist(
    watchlist_id: UUID,
    user_id: UUID = Depends(get_current_user_id),
    provider: DataProvider = Depends(get_data_provider),
) -> None:
    """Delete watchlist owned by authenticated user only.

    Security: Only allows deleting watchlists owned by the authenticated user.
    Silently succeeds if watchlist not found or not owned by user (idempotent).
    """
    await provider.delete_watchlist(user_id=user_id, watchlist_id=watchlist_id)
