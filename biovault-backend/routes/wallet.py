# biovault-backend/routes/wallet.py
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status

from db.database import get_db
from models.schemas import TransactionCreate
from routes.auth import get_current_user

router = APIRouter()


# ── GET /wallet/{user_id} ───────────────────────────────────────
@router.get("/{user_id}")
async def get_wallet(
    user_id: str,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    user = await db["users"].find_one({"_id": user_id})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return {
        "wallet_address": user["wallet_address"],
        "balance": user["balance"],
        "name": user["name"],
    }


# ── POST /transaction ──────────────────────────────────────────
@router.post("/transaction")
async def create_transaction(
    txn: TransactionCreate,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    # ── Geo-lock check ──────────────────────────────────────────
    if not txn.geo_verified:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Transaction blocked: Not in safe zone",
        )

    # ── Biometric tier check ────────────────────────────────────
    if txn.amount >= 500 and txn.biometric_used != "face_id":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Transactions >= 500 require face_id authentication",
        )

    # ── Sufficient balance check ────────────────────────────────
    sender = current_user
    if sender["balance"] < txn.amount:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Insufficient balance",
        )

    # ── Find receiver ───────────────────────────────────────────
    receiver = await db["users"].find_one(
        {"wallet_address": txn.receiver_wallet}
    )
    if not receiver:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Receiver wallet not found",
        )

    # ── Update balances ─────────────────────────────────────────
    new_sender_balance = sender["balance"] - txn.amount
    await db["users"].update_one(
        {"_id": sender["_id"]},
        {"$set": {"balance": new_sender_balance}},
    )
    await db["users"].update_one(
        {"_id": receiver["_id"]},
        {"$inc": {"balance": txn.amount}},
    )

    # ── Record transaction ──────────────────────────────────────
    transaction_id = str(uuid.uuid4())
    txn_doc = {
        "_id": transaction_id,
        "sender_wallet": sender["wallet_address"],
        "receiver_wallet": txn.receiver_wallet,
        "amount": txn.amount,
        "status": "completed",
        "biometric_used": txn.biometric_used,
        "geo_verified": txn.geo_verified,
        "timestamp": datetime.utcnow(),
    }
    await db["transactions"].insert_one(txn_doc)

    return {
        "transaction_id": transaction_id,
        "status": "completed",
        "new_balance": new_sender_balance,
    }


# ── GET /history/{user_id} ─────────────────────────────────────
@router.get("/history/{user_id}")
async def get_history(
    user_id: str,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    # Look up user's wallet address
    user = await db["users"].find_one({"_id": user_id})
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    wallet = user["wallet_address"]

    # Fetch last 20 transactions involving this wallet
    cursor = db["transactions"].find(
        {"$or": [
            {"sender_wallet": wallet},
            {"receiver_wallet": wallet},
        ]}
    ).sort("timestamp", -1).limit(20)

    transactions = []
    async for doc in cursor:
        direction = "sent" if doc["sender_wallet"] == wallet else "received"
        transactions.append({
            "id": doc["_id"],
            "sender_wallet": doc["sender_wallet"],
            "receiver_wallet": doc["receiver_wallet"],
            "amount": doc["amount"],
            "status": doc["status"],
            "biometric_used": doc["biometric_used"],
            "geo_verified": doc["geo_verified"],
            "timestamp": doc["timestamp"].isoformat(),
            "direction": direction,
        })

    return transactions
