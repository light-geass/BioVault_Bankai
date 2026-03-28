# biovault-backend/routes/recovery.py
import uuid
import hashlib
from datetime import datetime
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from db.database import get_db
from routes.auth import get_current_user

router = APIRouter()


# ── Request schemas ─────────────────────────────────────────────
class RecoveryEnable(BaseModel):
    trusted_contacts: List[str]  # list of user_ids
    approvals_needed: int


class RecoveryToggle(BaseModel):
    enabled: bool


class RecoveryRequestCreate(BaseModel):
    new_device_id: str


class RecoveryApprove(BaseModel):
    recovery_id: str


# ── POST /recovery/enable ──────────────────────────────────────
@router.post("/enable")
async def enable_recovery(
    body: RecoveryEnable,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    await db["users"].update_one(
        {"_id": current_user["_id"]},
        {"$set": {
            "recovery.enabled": True,
            "recovery.trusted_contacts": body.trusted_contacts,
            "recovery.approvals_needed": body.approvals_needed,
        }},
    )

    return {
        "enabled": True,
        "trusted_contacts": body.trusted_contacts,
        "approvals_needed": body.approvals_needed,
    }


# ── POST /recovery/toggle ──────────────────────────────────────
@router.post("/toggle")
async def toggle_recovery(
    body: RecoveryToggle,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    await db["users"].update_one(
        {"_id": current_user["_id"]},
        {"$set": {"recovery.enabled": body.enabled}},
    )

    state = "enabled" if body.enabled else "disabled"
    return {"enabled": body.enabled, "message": f"Recovery {state}"}


# ── POST /recovery/request ─────────────────────────────────────
@router.post("/request")
async def create_recovery_request(
    body: RecoveryRequestCreate,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    recovery_cfg = current_user.get("recovery", {})

    if not recovery_cfg.get("enabled", False):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Recovery is not enabled for this account",
        )

    trusted_contacts = recovery_cfg.get("trusted_contacts", [])
    if not trusted_contacts:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No trusted contacts configured",
        )

    recovery_id = str(uuid.uuid4())
    doc = {
        "_id": recovery_id,
        "requester_id": current_user["_id"],
        "trusted_contacts": trusted_contacts,
        "approvals_received": [],
        "status": "pending",
        "new_device_id": body.new_device_id,
        "created_at": datetime.utcnow(),
    }
    await db["recovery_requests"].insert_one(doc)

    return {
        "recovery_id": recovery_id,
        "contacts_notified": len(trusted_contacts),
        "approvals_needed": recovery_cfg.get("approvals_needed", 1),
    }


# ── POST /recovery/approve ─────────────────────────────────────
@router.post("/approve")
async def approve_recovery(
    body: RecoveryApprove,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    # Find the recovery request
    request = await db["recovery_requests"].find_one({"_id": body.recovery_id})
    if not request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recovery request not found",
        )

    if request["status"] != "pending":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Recovery request is already {request['status']}",
        )

    # Verify approver is a trusted contact of the requester
    requester = await db["users"].find_one({"_id": request["requester_id"]})
    if not requester:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Requester not found",
        )

    trusted = requester.get("recovery", {}).get("trusted_contacts", [])
    approver_id = current_user["_id"]

    if approver_id not in trusted:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a trusted contact for this account",
        )

    # Add approval (idempotent – skip if already approved)
    if approver_id not in request["approvals_received"]:
        await db["recovery_requests"].update_one(
            {"_id": body.recovery_id},
            {"$push": {"approvals_received": approver_id}},
        )

    # Re-fetch to get updated count
    request = await db["recovery_requests"].find_one({"_id": body.recovery_id})
    approvals_received = len(request["approvals_received"])
    approvals_needed = requester.get("recovery", {}).get("approvals_needed", 1)

    wallet_restored = False

    # Check if threshold met
    if approvals_received >= approvals_needed:
        # Approve: update status + migrate device_id + regenerate biometric_hash
        new_device_id = request["new_device_id"]
        new_biometric_hash = hashlib.sha256(
            f"{new_device_id}{requester['_id']}".encode()
        ).hexdigest()

        await db["users"].update_one(
            {"_id": requester["_id"]},
            {"$set": {
                "device_id": new_device_id,
                "biometric_hash": new_biometric_hash,
            }},
        )
        await db["recovery_requests"].update_one(
            {"_id": body.recovery_id},
            {"$set": {"status": "approved"}},
        )
        wallet_restored = True

    return {
        "status": "approved" if wallet_restored else "pending",
        "approvals_received": approvals_received,
        "approvals_needed": approvals_needed,
        "wallet_restored": wallet_restored,
    }


# ── GET /recovery/status/{recovery_id} ─────────────────────────
@router.get("/status/{recovery_id}")
async def get_recovery_status(
    recovery_id: str,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    request = await db["recovery_requests"].find_one({"_id": recovery_id})
    if not request:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Recovery request not found",
        )

    return {
        "id": request["_id"],
        "requester_id": request["requester_id"],
        "trusted_contacts": request["trusted_contacts"],
        "approvals_received": request["approvals_received"],
        "status": request["status"],
        "new_device_id": request["new_device_id"],
        "created_at": request["created_at"].isoformat() if isinstance(request["created_at"], datetime) else request["created_at"],
    }
