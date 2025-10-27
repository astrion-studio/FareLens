"""Pydantic schemas aligned with API.md contracts."""

from __future__ import annotations

from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field


class Route(BaseModel):
    origin: str = Field(..., description="IATA origin code")
    destination: str = Field(..., description="IATA destination code")


class DealRoute(BaseModel):
    origin: str
    destination: str
    origin_city: Optional[str] = None
    destination_city: Optional[str] = None


class FlightDeal(BaseModel):
    id: UUID
    origin: str
    destination: str
    departure_date: datetime
    return_date: datetime
    total_price: float
    currency: str
    deal_score: int
    discount_percent: int
    normal_price: float
    created_at: datetime
    expires_at: datetime
    airline: str
    stops: int
    return_stops: Optional[int] = None
    deep_link: str


class SavedDealResponse(BaseModel):
    deal: FlightDeal


class Watchlist(BaseModel):
    id: UUID
    user_id: UUID
    name: str
    origin: str
    destination: str
    date_range_start: Optional[datetime] = None
    date_range_end: Optional[datetime] = None
    max_price: Optional[float] = None
    is_active: bool = True
    created_at: datetime
    updated_at: datetime


class WatchlistCreate(BaseModel):
    name: str
    origin: str
    destination: str
    date_range_start: Optional[datetime] = None
    date_range_end: Optional[datetime] = None
    max_price: Optional[float] = None
    is_active: bool = True


class WatchlistUpdate(BaseModel):
    name: Optional[str] = None
    origin: Optional[str] = None
    destination: Optional[str] = None
    date_range_start: Optional[datetime] = None
    date_range_end: Optional[datetime] = None
    max_price: Optional[float] = None
    is_active: Optional[bool] = None


class AlertPreferences(BaseModel):
    enabled: bool = True
    quiet_hours_enabled: bool = True
    quiet_hours_start: int = 22
    quiet_hours_end: int = 7
    watchlist_only_mode: bool = False


class PreferredAirport(BaseModel):
    iata: str
    weight: float


class PreferredAirportsUpdate(BaseModel):
    preferred_airports: List[PreferredAirport]


class AlertHistory(BaseModel):
    id: UUID
    deal: FlightDeal
    sent_at: datetime
    opened_at: Optional[datetime] = None
    clicked_through: Optional[bool] = None
    expires_at: Optional[datetime] = None


class AlertHistoryResponse(BaseModel):
    alerts: List[AlertHistory]
    page: int = 1
    per_page: int = 20
    total: int = 0


class DeviceRegistrationRequest(BaseModel):
    device_id: UUID
    token: str
    platform: str


class DeviceRegistrationResponse(BaseModel):
    status: str
    message: str


class AuthRequest(BaseModel):
    email: EmailStr
    password: str


class AuthResponse(BaseModel):
    user: "User"
    token: str


class ResetPasswordRequest(BaseModel):
    email: EmailStr


class SubscriptionInfo(BaseModel):
    tier: str = Field("free", description="Subscription tier (free|pro)")
    max_watchlists: Optional[int] = 5
    max_alerts_per_day: int = 3
    trial_ends_at: Optional[datetime] = None


class User(BaseModel):
    id: UUID
    email: EmailStr
    subscription_tier: str = "free"
    timezone: str = "America/Los_Angeles"
    created_at: datetime
    subscription: SubscriptionInfo = Field(default_factory=SubscriptionInfo)


class UserUpdate(BaseModel):
    timezone: Optional[str] = None


class APNsRegistration(BaseModel):
    token: str
    platform: str = "ios"


class DealsResponse(BaseModel):
    deals: List[FlightDeal]


class BackgroundRefreshResponse(BaseModel):
    status: str
    new_deals: int = 0
    refreshed_at: datetime


AuthResponse.model_rebuild()
