from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from sqlalchemy.orm import Session
from app.core.config import settings
from app.db.database import get_db
from app.models.entities import User

security = HTTPBearer(auto_error=False)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db),
) -> User:
    """
    Valida o token JWT e retorna o usuário do banco SQLite.
    Se nenhum token for fornecido no ambiente MVP, cria ou retorna um usuário de teste automático
    ('mvp_explorer') para permitir testes imediatos sem atrito.
    """
    if credentials is None:
        # Fallback de conveniência para desenvolvimento do MVP: garante que requisições sem header funcionem
        default_user = db.query(User).filter(User.username == "mvp_explorer").first()
        if not default_user:
            from app.core.security import get_password_hash
            default_user = User(
                username="mvp_explorer",
                email="explorer@graffiti.local",
                hashed_password=get_password_hash("explorer123"),
            )
            db.add(default_user)
            db.commit()
            db.refresh(default_user)
        return default_user

    token = credentials.credentials
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token de autenticação inválido",
            )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais inválidas ou expiradas",
        )

    user = db.query(User).filter(User.id == user_id).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuário associado ao token não encontrado",
        )
    return user


def get_current_user_id(user: User = Depends(get_current_user)) -> str:
    return user.id
