import os
from pydantic_settings import BaseSettings, SettingsConfigDict

_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


class Settings(BaseSettings):
    PROJECT_NAME: str = "AR Graffiti API"
    VERSION: str = "0.2.0"
    API_V1_STR: str = "/api/v1"

    # SQLite & Local Storage Configuration (caminhos absolutos independentes de onde o uvicorn é executado)
    DATABASE_URL: str = f"sqlite:///{os.path.join(_BACKEND_DIR, 'graffiti.db')}"
    UPLOAD_DIR: str = os.path.join(_BACKEND_DIR, "uploads")
    STATIC_UPLOADS_URL: str = "/static/uploads"
    
    # Host base URL for constructing full media URLs (ex: http://localhost:8000)
    HOST_BASE_URL: str = "http://localhost:8000"

    # JWT Authentication
    JWT_SECRET_KEY: str = "graffiti-mvp-super-secret-key-change-in-production"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 dias

    # Game Mechanics
    SPATIAL_EXCLUSIVITY_RADIUS_METERS: float = 10.0
    PROTECTION_DURATION_HOURS: int = 24
    EXPIRATION_DURATION_DAYS: int = 7

    # Moderation & File Limits
    MAX_REPORTS_BEFORE_HIDE: int = 3
    MAX_IMAGE_SIZE_BYTES: int = 5 * 1024 * 1024   # 5 MB
    MAX_GIF_SIZE_BYTES: int = 10 * 1024 * 1024    # 10 MB

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=True, extra="ignore")


settings = Settings()
