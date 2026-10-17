from typing import List
from fastapi import APIRouter, Depends, File, Form, Query, UploadFile, status
from sqlalchemy.orm import Session
from app.core.auth import get_current_user_id
from app.db.database import get_db
from app.models.graffiti import (
    GraffitiResponse,
    GraffitiReportCreate,
    GraffitiReportResponse,
    SurfaceType,
)
from app.services.graffiti_service import GraffitiService

router = APIRouter(prefix="/graffiti", tags=["Graffiti"])


@router.get("/nearby", response_model=List[GraffitiResponse])
def get_nearby_graffiti(
    lat: float = Query(..., ge=-90.0, le=90.0, description="Latitude atual do usuário"),
    lon: float = Query(..., ge=-180.0, le=180.0, description="Longitude atual do usuário"),
    radius: float = Query(50.0, ge=1.0, le=1000.0, description="Raio de busca em metros"),
    db: Session = Depends(get_db),
):
    """
    Lista todos os grafites ativos no raio solicitado para o mapa e visualizador AR.
    Informa se cada grafite ainda está em período de proteção de 24h.
    """
    service = GraffitiService(db)
    return service.get_nearby_graffitis(lat=lat, lon=lon, radius_meters=radius)


@router.post("/claim", response_model=GraffitiResponse, status_code=status.HTTP_201_CREATED)
async def claim_graffiti_spot(
    latitude: float = Form(..., ge=-90.0, le=90.0),
    longitude: float = Form(..., ge=-180.0, le=180.0),
    surface_type: SurfaceType = Form(...),
    file: UploadFile = File(..., description="Imagem (PNG/JPG) ou GIF a ser grafitado"),
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Reivindica um ponto geográfico e fixa a arte em um plano físico.
    Aplica a regra King of the Hill (10m de exclusividade e 24h de proteção).
    """
    service = GraffitiService(db)
    return await service.claim_spot(
        user_id=user_id,
        lat=latitude,
        lon=longitude,
        surface_type=surface_type,
        file=file,
    )


@router.post("/{graffiti_id}/report", response_model=GraffitiReportResponse)
def report_graffiti_content(
    graffiti_id: str,
    payload: GraffitiReportCreate,
    user_id: str = Depends(get_current_user_id),
    db: Session = Depends(get_db),
):
    """
    Registra uma denúncia contra um grafite impróprio.
    Grafites com 3 denúncias são automaticamente ocultados da exibição pública.
    """
    service = GraffitiService(db)
    report = service.report_graffiti(
        user_id=user_id,
        graffiti_id=graffiti_id,
        reason=payload.reason,
    )
    return GraffitiReportResponse(
        id=report.id,
        graffiti_id=graffiti_id,
        created_at=report.created_at,
    )


@router.delete("/reset/all", status_code=status.HTTP_200_OK)
def reset_all_graffiti_spots(
    db: Session = Depends(get_db),
):
    """
    [UTILITÁRIO DE TESTES]
    Remove todos os grafites e fotos da base para permitir pintar novamente no mesmo local.
    """
    service = GraffitiService(db)
    removed_count = service.reset_all_graffitis()
    return {"message": f"Todos os {removed_count} grafites e mídias foram removidos com sucesso."}


@router.delete("/{graffiti_id}", status_code=status.HTTP_200_OK)
def delete_single_graffiti(
    graffiti_id: str,
    db: Session = Depends(get_db),
):
    """
    [UTILITÁRIO DE TESTES]
    Deleta um grafite específico pelo seu ID.
    """
    service = GraffitiService(db)
    service.delete_graffiti(graffiti_id)
    return {"message": f"Grafite {graffiti_id} deletado com sucesso."}

