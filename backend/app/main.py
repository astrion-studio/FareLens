"""
FareLens Backend API

FastAPI application entry point.
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from .api import alerts, auth, deals, user, watchlists
from .services.provider_factory import get_provider


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Lifespan event handler for startup and shutdown."""
    # Startup
    yield
    # Shutdown: Clean up resources
    provider = get_provider()
    if hasattr(provider, "close"):
        await provider.close()


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
import os

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
    """Detailed health check with database and Redis connectivity tests."""
    import redis.asyncio as aioredis

    from .core.config import settings
    from .services.provider_factory import get_provider

    health_status = {
        "status": "healthy",
        "database": "not_configured",
        "cache": "not_configured",
    }

    # Check database connectivity
    provider = get_provider()
    if hasattr(provider, "_ensure_pool"):
        try:
            pool = await provider._ensure_pool()
            async with pool.acquire() as conn:
                await conn.fetchval("SELECT 1")
            health_status["database"] = "healthy"
        except Exception as e:
            health_status["database"] = f"unhealthy: {str(e)}"
            health_status["status"] = "degraded"
    elif settings.use_in_memory_store:
        health_status["database"] = "in_memory"

    # Check Redis connectivity
    redis_url = os.getenv("REDIS_URL")
    if redis_url and redis_url != "memory://":
        try:
            redis_client = aioredis.from_url(redis_url)
            await redis_client.ping()
            await redis_client.close()
            health_status["cache"] = "healthy"
        except Exception as e:
            health_status["cache"] = f"unhealthy: {str(e)}"
            health_status["status"] = "degraded"
    elif redis_url == "memory://":
        health_status["cache"] = "in_memory"

    return health_status


api_prefix = "/v1"

app.include_router(auth.router, prefix=api_prefix)
app.include_router(deals.router, prefix=api_prefix)
app.include_router(watchlists.router, prefix=api_prefix)
app.include_router(alerts.alerts_router, prefix=api_prefix)
app.include_router(alerts.preferences_router, prefix=api_prefix)
app.include_router(user.router, prefix=api_prefix)
