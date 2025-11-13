"""
FareLens Backend API

FastAPI application entry point.
"""

import os
from contextlib import asynccontextmanager

import redis.asyncio as aioredis
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from .api import alerts, auth, deals, user, watchlists
from .services.provider_factory import get_provider

# Global Redis connection pool for health checks (reused across requests)
_redis_pool: aioredis.ConnectionPool | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan event handler for startup and shutdown."""
    global _redis_pool

    # Startup: Initialize Redis connection pool if configured
    redis_url = os.getenv("REDIS_URL")
    if redis_url and redis_url != "memory://":
        _redis_pool = aioredis.ConnectionPool.from_url(redis_url)

    yield

    # Shutdown: Clean up resources
    provider = get_provider()
    if hasattr(provider, "close"):
        await provider.close()

    # Close Redis connection pool
    if _redis_pool:
        await _redis_pool.disconnect()


app = FastAPI(
    title="FareLens API",
    description="Flight deal tracking and alerts API",
    version="0.1.0",
    lifespan=lifespan,
)


# Adapter to match Starlette's exception handler signature
# slowapi's handler doesn't match Callable[[Request, Exception], Response]
async def rate_limit_handler(request: Request, exc: Exception) -> Response:
    """Adapter for slowapi's rate limit exception handler.

    Starlette expects: Callable[[Request, Exception], Response]
    slowapi provides: different signature
    This adapter ensures type compatibility for mypy.
    """
    return _rate_limit_exceeded_handler(request, exc)


# Add rate limiter state and exception handler
app.state.limiter = auth.limiter
app.add_exception_handler(RateLimitExceeded, rate_limit_handler)

# CORS configuration
# Note: Native iOS apps don't require CORS (browser-only security feature)
# CORS is disabled by default for security - only enable if web client needed
cors_origins = (
    os.getenv("CORS_ORIGINS", "").split(",") if os.getenv("CORS_ORIGINS") else []
)

if cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,  # Explicit origins only (never use "*")
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE"],
        allow_headers=["Authorization", "Content-Type"],
    )


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "ok",
        "service": "FareLens API",
        "version": "0.1.0",
    }


@app.get("/health")
async def health():
    """Detailed health check with database and Redis connectivity tests.

    Uses connection pools to avoid creating new connections on every request.
    Provides detailed status and metrics for observability.
    """
    health_status = {
        "status": "healthy",
        "database": {"status": "not_configured"},
        "cache": {"status": "not_configured"},
    }

    # Check database connectivity using provider's health check
    provider = get_provider()
    db_health = await provider.health_check()
    health_status["database"] = db_health

    if db_health["status"] == "unhealthy":
        health_status["status"] = "degraded"

    # Check Redis connectivity using connection pool
    redis_url = os.getenv("REDIS_URL")
    if redis_url and redis_url != "memory://":
        try:
            if _redis_pool:
                # Use existing connection pool
                redis_client = aioredis.Redis(connection_pool=_redis_pool)
                await redis_client.ping()
                health_status["cache"] = {
                    "status": "healthy",
                    "type": "redis",
                }
            else:
                health_status["cache"] = {
                    "status": "unhealthy",
                    "error": "Redis pool not initialized",
                }
                health_status["status"] = "degraded"
        except Exception as e:
            health_status["cache"] = {
                "status": "unhealthy",
                "type": "redis",
                "error": str(e),
            }
            health_status["status"] = "degraded"
    elif redis_url == "memory://":
        health_status["cache"] = {"status": "healthy", "type": "in_memory"}

    return health_status


api_prefix = "/v1"

app.include_router(auth.router, prefix=api_prefix)
app.include_router(deals.router, prefix=api_prefix)
app.include_router(watchlists.router, prefix=api_prefix)
app.include_router(alerts.alerts_router, prefix=api_prefix)
app.include_router(alerts.preferences_router, prefix=api_prefix)
app.include_router(user.router, prefix=api_prefix)
