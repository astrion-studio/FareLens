"""Factory for selecting the active data provider."""

from __future__ import annotations

from functools import lru_cache

from ..core.config import settings
from .data_provider import DataProvider
from .inmemory_provider import InMemoryProvider

try:
    from .supabase_provider import SupabaseProvider
except Exception:  # pragma: no cover - Supabase optional
    SupabaseProvider = None  # type: ignore


@lru_cache
def get_provider() -> DataProvider:
    if (
        not settings.use_in_memory_store
        and settings.database_url
        and SupabaseProvider is not None
    ):
        try:
            return SupabaseProvider()
        except Exception:  # fall back to in-memory if connection setup fails
            pass
    return InMemoryProvider()


async def get_data_provider() -> DataProvider:
    """FastAPI dependency returning the active data provider."""
    return get_provider()
