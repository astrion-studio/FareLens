"""
FareLens Backend API

FastAPI application entry point.
"""

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from .api import alerts, auth, deals, user, watchlists

app = FastAPI(
    title="FareLens API",
    description="Flight deal tracking and alerts API",
    version="0.1.0",
)

# Add rate limiter state and exception handler
app.state.limiter = auth.limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

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
