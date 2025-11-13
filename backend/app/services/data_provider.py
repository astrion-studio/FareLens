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
    User,
    UserUpdate,
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
        user_id: UUID,
        payload: WatchlistCreate,
    ) -> Watchlist:
        """Create a new watchlist for the authenticated user.

        Args:
            user_id: ID of the authenticated user (from JWT token)
            payload: Watchlist creation data

        Returns:
            Created watchlist with user_id set to authenticated user
        """
        ...

    @abstractmethod
    async def update_watchlist(
        self, user_id: UUID, watchlist_id: UUID, payload: WatchlistUpdate
    ) -> Watchlist:
        """Update a watchlist owned by the authenticated user.

        Args:
            user_id: ID of the authenticated user (from JWT token)
            watchlist_id: ID of watchlist to update
            payload: Updated watchlist data

        Returns:
            Updated watchlist

        Raises:
            KeyError: If watchlist not found or not owned by user
        """
        ...

    @abstractmethod
    async def delete_watchlist(self, user_id: UUID, watchlist_id: UUID) -> None:
        """Delete a watchlist owned by the authenticated user.

        Idempotent: Silently succeeds if watchlist not found or not owned by user.
        This follows HTTP DELETE semantics (204 No Content for both existing and non-existing resources).

        Args:
            user_id: ID of the authenticated user (from JWT token)
            watchlist_id: ID of watchlist to delete
        """
        ...

    @abstractmethod
    async def list_alert_history(
        self, user_id: UUID, page: int, per_page: int
    ) -> Tuple[List[AlertHistory], int]: ...

    @abstractmethod
    async def append_alert(self, user_id: UUID, alert: AlertHistory) -> None:
        """Append an alert to the alert history for a user.

        Args:
            user_id: ID of the user this alert belongs to
            alert: Alert history entry to append
        """
        ...

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

    @abstractmethod
    async def get_user(self, user_id: UUID) -> User:
        """Get user by ID.

        Args:
            user_id: ID of the user to retrieve

        Returns:
            User object

        Raises:
            KeyError: If user not found
        """
        ...

    @abstractmethod
    async def update_user(self, user_id: UUID, payload: UserUpdate) -> User:
        """Update user settings.

        Args:
            user_id: ID of the user to update
            payload: User update data

        Returns:
            Updated user object

        Raises:
            KeyError: If user not found
        """
        ...
