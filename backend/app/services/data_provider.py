"""Data provider abstraction for backend services."""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import List, Optional, Tuple
from uuid import UUID

from ..models.schemas import (
    AlertHistory,
    AlertPreferences,
    DealsResponse,
    FlightDeal,
    PreferredAirportsUpdate,
    Watchlist,
    WatchlistCreate,
    WatchlistUpdate,
)


class DataProvider(ABC):
    """Abstract interface backed by Supabase or in-memory store."""

    @abstractmethod
    async def list_deals(self, origin: Optional[str], limit: int) -> DealsResponse: ...

    @abstractmethod
    async def get_deal(self, deal_id: UUID) -> FlightDeal: ...

    @abstractmethod
    async def list_watchlists(self) -> List[Watchlist]: ...

    @abstractmethod
    async def create_watchlist(self, payload: WatchlistCreate) -> Watchlist: ...

    @abstractmethod
    async def update_watchlist(
        self, watchlist_id: UUID, payload: WatchlistUpdate
    ) -> Watchlist: ...

    @abstractmethod
    async def delete_watchlist(self, watchlist_id: UUID) -> None: ...

    @abstractmethod
    async def list_alert_history(
        self, page: int, per_page: int
    ) -> Tuple[List[AlertHistory], int]: ...

    @abstractmethod
    async def append_alert(self, alert: AlertHistory) -> None: ...

    @abstractmethod
    async def get_alert_preferences(self) -> AlertPreferences: ...

    @abstractmethod
    async def update_alert_preferences(
        self, prefs: AlertPreferences
    ) -> AlertPreferences: ...

    @abstractmethod
    async def update_preferred_airports(
        self, payload: PreferredAirportsUpdate
    ) -> dict: ...

    @abstractmethod
    async def register_device_token(
        self, device_id: UUID, token: str, platform: str
    ) -> None: ...
