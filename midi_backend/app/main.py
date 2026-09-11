import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.database import engine
from app.models import Base
from app.routers import (
    auth, trainer, exercises, practice, dashboard, settings as settings_router, audio_ai
)

# Auto-create all 6 database tables in MySQL upon startup
try:
    Base.metadata.create_all(bind=engine)
except Exception as e:
    print(f"Database table verification notice (MySQL connection status): {e}")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="Python REST API backend service for Music Tutor application powering JWT authentication, Trainer-Trainee management, dynamic exercises, practice tracking, streaks, and settings.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS Middleware for Flutter Web and Mobile clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_origin_regex=r"^https?://.*",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include API Routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(trainer.router, prefix=settings.API_V1_STR)
app.include_router(exercises.router, prefix=settings.API_V1_STR)
app.include_router(practice.router, prefix=settings.API_V1_STR)
app.include_router(dashboard.router, prefix=settings.API_V1_STR)
app.include_router(settings_router.router, prefix=settings.API_V1_STR)
app.include_router(audio_ai.router, prefix=settings.API_V1_STR)

@app.get("/", tags=["Health Check"])
def health_check():
    """Health check endpoint to verify backend service status."""
    return {
        "status": "online",
        "service": settings.PROJECT_NAME,
        "docs_url": "/docs"
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
