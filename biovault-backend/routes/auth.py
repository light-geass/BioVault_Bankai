# biovault-backend/routes/auth.py
import os
import hashlib
import uuid
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from passlib.context import CryptContext
from jose import JWTError, jwt
from dotenv import load_dotenv

from db.database import get_db
from models.schemas import UserCreate, BiometricLogin

load_dotenv()

router = APIRouter()

# ── Security config ─────────────────────────────────────────────
SECRET_KEY = os.getenv("SECRET_KEY", "biovault-dev-secret-key-change-in-prod")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_HOURS = 24

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login/biometric")


# ── Helpers ─────────────────────────────────────────────────────
def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(hours=ACCESS_TOKEN_EXPIRE_HOURS)
    to_encode.update({"exp": expire})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def generate_biometric_hash(device_id: str, user_id: str) -> str:
    return hashlib.sha256(f"{device_id}{user_id}".encode()).hexdigest()


# ── Dependency: get current user from JWT ───────────────────────
async def get_current_user(
    token: str = Depends(oauth2_scheme),
    db=Depends(get_db),
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = await db["users"].find_one({"_id": user_id})
    if user is None:
        raise credentials_exception
    return user


# ── POST /register ──────────────────────────────────────────────
@router.post("/register", status_code=status.HTTP_201_CREATED)
async def register(user: UserCreate, db=Depends(get_db)):
    # Check if email already exists
    existing = await db["users"].find_one({"email": user.email})
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    user_id = str(uuid.uuid4())
    wallet_address = "BV-mock-" + user_id[:8]
    biometric_hash = generate_biometric_hash(user.device_id, user_id)
    hashed_pw = hash_password(user.password)

    user_doc = {
        "_id": user_id,
        "name": user.name,
        "email": user.email,
        "password_hash": hashed_pw,
        "device_id": user.device_id,
        "wallet_address": wallet_address,
        "balance": 2500.00,
        "biometric_hash": biometric_hash,
        "geo_lock": {"enabled": False, "safe_zones": []},
        "recovery": {"enabled": False, "trusted_contacts": [], "approvals_needed": 1},
        "created_at": datetime.utcnow(),
    }

    await db["users"].insert_one(user_doc)

    return {
        "user_id": user_id,
        "name": user.name,
        "email": user.email,
        "wallet_address": wallet_address,
        "biometric_hash": biometric_hash,
    }


# ── POST /login/biometric ──────────────────────────────────────
@router.post("/login/biometric")
async def login_biometric(creds: BiometricLogin, db=Depends(get_db)):
    user = await db["users"].find_one(
        {"device_id": creds.device_id, "biometric_hash": creds.biometric_hash}
    )

    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid biometric credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(data={"sub": user["_id"]})

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user["_id"],
        "wallet_address": user["wallet_address"],
    }
