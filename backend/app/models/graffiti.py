from datetime import datetime
from enum import Enum
from typing import Optional
from pydantic import BaseModel, Field, EmailStr


class SurfaceType(str, Enum):
    VERTICAL_WALL = "vertical_wall"
    HORIZONTAL_FLOOR = "horizontal_floor"
    HORIZONTAL_CEILING = "horizontal_ceiling"


class GraffitiStatus(str, Enum):
    ACTIVE = "active"
    OVERWRITTEN = "overwritten"
    EXPIRED = "expired"
    FLAGGED_HIDDEN = "flagged_hidden"


class GraffitiBase(BaseModel):
    latitude: float = Field(..., ge=-90.0, le=90.0)
    longitude: float = Field(..., ge=-180.0, le=180.0)
    surface_type: SurfaceType


class GraffitiResponse(GraffitiBase):
    id: str
    user_id: str
    media_url: str
    media_type: str
    status: GraffitiStatus
    created_at: datetime
    protection_until: datetime
    expires_at: datetime
    is_protected: bool = False
    distance_meters: Optional[float] = None

    class Config:
        from_attributes = True


class GraffitiReportCreate(BaseModel):
    reason: Optional[str] = Field(None, max_length=500)


class GraffitiReportResponse(BaseModel):
    id: str
    graffiti_id: str
    created_at: datetime
    message: str = "Denúncia registrada com sucesso"


# Schemas de Usuário e Autenticação
class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(..., min_length=6)


class UserLogin(BaseModel):
    email_or_username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    username: str
