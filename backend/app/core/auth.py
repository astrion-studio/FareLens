"""JWT authentication utilities for FareLens API.

Validates Supabase JWT tokens and extracts user_id for authenticated endpoints.
"""

from typing import Optional
from uuid import UUID

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import settings

# HTTPBearer security scheme for extracting Bearer tokens
security = HTTPBearer()


def decode_jwt(token: str) -> dict:
    """Decode and validate a Supabase JWT token.

    Args:
        token: JWT token string (without "Bearer " prefix)

    Returns:
        Decoded JWT payload containing user_id (sub) and other claims

    Raises:
        HTTPException: If token is invalid, expired, or missing required claims
    """
    if not settings.supabase_jwt_secret:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="JWT secret not configured",
        )

    try:
        payload = jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            options={"verify_aud": False},  # Supabase doesn't set aud claim
        )

        # Supabase puts user ID in the "sub" claim
        if "sub" not in payload:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing user ID",
                headers={"WWW-Authenticate": "Bearer"},
            )

        return payload

    except jwt.InvalidTokenError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        ) from e


async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> UUID:
    """Extract authenticated user ID from JWT token.

    This is a FastAPI dependency that validates the JWT token and returns
    the authenticated user's UUID. Use this in endpoints that require authentication.

    Usage:
        @router.get("/protected")
        async def protected_endpoint(
            user_id: UUID = Depends(get_current_user_id)
        ):
            # user_id is guaranteed to be valid UUID of authenticated user
            ...

    Args:
        credentials: Automatically injected by FastAPI from Authorization header

    Returns:
        UUID of the authenticated user

    Raises:
        HTTPException: If token is missing, invalid, or expired
    """
    payload = decode_jwt(credentials.credentials)

    try:
        user_id = UUID(payload["sub"])
    except (ValueError, KeyError) as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid user ID in token",
            headers={"WWW-Authenticate": "Bearer"},
        ) from e

    return user_id


async def get_optional_user_id(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(
        HTTPBearer(auto_error=False)
    ),
) -> Optional[UUID]:
    """Extract user ID from JWT token if present (optional authentication).

    This is a FastAPI dependency for endpoints that work with or without authentication.
    Returns None if no token provided, validates token if present.

    Usage:
        @router.get("/optional-auth")
        async def optional_endpoint(
            user_id: Optional[UUID] = Depends(get_optional_user_id)
        ):
            if user_id:
                # Return user-specific data
            else:
                # Return public data

    Args:
        credentials: Automatically injected by FastAPI (None if no token)

    Returns:
        UUID of authenticated user, or None if no token provided

    Raises:
        HTTPException: If token is provided but invalid/expired
    """
    if credentials is None:
        return None

    return await get_current_user_id(credentials)
