from typing import List, Optional, Any, Union, Dict
from datetime import datetime, date

from pydantic import BaseModel, EmailStr, Field
from app.models import (
    SkillLevelEnum, CategoryEnum, SessionTypeEnum, 
    ThemeModeEnum, UserRoleEnum, AssignmentStatusEnum
)

# ----------------------------------------------------------------------------
# 1. Authentication & User Schemas
# ----------------------------------------------------------------------------
class TrainerSignupRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(min_length=6)
    full_name: Optional[str] = None

class TraineeCreateRequest(BaseModel):
    username: str = Field(min_length=3, max_length=50)
    email: EmailStr
    password: str = Field(min_length=6)
    full_name: Optional[str] = None
    skill_level: SkillLevelEnum = SkillLevelEnum.BEGINNER

class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    role: Optional[str] = None

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    role: UserRoleEnum
    username: str
    full_name: Optional[str] = None
    email: str

class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    full_name: Optional[str] = None
    role: UserRoleEnum
    trainer_id: Optional[int] = None
    skill_level: SkillLevelEnum
    avatar_url: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True

# ----------------------------------------------------------------------------
# 2. Exercise & Assignment Schemas
# ----------------------------------------------------------------------------
class ExerciseBase(BaseModel):
    id: str
    title: str
    description: str
    skill_level: SkillLevelEnum
    category: CategoryEnum
    target_bpm: int
    notes_sequence: List[str]
    ai_tip: str

class ExerciseResponse(ExerciseBase):
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class AssignExerciseRequest(BaseModel):
    trainee_id: int
    exercise_id: str
    notes: Optional[str] = "Please practice this lesson before our next class."

class AssignmentResponse(BaseModel):
    id: int
    trainer_id: int
    trainee_id: int
    exercise_id: str
    status: AssignmentStatusEnum
    notes: Optional[str] = None
    assigned_at: datetime
    exercise: Optional[ExerciseResponse] = None

    class Config:
        from_attributes = True

# ----------------------------------------------------------------------------
# 3. Practice Session Schemas
# ----------------------------------------------------------------------------
class PracticeSessionCreate(BaseModel):
    user_id: int
    exercise_id: Optional[str] = None
    session_type: SessionTypeEnum
    accuracy_score: int = Field(ge=0, le=100)
    stability_score: Optional[int] = Field(default=8, ge=0, le=10)
    bpm_played: Optional[int] = 80
    duration_seconds: int = 60
    notes_evaluated: Optional[Any] = None
    ai_feedback: Optional[str] = None

class PracticeSessionResponse(BaseModel):
    id: int
    user_id: int
    exercise_id: Optional[str] = None
    session_type: SessionTypeEnum
    accuracy_score: int
    stability_score: Optional[int] = None
    bpm_played: Optional[int] = None
    duration_seconds: int
    notes_evaluated: Optional[Any] = None
    ai_feedback: Optional[str] = None
    created_at: datetime


    class Config:
        from_attributes = True

# ----------------------------------------------------------------------------
# 4. User Progress & Dashboard Schemas
# ----------------------------------------------------------------------------
class UserProgressResponse(BaseModel):
    user_id: int
    streak_days: int
    total_sessions_played: int
    average_accuracy: int
    badges_count: int
    last_practice_date: Optional[date] = None

    class Config:
        from_attributes = True

class DashboardSummaryResponse(BaseModel):
    username: str
    full_name: Optional[str] = None
    role: UserRoleEnum
    skill_level: SkillLevelEnum
    streak_days: int
    total_sessions_played: int
    average_accuracy: int
    badges_count: int
    ai_coach_message: str
    recent_sessions: List[PracticeSessionResponse]
    current_assignment: Optional[str] = None

class BulkAssignExerciseRequest(BaseModel):
    skill_level: Optional[SkillLevelEnum] = None
    exercise_id: str
    notes: Optional[str] = "Please practice this assigned lesson before our next class."

class TraineeSummaryDTO(BaseModel):
    id: int
    username: str
    email: str
    full_name: Optional[str] = None
    skill_level: SkillLevelEnum
    streak_days: int
    average_accuracy: int
    total_sessions_played: int
    last_practice_date: Optional[date] = None
    current_assignment: Optional[str] = None

# ----------------------------------------------------------------------------
# 5. User Settings Schemas
# ----------------------------------------------------------------------------
class UserSettingsBase(BaseModel):
    theme_mode: ThemeModeEnum = ThemeModeEnum.SYSTEM
    accent_palette_index: int = 0
    tuning_standard: str = "A4 = 440 Hz (Standard)"
    metronome_count_in: bool = True
    metronome_click: bool = True
    auto_connect_midi: bool = True
    latency_profile: str = "Low Latency (16ms)"
    audio_feedback: bool = True
    noise_cancellation: float = 0.75
    mic_gain: float = 0.8
    daily_reminders: bool = True
    detailed_ai_tips: bool = True

class UserSettingsUpdate(BaseModel):
    theme_mode: Optional[ThemeModeEnum] = None
    accent_palette_index: Optional[int] = None
    tuning_standard: Optional[str] = None
    metronome_count_in: Optional[bool] = None
    metronome_click: Optional[bool] = None
    auto_connect_midi: Optional[bool] = None
    latency_profile: Optional[str] = None
    audio_feedback: Optional[bool] = None
    noise_cancellation: Optional[float] = None
    mic_gain: Optional[float] = None
    daily_reminders: Optional[bool] = None
    detailed_ai_tips: Optional[bool] = None

class UserSettingsResponse(UserSettingsBase):
    user_id: int
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True
