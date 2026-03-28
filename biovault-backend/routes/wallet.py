# e:/BioVault/biovault-backend/routes/wallet.py
from fastapi import APIRouter

router = APIRouter()

@router.get("/test")
async def test_wallet():
    return {"status": "ok", "module": "wallet"}
