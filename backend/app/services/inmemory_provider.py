"""In-memory data provider (default for local development)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple
from uuid import UUID, uuid4

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
from .data_provider import DataProvider


def _now() -> datetime:
    return datetime.now(timezone.utc)


class InMemoryProvider(DataProvider):
    def __init__(self) -> None:
        self._deals: Dict[UUID, FlightDeal] = {}
        self._watchlists: Dict[UUID, Watchlist] = {}
        self._alerts: Dict[UUID, List[AlertHistory]] = {}  # Keyed by user_id for security
        # User-specific preferences (keyed by user_id)
        self._alert_preferences: Dict[UUID, AlertPreferences] = {}
        self._preferred_airports: Dict[UUID, List[Dict[str, Any]]] = {}
        # Device tokens (keyed by user_id, then device_id)
        self.device_tokens: Dict[UUID, Dict[UUID, str]] = {}
        self._seed()

    def _seed(self) -> None:
        demo_deal = FlightDeal(
            id=uuid4(),
            origin="LAX",
            destination="JFK",
            departure_date=_now() + timedelta(days=14),
            return_date=_now() + timedelta(days=21),
            total_price=420.0,
            currency="USD",
            deal_score=94,
            discount_percent=35,
            normal_price=646.0,
            created_at=_now() - timedelta(hours=2),
            expires_at=_now() + timedelta(hours=12),
            airline="Delta",
            stops=0,
            return_stops=0,
            deep_link="https://example.com/deal/lax-jfk",
        )
        self._deals[demo_deal.id] = demo_deal

        watchlist = Watchlist(
            id=uuid4(),
            user_id=uuid4(),
            name="LAX to JFK",
            origin="LAX",
            destination="JFK",
            date_range_start=_now(),
            date_range_end=_now() + timedelta(days=60),
            max_price=500.0,
            is_active=True,
            created_at=_now() - timedelta(days=2),
            updated_at=_now() - timedelta(days=1),
        )
        self._watchlists[watchlist.id] = watchlist

        alert = AlertHistory(
            id=uuid4(),
            deal=demo_deal,
            sent_at=_now() - timedelta(hours=3),
            opened_at=_now() - timedelta(hours=2, minutes=45),
            clicked_through=True,
            expires_at=demo_deal.expires_at,
        )
        # Associate alert with demo watchlist's user_id
        # Note: _alerts structure changed from List[AlertHistory] to Dict[UUID, List[AlertHistory]]
        # in commit 0c113ed to properly scope alerts per user and prevent IDOR vulnerabilities.
        # This dictionary check ensures alerts are keyed by user_id, not stored globally.
        if watchlist.user_id not in self._alerts:
            self._alerts[watchlist.user_id] = []
        self._alerts[watchlist.user_id].append(alert)

    # Deals -----------------------------------------------------------------

    async def list_deals(
        self,
        origin: Optional[str],
        limit: int,
    ) -> DealsResponse:
        deals = list(self._deals.values())
        if origin:
            deals = [d for d in deals if d.origin == origin.upper()]
        deals.sort(key=lambda d: d.deal_score, reverse=True)
        return DealsResponse(deals=deals[:limit])

    async def get_deal(self, deal_id: UUID) -> FlightDeal:
        return self._deals[deal_id]

    # Watchlists ------------------------------------------------------------

    async def list_watchlists(self, user_id: UUID) -> List[Watchlist]:
        # Filter watchlists by user_id
        user_watchlists = [
            w for w in self._watchlists.values() if w.user_id == user_id
        ]
        return sorted(
            user_watchlists,
            key=lambda watchlist: watchlist.created_at,
            reverse=True,
        )

    async def create_watchlist(
        self, user_id: UUID, payload: WatchlistCreate
    ) -> Watchlist:
        """Create watchlist for authenticated user.

        Security: Uses authenticated user_id from JWT token, not random UUID.
        """
        watchlist = Watchlist(
            id=uuid4(),
            user_id=user_id,  # Use authenticated user_id, not random!
            name=payload.name,
            origin=payload.origin.upper(),
            destination=payload.destination.upper(),
            date_range_start=payload.date_range_start,
            date_range_end=payload.date_range_end,
            max_price=payload.max_price,
            is_active=payload.is_active,
            created_at=_now(),
            updated_at=_now(),
        )
        self._watchlists[watchlist.id] = watchlist
        return watchlist

    async def update_watchlist(
        self, user_id: UUID, watchlist_id: UUID, payload: WatchlistUpdate
    ) -> Watchlist:
        """Update watchlist owned by authenticated user.

        Security: Validates ownership before updating to prevent IDOR attacks.
        Raises KeyError if watchlist not found or not owned by user.
        """
        watchlist = self._watchlists.get(watchlist_id)
        if watchlist is None or watchlist.user_id != user_id:
            raise KeyError(str(watchlist_id))
        update_data = payload.model_dump(exclude_unset=True)
        updated = watchlist.model_copy(
            update=update_data | {"updated_at": _now()},
        )
        self._watchlists[watchlist_id] = updated
        return updated

    async def delete_watchlist(self, user_id: UUID, watchlist_id: UUID) -> None:
        """Delete watchlist owned by authenticated user.

        Security: Validates ownership before deleting to prevent IDOR attacks.
        Silently succeeds if watchlist not found or not owned by user (idempotent).
        """
        watchlist = self._watchlists.get(watchlist_id)
        if watchlist is not None and watchlist.user_id == user_id:
            self._watchlists.pop(watchlist_id)

    # Alerts ----------------------------------------------------------------

    async def list_alert_history(
        self, user_id: UUID, page: int, per_page: int
    ) -> Tuple[List[AlertHistory], int]:
        """List alert history for specific user only.

        Security: Filters alerts by user_id to prevent users from seeing each other's alerts.
        """
        user_alerts = self._alerts.get(user_id, [])
        alerts = sorted(user_alerts, key=lambda a: a.sent_at, reverse=True)
        start = (page - 1) * per_page
        end = start + per_page
        return alerts[start:end], len(user_alerts)

    async def append_alert(self, user_id: UUID, alert: AlertHistory) -> None:
        """Append alert to history for specific user.

        Security: Associates alert with authenticated user_id to prevent data leakage.
        """
        if user_id not in self._alerts:
            self._alerts[user_id] = []
        self._alerts[user_id].append(alert)

    async def get_alert_preferences(self, user_id: UUID) -> AlertPreferences:
        # Return user-specific preferences or defaults
        return self._alert_preferences.get(user_id, AlertPreferences())

    async def update_alert_preferences(
        self, user_id: UUID, prefs: AlertPreferences
    ) -> AlertPreferences:
        self._alert_preferences[user_id] = prefs
        return prefs

    async def update_preferred_airports(
        self, user_id: UUID, payload: PreferredAirportsUpdate
    ) -> dict:
        airports_list = [
            {"iata": item.iata.upper(), "weight": item.weight}
            for item in payload.preferred_airports
        ]
        self._preferred_airports[user_id] = airports_list
        return {
            "status": "updated",
            "preferred_airports": airports_list,
        }

    async def register_device_token(
        self, user_id: UUID, device_id: UUID, token: str, platform: str
    ) -> None:
        if user_id not in self.device_tokens:
            self.device_tokens[user_id] = {}
        self.device_tokens[user_id][device_id] = token


provider = InMemoryProvider()


async def get_inmemory_provider() -> InMemoryProvider:
    return provider
