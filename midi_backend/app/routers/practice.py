from typing import List, Optional
from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query, File, UploadFile, Form
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import PracticeSession, UserProgress, User
from app.schemas import PracticeSessionCreate, PracticeSessionResponse
from app.services.audio_ai_service import AudioAIService

router = APIRouter(prefix="/practice", tags=["Practice Sessions"])
_audio_service = AudioAIService()

@router.post("/submit", response_model=PracticeSessionResponse)
def submit_practice_session(session_data: PracticeSessionCreate, db: Session = Depends(get_db)):
    """Submit results of a completed MIDI or Audio practice run. Automatically updates user streak and accuracy averages."""
    user = db.query(User).filter(User.id == session_data.user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    # 1. Create Practice Session Record
    new_session = PracticeSession(
        user_id=session_data.user_id,
        exercise_id=session_data.exercise_id,
        session_type=session_data.session_type,
        accuracy_score=session_data.accuracy_score,
        stability_score=session_data.stability_score,
        bpm_played=session_data.bpm_played,
        duration_seconds=session_data.duration_seconds,
        notes_evaluated=session_data.notes_evaluated,
        ai_feedback=session_data.ai_feedback or "Great practice run! Keep up the consistent rhythm."
    )
    db.add(new_session)
    db.flush()

    # 2. Update User Progress & Streak Metrics
    progress = db.query(UserProgress).filter(UserProgress.user_id == session_data.user_id).first()
    if not progress:
        progress = UserProgress(user_id=session_data.user_id, streak_days=1, total_sessions_played=1, average_accuracy=session_data.accuracy_score, badges_count=1, last_practice_date=date.today())
        db.add(progress)
    else:
        today = date.today()
        if progress.last_practice_date != today:
            if progress.last_practice_date and (today - progress.last_practice_date).days == 1:
                progress.streak_days += 1
            elif not progress.last_practice_date or (today - progress.last_practice_date).days > 1:
                progress.streak_days = 1
            progress.last_practice_date = today

        progress.total_sessions_played += 1
        
        # Calculate new cumulative accuracy average
        total_sessions = db.query(PracticeSession).filter(PracticeSession.user_id == session_data.user_id).count()
        if total_sessions > 0:
            scores = db.query(PracticeSession.accuracy_score).filter(PracticeSession.user_id == session_data.user_id).all()
            avg_score = sum(s[0] for s in scores) // len(scores)
            progress.average_accuracy = avg_score

        # Award badge milestone
        if progress.total_sessions_played in [5, 10, 25, 50, 100]:
            progress.badges_count += 1

    db.commit()
    db.refresh(new_session)
    return new_session

@router.get("/history", response_model=List[PracticeSessionResponse])
def get_practice_history(
    user_id: int = Query(1, description="User ID to fetch history for"),
    limit: int = Query(10, description="Max history logs to return"),
    db: Session = Depends(get_db)
):
    """Retrieve history log of past practice sessions for a user."""
    sessions = (
        db.query(PracticeSession)
        .filter(PracticeSession.user_id == user_id)
        .order_by(PracticeSession.created_at.desc())
        .limit(limit)
        .all()
    )
    return sessions


@router.post("/evaluate")
async def evaluate_practice_audio(
    user_id: int = Form(..., description="User ID submitting practice audio"),
    exercise_id: Optional[str] = Form(None, description="Optional target exercise ID"),
    target_notes: Optional[str] = Form(None, description="Optional target notes"),
    file: UploadFile = File(..., description="Uploaded audio file"),
    db: Session = Depends(get_db)
):
    """
    Evaluate recorded audio against target exercise notes using the AI Audio Engine (RMVPE).
    """
    db_user = db.query(User).filter(User.id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail=f"User with ID {user_id} not found in database.")

    if not file.filename:
        raise HTTPException(status_code=400, detail="No filename provided")


    audio_bytes = await file.read()
    if len(audio_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty audio file")

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
        result = _audio_service.process_audio_practice(
            db=db,
            user_id=user_id,
            audio_bytes=audio_bytes,
            exercise_id=exercise_id,
            target_notes=target_notes_list
        )
        if result.get("status") == "model_not_available":
            raise HTTPException(status_code=503, detail=result["message"])
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Evaluation failed: {str(e)}")
