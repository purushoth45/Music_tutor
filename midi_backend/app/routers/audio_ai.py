"""
Audio AI FastAPI Router.

Provides HTTP REST endpoints for uploading audio practice recordings,
executing ML pitch inference & analysis, and retrieving AI evaluation feedback.
"""

from typing import Optional, List
from fastapi import APIRouter, Depends, File, UploadFile, Form, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User
from app.services.audio_ai_service import AudioAIService

router = APIRouter(prefix="/audio-ai", tags=["Audio AI Evaluation"])
audio_service = AudioAIService()

@router.get("/status")
def audio_ai_status():
    return {"status": "ready", "model": "rmvpe", "torchcrepe": True}

@router.post("/analyze")
@router.post("/evaluate")
async def analyze_audio_practice(
    user_id: int = Form(..., description="User ID submitting practice audio"),
    exercise_id: Optional[str] = Form(None, description="Optional target exercise ID"),
    target_notes: Optional[str] = Form(None, description="Optional comma-separated or JSON target notes"),
    file: UploadFile = File(..., description="Uploaded audio file (.wav, .flac, .mp3)"),
    db: Session = Depends(get_db)
):
    """
    Upload recorded practice audio file (.wav, .flac, .mp3) for ML pitch evaluation,
    note segmentation, stability scoring, and AI feedback generation.
    """
    # Strict validation: user must exist in MySQL users table
    db_user = db.query(User).filter(User.id == user_id).first()
    if not db_user:
        raise HTTPException(
            status_code=404,
            detail=f"User with ID {user_id} not found in database."
        )

    if not file.filename:
        raise HTTPException(status_code=400, detail="No filename provided in upload")


    audio_bytes = await file.read()
    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file uploaded")

    target_notes_list = None
    if target_notes:
        try:
            import json
            if target_notes.strip().startswith("["):
                target_notes_list = json.loads(target_notes)
            else:
                target_notes_list = [n.strip() for n in target_notes.split(",") if n.strip()]
        except Exception:
            target_notes_list = None

    try:
        result = audio_service.process_audio_practice(
            db=db,
            user_id=user_id,
            audio_bytes=audio_bytes,
            exercise_id=exercise_id,
            target_notes=target_notes_list
        )
        if result.get("status") == "model_not_available":
            raise HTTPException(
                status_code=503,
                detail=result["message"]
            )
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Audio AI processing failed: {str(e)}")
