import os
import uuid
from datetime import datetime, timedelta, timezone
from typing import List, Optional
from fastapi import HTTPException, status, UploadFile
from sqlalchemy.orm import Session
from app.core.config import settings
from app.models.entities import GraffitiModel, GraffitiReportModel, User
from app.models.graffiti import GraffitiResponse, SurfaceType, GraffitiStatus
from app.services.spatial import haversine_distance, get_bounding_box


def ensure_utc(dt: Optional[datetime]) -> datetime:
    if dt is None:
        return datetime.now(timezone.utc)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt


class GraffitiService:
    def __init__(self, db: Session):
        self.db = db
        # Garante que a pasta de uploads local exista
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

    def get_nearby_graffitis(
        self, lat: float, lon: float, radius_meters: float = 50.0
    ) -> List[GraffitiResponse]:
        """
        Retorna todos os grafites ativos dentro do raio estipulado.
        Usa bounding-box para filtragem rápida no SQLite e Haversine para precisão métrica.
        """
        now = datetime.now(timezone.utc)
        min_lat, max_lat, min_lon, max_lon = get_bounding_box(lat, lon, radius_meters)

        # 1. Pré-filtragem indexada no SQLite
        candidates = (
            self.db.query(GraffitiModel)
            .filter(
                GraffitiModel.status == GraffitiStatus.ACTIVE.value,
                GraffitiModel.expires_at > now,
                GraffitiModel.latitude >= min_lat,
                GraffitiModel.latitude <= max_lat,
                GraffitiModel.longitude >= min_lon,
                GraffitiModel.longitude <= max_lon,
            )
            .all()
        )

        results = []
        for g in candidates:
            dist = haversine_distance(lat, lon, g.latitude, g.longitude)
            if dist <= radius_meters:
                is_prot = now < ensure_utc(g.protection_until)
                results.append(
                    GraffitiResponse(
                        id=g.id,
                        user_id=g.user_id,
                        media_url=g.media_url,
                        media_type=g.media_type,
                        latitude=g.latitude,
                        longitude=g.longitude,
                        surface_type=SurfaceType(g.surface_type),
                        status=GraffitiStatus(g.status),
                        created_at=ensure_utc(g.created_at),
                        protection_until=ensure_utc(g.protection_until),
                        expires_at=ensure_utc(g.expires_at),
                        is_protected=is_prot,
                        distance_meters=round(dist, 2),
                    )
                )

        # Ordena do mais próximo para o mais distante
        results.sort(key=lambda x: x.distance_meters if x.distance_meters is not None else 0.0)
        return results

    async def claim_spot(
        self,
        user_id: str,
        lat: float,
        lon: float,
        surface_type: SurfaceType,
        file: UploadFile,
    ) -> GraffitiResponse:
        """
        Regra King of the Hill com SQLite:
        1. Valida tamanho e formato (PNG, JPG, GIF).
        2. Checa se há arte ativa no raio de 10 metros.
        3. Se houver e estiver protegida (<24h), retorna 409 Conflict.
        4. Se já passou das 24h, marca a antiga como 'overwritten'.
        5. Salva o arquivo em disco local (/uploads).
        6. Persiste novo registro no SQLite.
        """
        # 1. Validação de formato de mídia
        filename = file.filename or ""
        media_type = filename.split(".")[-1].lower() if "." in filename else ""
        if media_type not in ["png", "jpg", "jpeg", "gif"]:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Formato inválido. Use apenas PNG, JPG ou GIF.",
            )

        content = await file.read()
        file_size = len(content)

        max_size = (
            settings.MAX_GIF_SIZE_BYTES
            if media_type == "gif"
            else settings.MAX_IMAGE_SIZE_BYTES
        )
        if file_size > max_size:
            max_mb = max_size // (1024 * 1024)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Arquivo excede o limite máximo permitido de {max_mb}MB.",
            )

        now = datetime.now(timezone.utc)

        # 2. Verificar colisão de 10 metros no SQLite
        min_lat, max_lat, min_lon, max_lon = get_bounding_box(
            lat, lon, settings.SPATIAL_EXCLUSIVITY_RADIUS_METERS
        )
        nearby_spots = (
            self.db.query(GraffitiModel)
            .filter(
                GraffitiModel.status == GraffitiStatus.ACTIVE.value,
                GraffitiModel.expires_at > now,
                GraffitiModel.latitude >= min_lat,
                GraffitiModel.latitude <= max_lat,
                GraffitiModel.longitude >= min_lon,
                GraffitiModel.longitude <= max_lon,
            )
            .all()
        )

        existing_spot: Optional[GraffitiModel] = None
        for spot in nearby_spots:
            dist = haversine_distance(lat, lon, spot.latitude, spot.longitude)
            if dist <= settings.SPATIAL_EXCLUSIVITY_RADIUS_METERS:
                existing_spot = spot
                break

        if existing_spot:
            existing_prot = ensure_utc(existing_spot.protection_until)
            if now < existing_prot:
                diff_seconds = (existing_prot - now).total_seconds()
                hours_left = max(0.1, round(diff_seconds / 3600.0, 1))
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Este local está sob proteção de 24 horas por outro grafiteiro. Restam {hours_left}h.",
                )
            else:
                # Conquista o território: sobrescreve a arte antiga
                existing_spot.status = GraffitiStatus.OVERWRITTEN.value
                self.db.add(existing_spot)

        # 3. Salvar arquivo no disco local
        file_id = str(uuid.uuid4())
        saved_filename = f"{file_id}.{media_type}"
        file_path = os.path.join(settings.UPLOAD_DIR, saved_filename)

        with open(file_path, "wb") as f:
            f.write(content)

        # URL pública para o frontend
        media_url = f"{settings.STATIC_UPLOADS_URL}/{saved_filename}"

        # 4. Criar registro no banco SQLite
        prot_until = now + timedelta(hours=settings.PROTECTION_DURATION_HOURS)
        exp_at = now + timedelta(days=settings.EXPIRATION_DURATION_DAYS)

        new_graffiti = GraffitiModel(
            id=file_id,
            user_id=user_id,
            media_url=media_url,
            media_type=media_type,
            latitude=lat,
            longitude=lon,
            surface_type=surface_type.value,
            status=GraffitiStatus.ACTIVE.value,
            created_at=now,
            protection_until=prot_until,
            expires_at=exp_at,
            reports_count=0,
        )

        self.db.add(new_graffiti)
        self.db.commit()
        self.db.refresh(new_graffiti)

        return GraffitiResponse(
            id=new_graffiti.id,
            user_id=new_graffiti.user_id,
            media_url=new_graffiti.media_url,
            media_type=new_graffiti.media_type,
            latitude=new_graffiti.latitude,
            longitude=new_graffiti.longitude,
            surface_type=SurfaceType(new_graffiti.surface_type),
            status=GraffitiStatus(new_graffiti.status),
            created_at=ensure_utc(new_graffiti.created_at),
            protection_until=ensure_utc(new_graffiti.protection_until),
            expires_at=ensure_utc(new_graffiti.expires_at),
            is_protected=True,
            distance_meters=0.0,
        )

    def report_graffiti(self, user_id: str, graffiti_id: str, reason: Optional[str]) -> GraffitiReportModel:
        """Registra denúncia e auto-oculta ao atingir o limite estipulado."""
        graffiti = self.db.query(GraffitiModel).filter(GraffitiModel.id == graffiti_id).first()
        if not graffiti:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Grafite não encontrado.",
            )

        existing_report = (
            self.db.query(GraffitiReportModel)
            .filter(
                GraffitiReportModel.graffiti_id == graffiti_id,
                GraffitiReportModel.reporter_id == user_id,
            )
            .first()
        )
        if existing_report:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Você já denunciou este grafite anteriormente.",
            )

        report = GraffitiReportModel(
            graffiti_id=graffiti_id,
            reporter_id=user_id,
            reason=reason,
        )
        self.db.add(report)

        graffiti.reports_count += 1
        if graffiti.reports_count >= settings.MAX_REPORTS_BEFORE_HIDE:
            graffiti.status = GraffitiStatus.FLAGGED_HIDDEN.value

        self.db.commit()
        self.db.refresh(report)
        return report

    def delete_graffiti(self, graffiti_id: str) -> bool:
        """Deleta um grafite específico e seu arquivo associado."""
        graffiti = self.db.query(GraffitiModel).filter(GraffitiModel.id == graffiti_id).first()
        if not graffiti:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Grafite não encontrado.",
            )

        # Deleta o arquivo físico de upload se existir
        if graffiti.media_url:
            filename = os.path.basename(graffiti.media_url)
            file_path = os.path.join(settings.UPLOAD_DIR, filename)
            if os.path.exists(file_path):
                try:
                    os.remove(file_path)
                except Exception as e:
                    pass

        self.db.delete(graffiti)
        self.db.commit()
        return True

    def reset_all_graffitis(self) -> int:
        """Remove todos os grafites cadastrados e limpa a pasta de uploads (ideal para testes)."""
        count = self.db.query(GraffitiModel).delete()
        self.db.query(GraffitiReportModel).delete()
        self.db.commit()

        # Limpa os arquivos da pasta uploads
        if os.path.exists(settings.UPLOAD_DIR):
            for f in os.listdir(settings.UPLOAD_DIR):
                file_path = os.path.join(settings.UPLOAD_DIR, f)
                if os.path.isfile(file_path):
                    try:
                        os.remove(file_path)
                    except Exception:
                        pass

        return count

