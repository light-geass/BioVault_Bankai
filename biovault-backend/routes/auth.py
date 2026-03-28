# e:/BioVault/biovault-backend/routes/auth.py
from fastapi import APIRouter

router = APIRouter()

@router.get("/test")
async def test_auth():
    return {"status": "ok", "module": "auth"}
