# e:/BioVault/biovault-backend/routes/recovery.py
from fastapi import APIRouter

router = APIRouter()

@router.get("/test")
async def test_recovery():
    return {"status": "ok", "module": "recovery"}
