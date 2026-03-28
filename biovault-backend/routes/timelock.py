# biovault-backend/routes/timelock.py
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from typing import Optional

from db.database import get_db
from routes.auth import get_current_user

router = APIRouter()


# ── Request schemas ─────────────────────────────────────────────
class TimelockCreate(BaseModel):
    receiver_wallet: str
    amount: float
    scheduled_at: datetime  # ISO 8601 string
    note: str = ""


class TimelockConfirm(BaseModel):
    transfer_id: str
    biometric_confirmed: bool


# ── POST /timelock/create ───────────────────────────────────────
@router.post("/create", status_code=status.HTTP_201_CREATED)
async def create_timelock(
    body: TimelockCreate,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    transfer_id = str(uuid.uuid4())

    doc = {
        "_id": transfer_id,
        "sender_wallet": current_user["wallet_address"],
        "receiver_wallet": body.receiver_wallet,
        "amount": body.amount,
        "scheduled_at": body.scheduled_at,
        "note": body.note,
        "status": "pending",
        "notified": False,
        "created_at": datetime.utcnow(),
    }
    await db["timelocked_transfers"].insert_one(doc)

    return {
        "transfer_id": transfer_id,
        "scheduled_at": body.scheduled_at.isoformat(),
        "status": "pending",
    }


# ── GET /timelock/{user_id} ─────────────────────────────────────
@router.get("/{user_id}")
async def get_pending_timelocks(
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

    wallet = user["wallet_address"]

    cursor = db["timelocked_transfers"].find({
        "$or": [
            {"sender_wallet": wallet},
            {"receiver_wallet": wallet},
        ],
        "status": "pending",
    }).sort("scheduled_at", 1)

    transfers = []
    async for doc in cursor:
        transfers.append({
            "id": doc["_id"],
            "sender_wallet": doc["sender_wallet"],
            "receiver_wallet": doc["receiver_wallet"],
            "amount": doc["amount"],
            "scheduled_at": doc["scheduled_at"].isoformat() if isinstance(doc["scheduled_at"], datetime) else doc["scheduled_at"],
            "note": doc.get("note", ""),
            "status": doc["status"],
            "notified": doc["notified"],
        })

    return transfers


# ── POST /timelock/confirm ──────────────────────────────────────
@router.post("/confirm")
async def confirm_timelock(
    body: TimelockConfirm,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    # Biometric check
    if not body.biometric_confirmed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Biometric confirmation required",
        )

    # Find the transfer
    transfer = await db["timelocked_transfers"].find_one({"_id": body.transfer_id})
    if not transfer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transfer not found",
        )

    if transfer["status"] != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Transfer is already {transfer['status']}",
        )

    # Check sender has enough balance
    sender = await db["users"].find_one({"wallet_address": transfer["sender_wallet"]})
    if not sender or sender["balance"] < transfer["amount"]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Insufficient balance",
        )

    # Find receiver
    receiver = await db["users"].find_one({"wallet_address": transfer["receiver_wallet"]})
    if not receiver:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Receiver wallet not found",
        )

    # Execute balance transfer
    new_sender_balance = sender["balance"] - transfer["amount"]
    await db["users"].update_one(
        {"_id": sender["_id"]},
        {"$set": {"balance": new_sender_balance}},
    )
    await db["users"].update_one(
        {"_id": receiver["_id"]},
        {"$inc": {"balance": transfer["amount"]}},
    )

    # Mark transfer completed
    await db["timelocked_transfers"].update_one(
        {"_id": body.transfer_id},
        {"$set": {"status": "completed", "completed_at": datetime.utcnow()}},
    )

    return {
        "status": "completed",
        "new_balance": new_sender_balance,
    }


# ── DELETE /timelock/{id} ───────────────────────────────────────
@router.delete("/{id}")
async def cancel_timelock(
    id: str,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    transfer = await db["timelocked_transfers"].find_one({"_id": id})
    if not transfer:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Transfer not found",
        )

    if transfer["status"] != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Transfer is already {transfer['status']}",
        )

    await db["timelocked_transfers"].update_one(
        {"_id": id},
        {"$set": {"status": "cancelled"}},
    )

    return {"status": "cancelled", "transfer_id": id}
