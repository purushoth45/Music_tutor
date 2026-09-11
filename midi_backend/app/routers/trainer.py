from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, UserRoleEnum, UserProgress, Exercise, TrainerAssignment, AssignmentStatusEnum, PracticeSession
from app.schemas import (
    TraineeSummaryDTO, AssignExerciseRequest, AssignmentResponse, 
    BulkAssignExerciseRequest
)
from app.security import require_trainer_role

router = APIRouter(prefix="/trainer", tags=["Trainer Management"])

@router.get("/trainees", response_model=List[TraineeSummaryDTO])
def get_my_trainees(
    current_trainer: User = Depends(require_trainer_role),
    db: Session = Depends(get_db)
):
    """Retrieve list of all Trainees / Students in the system for Trainer management."""
    # Retrieve all trainees
    trainees = db.query(User).filter(User.role == UserRoleEnum.TRAINEE).all()

    result = []
    for trainee in trainees:
        progress = db.query(UserProgress).filter(UserProgress.user_id == trainee.id).first()
        
        # Calculate dynamic realtime metrics from PracticeSession DB table
        sessions = db.query(PracticeSession).filter(PracticeSession.user_id == trainee.id).all()
        sessions_count = len(sessions)
        avg_accuracy = int(sum(s.accuracy_score for s in sessions) / sessions_count) if sessions_count > 0 else 0
        streak = (progress.streak_days if progress else 0) if sessions_count > 0 else 0

        # Get latest assigned task title
        latest_assignment = (
            db.query(TrainerAssignment)
            .filter(TrainerAssignment.trainee_id == trainee.id)
            .order_by(TrainerAssignment.assigned_at.desc())
            .first()
        )
        assignment_title: Optional[str] = None
        if latest_assignment:
            ex = db.query(Exercise).filter(Exercise.id == latest_assignment.exercise_id).first()
            if ex:
                assignment_title = ex.title

        result.append(
            TraineeSummaryDTO(
                id=trainee.id,
                username=trainee.username,
                email=trainee.email,
                full_name=trainee.full_name or trainee.username,
                skill_level=trainee.skill_level,
                streak_days=streak,
                average_accuracy=avg_accuracy,
                total_sessions_played=sessions_count,
                last_practice_date=progress.last_practice_date if (progress and sessions_count > 0) else None,
                current_assignment=assignment_title
            )
        )
    return result

@router.post("/assign-exercise", response_model=AssignmentResponse, status_code=status.HTTP_201_CREATED)
def assign_exercise_to_trainee(
    request: AssignExerciseRequest,
    current_trainer: User = Depends(require_trainer_role),
    db: Session = Depends(get_db)
):
    """Assign a practice exercise to a specific Trainee."""
    trainee = db.query(User).filter(User.id == request.trainee_id, User.role == UserRoleEnum.TRAINEE).first()
    if not trainee:
        raise HTTPException(status_code=404, detail="Trainee not found")

    exercise = db.query(Exercise).filter(Exercise.id == request.exercise_id).first()
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")

    new_assignment = TrainerAssignment(
        trainer_id=current_trainer.id,
        trainee_id=request.trainee_id,
        exercise_id=request.exercise_id,
        status=AssignmentStatusEnum.PENDING,
        notes=request.notes
    )
    db.add(new_assignment)
    db.commit()
    db.refresh(new_assignment)

    return new_assignment

@router.post("/assign-exercise-bulk", status_code=status.HTTP_201_CREATED)
def assign_exercise_bulk(
    request: BulkAssignExerciseRequest,
    current_trainer: User = Depends(require_trainer_role),
    db: Session = Depends(get_db)
):
    """Assign a common exercise/lesson to all students or level-filtered students in bulk."""
    exercise = db.query(Exercise).filter(Exercise.id == request.exercise_id).first()
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")

    query = db.query(User).filter(User.role == UserRoleEnum.TRAINEE)
    if request.skill_level:
        query = query.filter(User.skill_level == request.skill_level)
    
    target_trainees = query.all()
    if not target_trainees:
        raise HTTPException(status_code=404, detail="No students match the target skill level filter")

    created_count = 0
    for t in target_trainees:
        assignment = TrainerAssignment(
            trainer_id=current_trainer.id,
            trainee_id=t.id,
            exercise_id=request.exercise_id,
            status=AssignmentStatusEnum.PENDING,
            notes=request.notes
        )
        db.add(assignment)
        created_count += 1

    db.commit()
    return {
        "message": f"Successfully assigned '{exercise.title}' to {created_count} student(s)",
        "assigned_count": created_count
    }

@router.get("/trainee/{trainee_id}/assignments", response_model=List[AssignmentResponse])
def get_trainee_assignments(
    trainee_id: int,
    current_trainer: User = Depends(require_trainer_role),
    db: Session = Depends(get_db)
):
    """View assigned exercises for a specific trainee."""
    trainee = db.query(User).filter(User.id == trainee_id, User.role == UserRoleEnum.TRAINEE).first()
    if not trainee:
        raise HTTPException(status_code=404, detail="Trainee not found")

    assignments = db.query(TrainerAssignment).filter(TrainerAssignment.trainee_id == trainee_id).all()
    return assignments
