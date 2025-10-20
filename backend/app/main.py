"""
FareLens Backend API

FastAPI application entry point.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(
    title="FareLens API",
    description="Flight deal tracking and alerts API",
    version="0.1.0",
)

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


# TODO: Add API routers
# from app.api import deals, watchlists, alerts, users
# app.include_router(deals.router, prefix="/api/v1/deals", tags=["deals"])
# app.include_router(watchlists.router, prefix="/api/v1/watchlists", tags=["watchlists"])
# app.include_router(alerts.router, prefix="/api/v1/alerts", tags=["alerts"])
# app.include_router(users.router, prefix="/api/v1/users", tags=["users"])
