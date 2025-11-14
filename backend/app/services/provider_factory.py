"""Factory for selecting the active data provider."""

from __future__ import annotations

import logging
from functools import lru_cache

from ..core.config import settings
from .data_provider import DataProvider
from .inmemory_provider import InMemoryProvider

logger = logging.getLogger(__name__)

try:
    from .supabase_provider import SupabaseProvider
except Exception:  # pragma: no cover - Supabase optional
    SupabaseProvider = None  # type: ignore


@lru_cache
def get_provider() -> DataProvider:
    if settings.use_in_memory_store:
        logger.info("Using InMemoryProvider (development mode)")
        return InMemoryProvider()

    if not settings.database_url:
        raise RuntimeError(
            "DATABASE_URL not configured. Set FARELENS_USE_IN_MEMORY_STORE=true "
            "for development or configure FARELENS_DATABASE_URL for production."
        )

    if SupabaseProvider is None:
        raise RuntimeError(
            "SupabaseProvider could not be imported. Check dependencies."
        )

    try:
        logger.info("Initializing SupabaseProvider with database connection")
        return SupabaseProvider()
    except Exception as e:
        logger.error(
            "Failed to initialize SupabaseProvider: %s. "
            "Check DATABASE_URL and database connectivity.",
            str(e),
            exc_info=True,
        )
        raise RuntimeError(
            f"Database connection failed: {str(e)}. "
            "Check DATABASE_URL and database connectivity."
        ) from e


async def get_data_provider() -> DataProvider:
    """FastAPI dependency returning the active data provider."""
    return get_provider()
