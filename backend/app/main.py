import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from app.api.endpoints import router as graffiti_router
from app.api.auth_endpoints import router as auth_router
from app.core.config import settings
from app.db.database import engine, Base
import app.models.entities # Carrega as tabelas para o SQLAlchemy

# Cria automaticamente todas as tabelas no SQLite se não existirem
Base.metadata.create_all(bind=engine)

# Garante a existência do diretório de upload
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Backend API autossuficiente (SQLite + FastAPI) para o jogo de grafite virtual com Realidade Aumentada.",
)

# CORS liberado para testes no Flutter (Web, Emulador Android, Dispositivo Físico)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Servir uploads locais estaticamente
app.mount(
    settings.STATIC_UPLOADS_URL,
    StaticFiles(directory=settings.UPLOAD_DIR),
    name="uploads",
)

# Registro dos roteadores
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(graffiti_router, prefix=settings.API_V1_STR)


@app.get("/health", tags=["Health"])
def health_check():
    return {
        "status": "ok",
        "version": settings.VERSION,
        "database": "sqlite",
        "uploads_dir": settings.UPLOAD_DIR,
    }
