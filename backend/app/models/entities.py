import uuid
from datetime import datetime, timezone
from sqlalchemy import Column, String, Float, Integer, DateTime, ForeignKey, Text, UniqueConstraint, Index
from sqlalchemy.orm import relationship
from app.db.database import Base


def generate_uuid() -> str:
    return str(uuid.uuid4())


def now_utc():
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    hashed_password = Column(String(200), nullable=False)
    created_at = Column(DateTime, default=now_utc, nullable=False)

    graffitis = relationship("GraffitiModel", back_populates="owner", cascade="all, delete-orphan")
    reports = relationship("GraffitiReportModel", back_populates="reporter", cascade="all, delete-orphan")


class GraffitiModel(Base):
    __tablename__ = "graffitis"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    user_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    media_url = Column(Text, nullable=False)
    media_type = Column(String(10), nullable=False) # png, jpg, jpeg, gif
    latitude = Column(Float, nullable=False, index=True)
    longitude = Column(Float, nullable=False, index=True)
    surface_type = Column(String(30), nullable=False) # vertical_wall, horizontal_floor, horizontal_ceiling
    status = Column(String(20), default="active", nullable=False, index=True) # active, overwritten, expired, flagged_hidden
    created_at = Column(DateTime, default=now_utc, nullable=False)
    protection_until = Column(DateTime, nullable=False, index=True)
    expires_at = Column(DateTime, nullable=False, index=True)
    reports_count = Column(Integer, default=0, nullable=False)

    owner = relationship("User", back_populates="graffitis")
    reports = relationship("GraffitiReportModel", back_populates="graffiti", cascade="all, delete-orphan")

    __table_args__ = (
        Index("idx_graffitis_lat_lon", "latitude", "longitude"),
        Index("idx_graffitis_status_expires", "status", "expires_at"),
    )


class GraffitiReportModel(Base):
    __tablename__ = "graffiti_reports"

    id = Column(String(36), primary_key=True, default=generate_uuid)
    graffiti_id = Column(String(36), ForeignKey("graffitis.id", ondelete="CASCADE"), nullable=False, index=True)
    reporter_id = Column(String(36), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    reason = Column(Text, nullable=True)
    created_at = Column(DateTime, default=now_utc, nullable=False)

    graffiti = relationship("GraffitiModel", back_populates="reports")
    reporter = relationship("User", back_populates="reports")

    __table_args__ = (
        UniqueConstraint("graffiti_id", "reporter_id", name="uq_graffiti_reporter"),
    )
