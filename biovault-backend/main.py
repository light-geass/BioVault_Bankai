# e:/BioVault/biovault-backend/main.py
from fastapi import FastAPI
from routes import auth, wallet, geolock, timelock, recovery

app = FastAPI(title="BioVault API")

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
