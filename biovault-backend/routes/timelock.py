# e:/BioVault/biovault-backend/routes/timelock.py
from fastapi import APIRouter

router = APIRouter()

@router.get("/test")
async def test_timelock():
    return {"status": "ok", "module": "timelock"}
