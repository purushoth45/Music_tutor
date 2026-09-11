from typing import List, Optional
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import Exercise, SkillLevelEnum, CategoryEnum
from app.schemas import ExerciseResponse

router = APIRouter(prefix="/exercises", tags=["Exercises"])

@router.get("", response_model=List[ExerciseResponse])
def get_exercises(
    skill_level: Optional[SkillLevelEnum] = Query(None, description="Filter exercises by level: BEGINNER, MODERATE, PRO"),
    category: Optional[CategoryEnum] = Query(None, description="Filter exercises by category: MIDI, AUDIO, THEORY"),
    db: Session = Depends(get_db)
):
    """Retrieve catalog of practice exercises filtered dynamically by level and category."""
    query = db.query(Exercise)
    
    if skill_level:
        query = query.filter(Exercise.skill_level == skill_level)
    if category:
        query = query.filter(Exercise.category == category)

    exercises = query.all()
    return exercises

@router.get("/{exercise_id}", response_model=ExerciseResponse)
def get_exercise_by_id(exercise_id: str, db: Session = Depends(get_db)):
    """Retrieve details for a specific exercise by ID."""
    exercise = db.query(Exercise).filter(Exercise.id == exercise_id).first()
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")
    return exercise
