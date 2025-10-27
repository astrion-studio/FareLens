"""Expose route modules for app inclusion."""

from . import alerts, auth, deals, user, watchlists

__all__ = [
    "alerts",
    "auth",
    "deals",
    "user",
    "watchlists",
]
