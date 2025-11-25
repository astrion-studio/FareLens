"""Application settings derived from environment variables."""

from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: Optional[str] = None
    supabase_service_role_key: Optional[str] = None
    supabase_jwt_secret: Optional[str] = None
    use_in_memory_store: bool = True
    database_pool_min_size: int = 1
    database_pool_max_size: int = 10
    rate_limit_signup: str = "5/hour"
    rate_limit_signin: str = "10/minute"
    rate_limit_reset_password: str = "3/hour"
    service_account_api_key: Optional[str] = None

    class Config:
        env_prefix = "FARELENS_"
        case_sensitive = False


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
