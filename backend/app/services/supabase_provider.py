"""Supabase-backed data provider (uses PostgreSQL via asyncpg)."""

from __future__ import annotations

from typing import List, Optional, Tuple
from uuid import UUID

import asyncpg

from ..core.config import settings
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


class SupabaseProvider(DataProvider):
    def __init__(self) -> None:
        if not settings.database_url:
            raise ValueError("DATABASE_URL must be set for SupabaseProvider")
        self._pool: Optional[asyncpg.Pool] = None

    async def _ensure_pool(self) -> asyncpg.Pool:
        if self._pool is None:
            self._pool = await asyncpg.create_pool(
                dsn=settings.database_url, min_size=1, max_size=5
            )
        return self._pool

    # Deals -----------------------------------------------------------------

    async def list_deals(self, origin: Optional[str], limit: int) -> DealsResponse:
        pool = await self._ensure_pool()
        query = (
            "SELECT * FROM flight_deals WHERE ($1::text IS NULL OR origin = $1) "
            "ORDER BY deal_score DESC LIMIT $2"
        )
        async with pool.acquire() as conn:
            rows = await conn.fetch(query, origin.upper() if origin else None, limit)
        deals = [self._map_deal(row) for row in rows]
        return DealsResponse(deals=deals)

    async def get_deal(self, deal_id: UUID) -> FlightDeal:
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                "SELECT * FROM flight_deals WHERE id = $1", deal_id
            )
            if row is None:
                raise KeyError(str(deal_id))
        return self._map_deal(row)

    # Watchlists ------------------------------------------------------------

    async def list_watchlists(self) -> List[Watchlist]:
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            rows = await conn.fetch("SELECT * FROM watchlists ORDER BY created_at DESC")
        return [self._map_watchlist(row) for row in rows]

    async def create_watchlist(self, payload: WatchlistCreate) -> Watchlist:
        pool = await self._ensure_pool()
        query = """
            INSERT INTO watchlists (name, origin, destination, date_range_start,
                                   date_range_end, max_price, is_active)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING *
        """
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                query,
                payload.name,
                payload.origin.upper(),
                payload.destination.upper(),
                payload.date_range_start,
                payload.date_range_end,
                payload.max_price,
                payload.is_active,
            )
        return self._map_watchlist(row)

    async def update_watchlist(
        self, watchlist_id: UUID, payload: WatchlistUpdate
    ) -> Watchlist:
        pool = await self._ensure_pool()
        update_data = payload.model_dump(exclude_unset=True)
        set_clause = ", ".join(
            f"{key} = ${idx}" for idx, key in enumerate(update_data.keys(), start=2)
        )
        # Column names from Pydantic model fields (not user input)
        query = (
            f"UPDATE watchlists SET {set_clause}, updated_at = NOW() "  # nosec
            f"WHERE id = $1 RETURNING *"
        )
        params = [watchlist_id] + list(update_data.values())
        async with pool.acquire() as conn:
            row = await conn.fetchrow(query, *params)
            if row is None:
                raise KeyError(str(watchlist_id))
        return self._map_watchlist(row)

    async def delete_watchlist(self, watchlist_id: UUID) -> None:
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            await conn.execute("DELETE FROM watchlists WHERE id = $1", watchlist_id)

    # Alerts ----------------------------------------------------------------

    async def list_alert_history(
        self, page: int, per_page: int
    ) -> Tuple[List[AlertHistory], int]:
        pool = await self._ensure_pool()
        offset = (page - 1) * per_page
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                "SELECT a.*, fd.* FROM alert_history a JOIN flight_deals fd ON a.deal_id = fd.id"
                " ORDER BY a.sent_at DESC LIMIT $1 OFFSET $2",
                per_page,
                offset,
            )
            total_row = await conn.fetchrow(
                "SELECT COUNT(*) AS total FROM alert_history"
            )
        alerts = [self._map_alert(row) for row in rows]
        total = total_row["total"] if total_row else 0
        return alerts, total

    async def append_alert(self, alert: AlertHistory) -> None:
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO alert_history (id, deal_id, sent_at, opened_at, "
                "clicked_through, expires_at) VALUES ($1, $2, $3, $4, $5, $6)",
                alert.id,
                alert.deal.id,
                alert.sent_at,
                alert.opened_at,
                alert.clicked_through,
                alert.expires_at,
            )

    async def get_alert_preferences(self) -> AlertPreferences:
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            row = await conn.fetchrow("SELECT * FROM alert_preferences LIMIT 1")
        if row is None:
            return AlertPreferences()
        return AlertPreferences(
            enabled=row["enabled"],
            quiet_hours_enabled=row["quiet_hours_enabled"],
            quiet_hours_start=row["quiet_hours_start"],
            quiet_hours_end=row["quiet_hours_end"],
            watchlist_only_mode=row["watchlist_only_mode"],
        )

    async def update_alert_preferences(
        self, prefs: AlertPreferences
    ) -> AlertPreferences:
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            await conn.execute("DELETE FROM alert_preferences")  # ensure single row
            await conn.execute(
                "INSERT INTO alert_preferences (enabled, quiet_hours_enabled, "
                "quiet_hours_start, quiet_hours_end, watchlist_only_mode)"
                " VALUES ($1, $2, $3, $4, $5)",
                prefs.enabled,
                prefs.quiet_hours_enabled,
                prefs.quiet_hours_start,
                prefs.quiet_hours_end,
                prefs.watchlist_only_mode,
            )
        return prefs

    async def update_preferred_airports(self, payload: PreferredAirportsUpdate) -> dict:
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            await conn.execute("DELETE FROM preferred_airports")
            for airport in payload.preferred_airports:
                await conn.execute(
                    "INSERT INTO preferred_airports (iata, weight) VALUES ($1, $2)",
                    airport.iata.upper(),
                    airport.weight,
                )
        return {"status": "updated"}

    async def register_device_token(
        self, device_id: UUID, token: str, platform: str
    ) -> None:
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            await conn.execute(
                "INSERT INTO device_tokens (id, token, platform, created_at)"
                " VALUES ($1, $2, $3, NOW())"
                " ON CONFLICT (id) DO UPDATE SET token = EXCLUDED.token, "
                "platform = EXCLUDED.platform, last_used_at = NOW()",
                device_id,
                token,
                platform,
            )

    # Mapping helpers -------------------------------------------------------

    def _map_deal(self, row: asyncpg.Record) -> FlightDeal:
        return FlightDeal(
            id=row["id"],
            origin=row["origin"],
            destination=row["destination"],
            departure_date=row["departure_date"],
            return_date=row["return_date"],
            total_price=row["total_price"],
            currency=row["currency"],
            deal_score=row["deal_score"],
            discount_percent=row["discount_percent"],
            normal_price=row["normal_price"],
            created_at=row["created_at"],
            expires_at=row["expires_at"],
            airline=row["airline"],
            stops=row["stops"],
            return_stops=row.get("return_stops"),
            deep_link=row["deep_link"],
        )

    def _map_watchlist(self, row: asyncpg.Record) -> Watchlist:
        return Watchlist(
            id=row["id"],
            user_id=row["user_id"],
            name=row["name"],
            origin=row["origin"],
            destination=row["destination"],
            date_range_start=row.get("date_range_start"),
            date_range_end=row.get("date_range_end"),
            max_price=row.get("max_price"),
            is_active=row["is_active"],
            created_at=row["created_at"],
            updated_at=row["updated_at"],
        )

    def _map_alert(self, row: asyncpg.Record) -> AlertHistory:
        deal = self._map_deal(row)
        return AlertHistory(
            id=row["id"],
            deal=deal,
            sent_at=row["sent_at"],
            opened_at=row.get("opened_at"),
            clicked_through=row.get("clicked_through"),
            expires_at=row.get("expires_at"),
        )
