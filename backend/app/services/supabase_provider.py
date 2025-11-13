"""Supabase-backed data provider (uses PostgreSQL via asyncpg)."""

from __future__ import annotations

from textwrap import dedent
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
                dsn=settings.database_url,
                min_size=settings.database_pool_min_size,
                max_size=settings.database_pool_max_size,
            )
        return self._pool

    async def close(self) -> None:
        """Close the connection pool and release all connections."""
        if self._pool is not None:
            await self._pool.close()
            self._pool = None

    # Deals -----------------------------------------------------------------

    async def list_deals(
        self,
        origin: Optional[str],
        limit: int,
    ) -> DealsResponse:
        pool = await self._ensure_pool()
        query = dedent(
            """
            SELECT *
            FROM flight_deals
            WHERE ($1::text IS NULL OR origin = $1)
            ORDER BY deal_score DESC
            LIMIT $2
            """
        )
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                query,
                origin.upper() if origin else None,
                limit,
            )
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

    async def list_watchlists(self, user_id: UUID) -> List[Watchlist]:
        """List watchlists for a specific user only.

        Security: Filters by user_id to prevent users from seeing each other's watchlists.
        """
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                dedent(
                    """
                    SELECT *
                    FROM watchlists
                    WHERE user_id = $1
                    ORDER BY created_at DESC
                    """
                ),
                user_id,
            )
        return [self._map_watchlist(row) for row in rows]

    async def create_watchlist(
        self, user_id: UUID, payload: WatchlistCreate
    ) -> Watchlist:
        """Create a new watchlist for the authenticated user.

        Security: Associates watchlist with authenticated user_id from JWT token.
        """
        pool = await self._ensure_pool()
        query = dedent(
            """
            INSERT INTO watchlists (
                user_id,
                name,
                origin,
                destination,
                date_range_start,
                date_range_end,
                max_price,
                is_active
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING *
            """
        )
        async with pool.acquire() as conn:
            row = await conn.fetchrow(
                query,
                user_id,
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
        self, user_id: UUID, watchlist_id: UUID, payload: WatchlistUpdate
    ) -> Watchlist:
        """Update a watchlist owned by the authenticated user.

        Security: Only allows updating watchlists owned by the authenticated user.
        Raises KeyError if watchlist not found OR not owned by user (prevents IDOR).
        """
        pool = await self._ensure_pool()
        update_data = payload.model_dump(exclude_unset=True)

        # Whitelist of allowed column names to prevent SQL injection
        ALLOWED_COLUMNS = {
            "name",
            "origin",
            "destination",
            "date_range_start",
            "date_range_end",
            "max_price",
            "is_active",
        }

        # Filter update_data to only include whitelisted columns
        filtered_data = {k: v for k, v in update_data.items() if k in ALLOWED_COLUMNS}

        if not filtered_data:
            # No valid fields to update - just return current watchlist if owned by user
            async with pool.acquire() as conn:
                row = await conn.fetchrow(
                    "SELECT * FROM watchlists WHERE id = $1 AND user_id = $2",
                    watchlist_id,
                    user_id,
                )
                if row is None:
                    raise KeyError(str(watchlist_id))
            return self._map_watchlist(row)

        assignments = [
            f"{key} = ${idx}" for idx, key in enumerate(filtered_data.keys(), start=2)
        ]
        set_clause = ", ".join(assignments)
        # Add user_id check to prevent IDOR attacks
        query = (
            f"UPDATE watchlists SET {set_clause}, updated_at = NOW() "
            f"WHERE id = $1 AND user_id = ${len(filtered_data) + 2} RETURNING *"
        )
        params = [watchlist_id] + list(filtered_data.values()) + [user_id]
        async with pool.acquire() as conn:
            row = await conn.fetchrow(query, *params)
            if row is None:
                raise KeyError(str(watchlist_id))
        return self._map_watchlist(row)

    async def delete_watchlist(self, user_id: UUID, watchlist_id: UUID) -> None:
        """Delete a watchlist owned by the authenticated user.

        Security: Only allows deleting watchlists owned by the authenticated user.
        Silently succeeds if watchlist not found (idempotent) or not owned by user.
        """
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            await conn.execute(
                "DELETE FROM watchlists WHERE id = $1 AND user_id = $2",
                watchlist_id,
                user_id,
            )

    # Alerts ----------------------------------------------------------------

    async def list_alert_history(
        self, user_id: UUID, page: int, per_page: int
    ) -> Tuple[List[AlertHistory], int]:
        """List alert history for a specific user only.

        Security: Filters by user_id to prevent users from seeing each other's alerts.
        """
        pool = await self._ensure_pool()
        offset = (page - 1) * per_page
        async with pool.acquire() as conn:
            rows = await conn.fetch(
                dedent(
                    """
                    SELECT
                        a.id AS alert_id,
                        a.sent_at,
                        a.opened_at,
                        a.clicked_through,
                        a.expires_at AS alert_expires_at,
                        fd.id AS deal_id,
                        fd.origin,
                        fd.destination,
                        fd.departure_date,
                        fd.return_date,
                        fd.total_price,
                        fd.currency,
                        fd.deal_score,
                        fd.discount_percent,
                        fd.normal_price,
                        fd.created_at,
                        fd.expires_at AS deal_expires_at,
                        fd.airline,
                        fd.stops,
                        fd.return_stops,
                        fd.deep_link
                    FROM alert_history a
                    JOIN flight_deals fd ON a.deal_id = fd.id
                    WHERE a.user_id = $1
                    ORDER BY a.sent_at DESC
                    LIMIT $2 OFFSET $3
                    """
                ),
                user_id,
                per_page,
                offset,
            )
            total_row = await conn.fetchrow(
                "SELECT COUNT(*) AS total FROM alert_history WHERE user_id = $1",
                user_id,
            )
        alerts = [self._map_alert(row) for row in rows]
        total = total_row["total"] if total_row else 0
        return alerts, total

    async def append_alert(self, user_id: UUID, alert: AlertHistory) -> None:
        """Append alert to history for specific user.

        Security: Associates alert with authenticated user_id to prevent data leakage.
        """
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            await conn.execute(
                dedent(
                    """
                    INSERT INTO alert_history (
                        id,
                        user_id,
                        deal_id,
                        sent_at,
                        opened_at,
                        clicked_through,
                        expires_at
                    )
                    VALUES ($1, $2, $3, $4, $5, $6, $7)
                    """
                ),
                alert.id,
                user_id,
                alert.deal.id,
                alert.sent_at,
                alert.opened_at,
                alert.clicked_through,
                alert.expires_at,
            )

    async def get_alert_preferences(self, user_id: UUID) -> AlertPreferences:
        """Get alert preferences from users table columns.

        Security: Fetches preferences for specific user only.
        Schema: Reads from users table columns (alert_enabled, quiet_hours_*, watchlist_only_mode).
        """
        pool = await self._ensure_pool()
        query = dedent(
            """
            SELECT
                alert_enabled,
                quiet_hours_enabled,
                quiet_hours_start,
                quiet_hours_end,
                watchlist_only_mode
            FROM users
            WHERE id = $1
            """
        )
        async with pool.acquire() as conn:
            row = await conn.fetchrow(query, user_id)
        if row is None:
            # User not found - return defaults
            return AlertPreferences()
        return AlertPreferences(
            enabled=row["alert_enabled"],
            quiet_hours_enabled=row["quiet_hours_enabled"],
            quiet_hours_start=row["quiet_hours_start"],
            quiet_hours_end=row["quiet_hours_end"],
            watchlist_only_mode=row["watchlist_only_mode"],
        )

    async def update_alert_preferences(
        self, user_id: UUID, prefs: AlertPreferences
    ) -> AlertPreferences:
        """Update alert preferences in users table columns.

        Security: Updates preferences for specific user only.
        Schema: Updates users table columns (alert_enabled, quiet_hours_*, watchlist_only_mode).
        """
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            await conn.execute(
                dedent(
                    """
                    UPDATE users
                    SET
                        alert_enabled = $2,
                        quiet_hours_enabled = $3,
                        quiet_hours_start = $4,
                        quiet_hours_end = $5,
                        watchlist_only_mode = $6,
                        updated_at = NOW()
                    WHERE id = $1
                    """
                ),
                user_id,
                prefs.enabled,
                prefs.quiet_hours_enabled,
                prefs.quiet_hours_start,
                prefs.quiet_hours_end,
                prefs.watchlist_only_mode,
            )
        return prefs

    async def update_preferred_airports(
        self, user_id: UUID, payload: PreferredAirportsUpdate
    ) -> dict:
        """Update preferred airports in users.preferred_airports JSONB column.

        Security: Updates airports for specific user only.
        Schema: Updates users.preferred_airports JSONB column (array of {iata, weight} objects).
        """
        pool = await self._ensure_pool()

        # Convert PreferredAirport objects to JSONB-compatible dicts
        airports_json = [
            {"iata": airport.iata.upper(), "weight": airport.weight}
            for airport in payload.preferred_airports
        ]

        async with pool.acquire() as conn:
            await conn.execute(
                dedent(
                    """
                    UPDATE users
                    SET
                        preferred_airports = $2::jsonb,
                        updated_at = NOW()
                    WHERE id = $1
                    """
                ),
                user_id,
                airports_json,  # asyncpg handles list->jsonb conversion
            )
        return {"status": "updated"}

    async def register_device_token(
        self, user_id: UUID, device_id: UUID, token: str, platform: str
    ) -> None:
        """Register device token in device_registrations table.

        Security: Associates device with authenticated user_id.
        Schema: Uses device_registrations table with user_id, device_id, apns_token columns.
        UPSERT: Updates token if device already registered for this user.
        """
        pool = await self._ensure_pool()
        async with pool.acquire() as conn:
            await conn.execute(
                dedent(
                    """
                    INSERT INTO device_registrations (
                        user_id,
                        device_id,
                        apns_token,
                        platform,
                        created_at,
                        updated_at,
                        last_active_at
                    )
                    VALUES ($1, $2, $3, $4, NOW(), NOW(), NOW())
                    ON CONFLICT (user_id, device_id) DO UPDATE SET
                        apns_token = EXCLUDED.apns_token,
                        platform = EXCLUDED.platform,
                        updated_at = NOW(),
                        last_active_at = NOW()
                    """
                ),
                user_id,
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
        # Map the deal portion using aliased column names
        deal = FlightDeal(
            id=row["deal_id"],
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
            expires_at=row["deal_expires_at"],
            airline=row["airline"],
            stops=row["stops"],
            return_stops=row.get("return_stops"),
            deep_link=row["deep_link"],
        )
        return AlertHistory(
            id=row["alert_id"],
            deal=deal,
            sent_at=row["sent_at"],
            opened_at=row.get("opened_at"),
            clicked_through=row.get("clicked_through"),
            expires_at=row.get("alert_expires_at"),
        )
