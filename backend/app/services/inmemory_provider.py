"""In-memory data provider (default for local development)."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Dict, List, Optional, Tuple
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
        self._alerts: List[AlertHistory] = []
        self._alert_preferences = AlertPreferences()
        self._preferred_airports: Dict[str, float] = {"LAX": 1.0}
        self.device_tokens: Dict[UUID, str] = {}
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
        self._alerts.append(alert)

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

    async def list_watchlists(self) -> List[Watchlist]:
        return sorted(
            self._watchlists.values(),
            key=lambda watchlist: watchlist.created_at,
            reverse=True,
        )

    async def create_watchlist(
        self,
        payload: WatchlistCreate,
    ) -> Watchlist:
        watchlist = Watchlist(
            id=uuid4(),
            user_id=uuid4(),
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
        self, watchlist_id: UUID, payload: WatchlistUpdate
    ) -> Watchlist:
        watchlist = self._watchlists[watchlist_id]
        update_data = payload.model_dump(exclude_unset=True)
        updated = watchlist.model_copy(
            update=update_data | {"updated_at": _now()},
        )
        self._watchlists[watchlist_id] = updated
        return updated

    async def delete_watchlist(self, watchlist_id: UUID) -> None:
        self._watchlists.pop(watchlist_id, None)

    # Alerts ----------------------------------------------------------------

    async def list_alert_history(
        self, page: int, per_page: int
    ) -> Tuple[List[AlertHistory], int]:
        alerts = sorted(self._alerts, key=lambda a: a.sent_at, reverse=True)
        start = (page - 1) * per_page
        end = start + per_page
        return alerts[start:end], len(alerts)

    async def append_alert(self, alert: AlertHistory) -> None:
        self._alerts.append(alert)

    async def get_alert_preferences(self) -> AlertPreferences:
        return self._alert_preferences

    async def update_alert_preferences(
        self, prefs: AlertPreferences
    ) -> AlertPreferences:
        self._alert_preferences = prefs
        return prefs

    async def update_preferred_airports(
        self,
        payload: PreferredAirportsUpdate,
    ) -> dict:
        self._preferred_airports = {
            item.iata.upper(): item.weight for item in payload.preferred_airports
        }
        return {
            "status": "updated",
            "preferred_airports": self._preferred_airports,
        }

    async def register_device_token(
        self, device_id: UUID, token: str, platform: str
    ) -> None:
        self.device_tokens[device_id] = token


provider = InMemoryProvider()


async def get_inmemory_provider() -> InMemoryProvider:
    return provider
