# biovault-backend/main.py
import logging
from datetime import datetime
from contextlib import asynccontextmanager

from fastapi import FastAPI
from apscheduler.schedulers.asyncio import AsyncIOScheduler

from fastapi.middleware.cors import CORSMiddleware
from routes import auth, wallet, geolock, timelock, recovery
from db.database import get_db

logger = logging.getLogger("biovault")
logging.basicConfig(level=logging.INFO)


# ── APScheduler background job ──────────────────────────────────
async def check_timelocked_transfers():
    """Runs every 60s – marks due timelocked transfers as notified."""
    db = get_db()
    now = datetime.utcnow()

    cursor = db["timelocked_transfers"].find({
        "status": "pending",
        "scheduled_at": {"$lte": now},
        "notified": False,
    })

    count = 0
    async for doc in cursor:
        await db["timelocked_transfers"].update_one(
            {"_id": doc["_id"]},
            {"$set": {"notified": True}},
        )
        logger.info(
            f"[TimeLock] Notification sent for transfer {doc['_id']} "
            f"→ {doc['receiver_wallet']} ({doc['amount']} BVC)"
        )
        count += 1

    if count:
        logger.info(f"[TimeLock] Processed {count} due transfer(s)")


# ── Lifespan (startup / shutdown) ───────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler = AsyncIOScheduler()
    scheduler.add_job(check_timelocked_transfers, "interval", seconds=60)
    scheduler.start()
    logger.info("[Scheduler] APScheduler started – checking timelocks every 60s")
    yield
    scheduler.shutdown()
    logger.info("[Scheduler] APScheduler shut down")


app = FastAPI(title="BioVault API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routers
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(wallet.router, prefix="/wallet", tags=["wallet"])
app.include_router(geolock.router, prefix="/geolock", tags=["geolock"])
app.include_router(timelock.router, prefix="/timelock", tags=["timelock"])
app.include_router(recovery.router, prefix="/recovery", tags=["recovery"])


@app.get("/")
async def root():
    return {"message": "Welcome to BioVault API", "status": "running"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
