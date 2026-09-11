from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, UserProgress, PracticeSession, SkillLevelEnum, TrainerAssignment, Exercise
from app.schemas import DashboardSummaryResponse, PracticeSessionResponse

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])

@router.get("/summary", response_model=DashboardSummaryResponse)
def get_dashboard_summary(
    user_id: int = Query(1, description="User ID for dashboard metrics"),
    db: Session = Depends(get_db)
):
    """Retrieve full dashboard summary for a user including streak, accuracy, badges, recent sessions, and AI coach tip."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    progress = db.query(UserProgress).filter(UserProgress.user_id == user_id).first()
    if not progress:
        progress = UserProgress(
            user_id=user_id,
            streak_days=0,
            total_sessions_played=0,
            average_accuracy=0,
            badges_count=0
        )
        db.add(progress)
        db.commit()
        db.refresh(progress)

    recent_sessions_db = (
        db.query(PracticeSession)
        .filter(PracticeSession.user_id == user_id)
        .order_by(PracticeSession.created_at.desc())
        .limit(5)
        .all()
    )

    recent_sessions = [PracticeSessionResponse.from_orm(s) for s in recent_sessions_db]

    all_user_sessions = db.query(PracticeSession).filter(PracticeSession.user_id == user_id).all()
    total_sessions_count = len(all_user_sessions)
    avg_accuracy_val = int(sum(s.accuracy_score for s in all_user_sessions) / total_sessions_count) if total_sessions_count > 0 else 0
    calculated_streak = progress.streak_days if total_sessions_count > 0 else 0

    latest_assignment = (
        db.query(TrainerAssignment)
        .filter(TrainerAssignment.trainee_id == user_id)
        .order_by(TrainerAssignment.assigned_at.desc())
        .first()
    )
    assignment_title = None
    if latest_assignment:
        ex = db.query(Exercise).filter(Exercise.id == latest_assignment.exercise_id).first()
        if ex:
            assignment_title = ex.title

    ai_coach_tip = (
        f"You are making great progress on your {user.skill_level.value} level scales! "
        "Try practicing with the MIDI mode today to sync with a physical keyboard."
    )

    return DashboardSummaryResponse(
        username=user.username,
        full_name=user.full_name or user.username,
        role=user.role,
        skill_level=user.skill_level or SkillLevelEnum.BEGINNER,
        streak_days=calculated_streak,
        total_sessions_played=total_sessions_count,
        average_accuracy=avg_accuracy_val,
        badges_count=progress.badges_count,
        ai_coach_message=ai_coach_tip,
        recent_sessions=recent_sessions,
        current_assignment=assignment_title
    )

