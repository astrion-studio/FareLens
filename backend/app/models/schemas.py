"""Pydantic schemas aligned with API.md contracts."""

from __future__ import annotations

import re
from datetime import datetime
from typing import List, Optional
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, field_validator


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
    origin: str = Field(..., description="3-letter IATA airport code")
    destination: str = Field(..., description="3-letter IATA airport code or ANY")
    date_range_start: Optional[datetime] = None
    date_range_end: Optional[datetime] = None
    max_price: Optional[float] = None
    is_active: bool = True

    @field_validator("origin")
    @classmethod
    def validate_origin(cls, v: str) -> str:
        """Validate origin is exactly 3 uppercase letters."""
        if not re.match(r"^[A-Z]{3}$", v.upper()):
            raise ValueError("Origin must be exactly 3 letters (e.g., LAX, JFK, SFO)")
        return v.upper()

    @field_validator("destination")
    @classmethod
    def validate_destination(cls, v: str) -> str:
        """Validate destination is exactly 3 uppercase letters or ANY."""
        if not re.match(r"^([A-Z]{3}|ANY)$", v.upper()):
            raise ValueError(
                "Destination must be exactly 3 letters (e.g., LAX, JFK, SFO) or ANY"
            )
        return v.upper()


class WatchlistUpdate(BaseModel):
    name: Optional[str] = None
    origin: Optional[str] = Field(None, description="3-letter IATA airport code")
    destination: Optional[str] = Field(
        None, description="3-letter IATA airport code or ANY"
    )
    date_range_start: Optional[datetime] = None
    date_range_end: Optional[datetime] = None
    max_price: Optional[float] = None
    is_active: Optional[bool] = None

    @field_validator("origin")
    @classmethod
    def validate_origin(cls, v: Optional[str]) -> Optional[str]:
        """Validate origin is exactly 3 uppercase letters."""
        if v is None:
            return v
        if not re.match(r"^[A-Z]{3}$", v.upper()):
            raise ValueError("Origin must be exactly 3 letters (e.g., LAX, JFK, SFO)")
        return v.upper()

    @field_validator("destination")
    @classmethod
    def validate_destination(cls, v: Optional[str]) -> Optional[str]:
        """Validate destination is exactly 3 uppercase letters or ANY."""
        if v is None:
            return v
        if not re.match(r"^([A-Z]{3}|ANY)$", v.upper()):
            raise ValueError(
                "Destination must be exactly 3 letters (e.g., LAX, JFK, SFO) or ANY"
            )
        return v.upper()


class AlertPreferences(BaseModel):
    enabled: bool = True
    quiet_hours_enabled: bool = True
    quiet_hours_start: int = 22
    quiet_hours_end: int = 7
    watchlist_only_mode: bool = False


class PreferredAirport(BaseModel):
    iata: str = Field(..., description="3-letter IATA airport code")
    weight: float

    @field_validator("iata")
    @classmethod
    def validate_iata(cls, v: str) -> str:
        """Validate IATA code is exactly 3 uppercase letters."""
        if not re.match(r"^[A-Z]{3}$", v.upper()):
            raise ValueError(
                "IATA code must be exactly 3 letters (e.g., LAX, JFK, SFO)"
            )
        return v.upper()


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
    registered: bool
    device_id: str


class AuthRequest(BaseModel):
    email: EmailStr
    password: str


class AuthResponse(BaseModel):
    user: "User"
    token: str


class ResetPasswordRequest(BaseModel):
    email: EmailStr


class SubscriptionInfo(BaseModel):
    tier: str = Field(
        default="free",
        description="Subscription tier (free|pro)",
    )
    max_watchlists: Optional[int] = 5
    max_alerts_per_day: int = 3
    trial_ends_at: Optional[datetime] = None


class User(BaseModel):
    id: UUID
    email: EmailStr
    subscription_tier: str = "free"
    timezone: str = "America/Los_Angeles"
    created_at: datetime
    subscription: SubscriptionInfo = Field(
        default_factory=SubscriptionInfo,
    )


class UserUpdate(BaseModel):
    timezone: Optional[str] = None


class DealsResponse(BaseModel):
    deals: List[FlightDeal]


AuthResponse.model_rebuild()
