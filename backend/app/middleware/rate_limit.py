"""Per-email rate limiting middleware for authentication endpoints."""

import json
import logging
from typing import Callable

from fastapi import Request, Response
from slowapi import Limiter
from slowapi.util import get_remote_address

logger = logging.getLogger(__name__)


def get_email_from_request(request: Request) -> str:
    """Extract email from request body for rate limiting.

    Returns:
        Email address from request body, or empty string if not found
    """
    try:
        # For auth endpoints, email is in the request body
        if hasattr(request.state, "body"):
            body = json.loads(request.state.body)
            return body.get("email", "")
    except Exception as e:
        logger.debug(f"Could not extract email from request: {e}")
    return ""


async def cache_request_body(request: Request, call_next: Callable) -> Response:
    """Middleware to cache request body for rate limiting by email.

    This middleware reads and caches the request body so it can be used for
    per-email rate limiting without consuming the stream.
    """
    if request.method in ["POST", "PUT", "PATCH"]:
        body = await request.body()
        request.state.body = body.decode("utf-8")

    response = await call_next(request)
    return response
