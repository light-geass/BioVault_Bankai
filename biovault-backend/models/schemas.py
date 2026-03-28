# e:/BioVault/biovault-backend/models/schemas.py
from pydantic import BaseModel, Field, EmailStr
from typing import List, Optional
from uuid import UUID, uuid4
from datetime import datetime

class SafeZone(BaseModel):
    lat: float
    lng: float
    radius_meters: float

class GeoLock(BaseModel):
    enabled: bool = False
    safe_zones: List[SafeZone] = []

class Recovery(BaseModel):
    enabled: bool = False
    trusted_contacts: List[str] = []
    approvals_needed: int = 1

class UserCreate(BaseModel):
    name: str
    email: EmailStr
    password: str

class UserInDB(BaseModel):
    id: UUID = Field(default_factory=uuid4, alias="_id")
    name: str
    email: EmailStr
    wallet_address: str  # Format: BV-mock-xxx
    balance: float = 0.0
    device_id: str
    biometric_hash: str
    geo_lock: GeoLock
    recovery: Recovery
    created_at: datetime = Field(default_factory=datetime.utcnow)

    class Config:
        allow_population_by_field_name = True
        schema_extra = {
            "example": {
                "_id": "550e8400-e29b-41d4-a716-446655440000",
                "name": "Jane Doe",
                "email": "jane@example.com",
                "wallet_address": "BV-mock-0x123",
                "balance": 100.5,
                "device_id": "iphone-13-uuid",
                "biometric_hash": "abcd-efgh-ijkl-mnop",
                "geo_lock": {
                    "enabled": True,
                    "safe_zones": [{"lat": 40.7128, "lng": -74.0060, "radius_meters": 500}]
                },
                "recovery": {
                    "enabled": True,
                    "trusted_contacts": ["alice@example.com", "bob@example.com"],
                    "approvals_needed": 2
                },
                "created_at": "2026-03-28T16:20:00Z"
            }
        }

class Transaction(BaseModel):
    transaction_id: str
    sender: str
    receiver: str
    amount: float
    timestamp: datetime = Field(default_factory=datetime.utcnow)

class TimelockTransfer(BaseModel):
    transfer_id: str
    amount: float
    recipient_address: str
    release_time: datetime

class RecoveryRequest(BaseModel):
    user_id: UUID
    request_id: str
    approvals_count: int = 0
    is_completed: bool = False
