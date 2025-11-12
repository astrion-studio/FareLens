"""
FareLens Backend API

FastAPI application entry point.
"""

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from .api import alerts, auth, deals, user, watchlists

app = FastAPI(
    title="FareLens API",
    description="Flight deal tracking and alerts API",
    version="0.1.0",
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

# CORS configuration for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: Restrict to iOS app domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
    """Detailed health check"""
    return {
        "status": "healthy",
        "database": "not_configured",  # TODO: Add database health check
        "cache": "not_configured",  # TODO: Add Redis health check
    }


api_prefix = "/v1"

app.include_router(auth.router, prefix=api_prefix)
app.include_router(deals.router, prefix=api_prefix)
app.include_router(watchlists.router, prefix=api_prefix)
app.include_router(alerts.alerts_router, prefix=api_prefix)
app.include_router(alerts.preferences_router, prefix=api_prefix)
app.include_router(user.router, prefix=api_prefix)
