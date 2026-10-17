from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.core.security import get_password_hash, verify_password, create_access_token
from app.db.database import get_db
from app.models.entities import User
from app.models.graffiti import UserCreate, UserLogin, TokenResponse
from app.core.auth import get_current_user

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(payload: UserCreate, db: Session = Depends(get_db)):
    """Cria uma nova conta de usuário para o jogador."""
    if db.query(User).filter(User.username == payload.username).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Nome de usuário já está em uso.",
        )
    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="E-mail já cadastrado.",
        )

    user = User(
        username=payload.username,
        email=payload.email,
        hashed_password=get_password_hash(payload.password),
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token(data={"sub": user.id, "username": user.username})
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        username=user.username,
    )


@router.post("/login", response_model=TokenResponse)
def login(payload: UserLogin, db: Session = Depends(get_db)):
    """Realiza o login via email ou nome de usuário."""
    user = (
        db.query(User)
        .filter(
            (User.email == payload.email_or_username)
            | (User.username == payload.email_or_username)
        )
        .first()
    )
    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Credenciais incorretas.",
        )

    token = create_access_token(data={"sub": user.id, "username": user.username})
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=user.id,
        username=user.username,
    )


@router.post("/guest", response_model=TokenResponse)
def guest_login(db: Session = Depends(get_db)):
    """
    Cria ou autentica uma sessão rápida de convidado para testar o MVP
    sem necessidade de preencher formulários na tela mobile.
    """
    guest = db.query(User).filter(User.username == "guest_player").first()
    if not guest:
        guest = User(
            username="guest_player",
            email="guest@graffiti.local",
            hashed_password=get_password_hash("guest123"),
        )
        db.add(guest)
        db.commit()
        db.refresh(guest)

    token = create_access_token(data={"sub": guest.id, "username": guest.username})
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user_id=guest.id,
        username=guest.username,
    )


@router.get("/me")
def get_me(current_user: User = Depends(get_current_user)):
    """Retorna dados do usuário atualmente autenticado."""
    return {
        "id": current_user.id,
        "username": current_user.username,
        "email": current_user.email,
        "created_at": current_user.created_at,
    }
