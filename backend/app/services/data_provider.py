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
    async def list_deals(
        self,
        origin: Optional[str],
        limit: int,
    ) -> DealsResponse: ...

    @abstractmethod
    async def get_deal(self, deal_id: UUID) -> FlightDeal: ...

    @abstractmethod
    async def list_watchlists(self, user_id: UUID) -> List[Watchlist]: ...

    @abstractmethod
    async def create_watchlist(
        self,
        payload: WatchlistCreate,
    ) -> Watchlist: ...

    @abstractmethod
    async def update_watchlist(
        self, watchlist_id: UUID, payload: WatchlistUpdate
    ) -> Watchlist: ...

    @abstractmethod
    async def delete_watchlist(self, watchlist_id: UUID) -> None: ...

    @abstractmethod
    async def list_alert_history(
        self, user_id: UUID, page: int, per_page: int
    ) -> Tuple[List[AlertHistory], int]: ...

    @abstractmethod
    async def append_alert(self, alert: AlertHistory) -> None: ...

    @abstractmethod
    async def get_alert_preferences(self, user_id: UUID) -> AlertPreferences: ...

    @abstractmethod
    async def update_alert_preferences(
        self, user_id: UUID, prefs: AlertPreferences
    ) -> AlertPreferences: ...

    @abstractmethod
    async def update_preferred_airports(
        self, user_id: UUID, payload: PreferredAirportsUpdate
    ) -> dict: ...

    @abstractmethod
    async def register_device_token(
        self, user_id: UUID, device_id: UUID, token: str, platform: str
    ) -> None: ...
