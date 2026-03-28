# biovault-backend/routes/geolock.py
import math

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from db.database import get_db
from routes.auth import get_current_user

router = APIRouter()


# ── Request schemas (local to this router) ──────────────────────
class GeoToggle(BaseModel):
    enabled: bool


class AddZone(BaseModel):
    lat: float
    lng: float
    radius_meters: int
    label: str


class CoordsCheck(BaseModel):
    lat: float
    lng: float


# ── Haversine helper ────────────────────────────────────────────
EARTH_RADIUS_M = 6_371_000  # meters


def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Return distance in meters between two (lat, lng) points."""
    lat1, lng1, lat2, lng2 = map(math.radians, [lat1, lng1, lat2, lng2])
    dlat = lat2 - lat1
    dlng = lng2 - lng1
    a = (
        math.sin(dlat / 2) ** 2
        + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
    )
    return 2 * EARTH_RADIUS_M * math.asin(math.sqrt(a))


# ── POST /geolock/toggle ───────────────────────────────────────
@router.post("/toggle")
async def toggle_geolock(
    body: GeoToggle,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    await db["users"].update_one(
        {"_id": current_user["_id"]},
        {"$set": {"geo_lock.enabled": body.enabled}},
    )
    state = "enabled" if body.enabled else "disabled"
    return {
        "enabled": body.enabled,
        "message": f"Geo-lock {state}",
    }


# ── POST /geolock/add-zone ─────────────────────────────────────
@router.post("/add-zone")
async def add_zone(
    body: AddZone,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    zone = {
        "lat": body.lat,
        "lng": body.lng,
        "radius_meters": body.radius_meters,
        "label": body.label,
    }
    await db["users"].update_one(
        {"_id": current_user["_id"]},
        {"$push": {"geo_lock.safe_zones": zone}},
    )

    # Return updated zones list
    user = await db["users"].find_one({"_id": current_user["_id"]})
    return {"safe_zones": user["geo_lock"]["safe_zones"]}


# ── POST /geolock/verify ───────────────────────────────────────
@router.post("/verify")
async def verify_location(
    body: CoordsCheck,
    db=Depends(get_db),
    current_user: dict = Depends(get_current_user),
):
    geo_lock = current_user.get("geo_lock", {})

    # If geo-lock is disabled, always safe
    if not geo_lock.get("enabled", False):
        return {"safe": True, "reason": "geo-lock disabled"}

    safe_zones = geo_lock.get("safe_zones", [])

    # No zones configured
    if not safe_zones:
        return {"safe": False, "reason": "no zones configured"}

    # Check each zone
    for zone in safe_zones:
        dist = haversine(body.lat, body.lng, zone["lat"], zone["lng"])
        if dist <= zone["radius_meters"]:
            return {"safe": True, "zone_label": zone.get("label", "unknown")}

    return {"safe": False, "reason": "Not in safe zone"}
