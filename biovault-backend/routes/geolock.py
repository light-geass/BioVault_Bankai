# e:/BioVault/biovault-backend/routes/geolock.py
from fastapi import APIRouter

router = APIRouter()

@router.get("/test")
async def test_geolock():
    return {"status": "ok", "module": "geolock"}
