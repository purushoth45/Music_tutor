import enum
from sqlalchemy import (
    Column, Integer, String, Text, Enum, JSON, ForeignKey, 
    DateTime, Date, Float, Boolean, func
)
from sqlalchemy.orm import relationship
from app.database import Base

class UserRoleEnum(str, enum.Enum):
    TRAINER = "TRAINER"
    TRAINEE = "TRAINEE"

class SkillLevelEnum(str, enum.Enum):
    BEGINNER = "BEGINNER"
    MODERATE = "MODERATE"
    PRO = "PRO"

class CategoryEnum(str, enum.Enum):
    MIDI = "MIDI"
    AUDIO = "AUDIO"
    THEORY = "THEORY"

class SessionTypeEnum(str, enum.Enum):
    MIDI = "MIDI"
    AUDIO = "AUDIO"

class ThemeModeEnum(str, enum.Enum):
    LIGHT = "LIGHT"
    DARK = "DARK"
    SYSTEM = "SYSTEM"

class AssignmentStatusEnum(str, enum.Enum):
    PENDING = "PENDING"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(100), nullable=True)
    role = Column(Enum(UserRoleEnum), default=UserRoleEnum.TRAINEE, nullable=False)
    trainer_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    skill_level = Column(Enum(SkillLevelEnum), default=SkillLevelEnum.BEGINNER)
    avatar_url = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    # Self-referential relationship for Trainer -> Trainees
    trainer = relationship("User", remote_side=[id], backref="trainees")

    progress = relationship("UserProgress", back_populates="user", uselist=False, cascade="all, delete-orphan")
    settings = relationship("UserSettings", back_populates="user", uselist=False, cascade="all, delete-orphan")
    sessions = relationship("PracticeSession", back_populates="user", cascade="all, delete-orphan")

class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(String(50), primary_key=True, index=True)
    title = Column(String(100), nullable=False)
    description = Column(Text, nullable=False)
    skill_level = Column(Enum(SkillLevelEnum), nullable=False, index=True)
    category = Column(Enum(CategoryEnum), default=CategoryEnum.MIDI, nullable=False)
    target_bpm = Column(Integer, default=80, nullable=False)
    notes_sequence = Column(JSON, nullable=False)
    ai_tip = Column(Text, nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    sessions = relationship("PracticeSession", back_populates="exercise")
    assignments = relationship("TrainerAssignment", back_populates="exercise", cascade="all, delete-orphan")

class TrainerAssignment(Base):
    __tablename__ = "trainer_assignments"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    trainer_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    trainee_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    exercise_id = Column(String(50), ForeignKey("exercises.id", ondelete="CASCADE"), nullable=False)
    status = Column(Enum(AssignmentStatusEnum), default=AssignmentStatusEnum.PENDING, nullable=False)
    notes = Column(Text, nullable=True)
    assigned_at = Column(DateTime, server_default=func.now())
    completed_at = Column(DateTime, nullable=True)

    trainer = relationship("User", foreign_keys=[trainer_id])
    trainee = relationship("User", foreign_keys=[trainee_id])
    exercise = relationship("Exercise", back_populates="assignments")

class UserProgress(Base):
    __tablename__ = "user_progress"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    streak_days = Column(Integer, default=1, nullable=False)
    total_sessions_played = Column(Integer, default=0, nullable=False)
    average_accuracy = Column(Integer, default=0, nullable=False)
    badges_count = Column(Integer, default=0, nullable=False)
    last_practice_date = Column(Date, nullable=True)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="progress")

class PracticeSession(Base):
    __tablename__ = "practice_sessions"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    exercise_id = Column(String(50), ForeignKey("exercises.id", ondelete="SET NULL"), nullable=True)
    session_type = Column(Enum(SessionTypeEnum), nullable=False)
    accuracy_score = Column(Integer, nullable=False, default=0)
    stability_score = Column(Integer, nullable=True)
    bpm_played = Column(Integer, nullable=True)
    duration_seconds = Column(Integer, nullable=False, default=60)
    notes_evaluated = Column(JSON, nullable=True)
    ai_feedback = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    user = relationship("User", back_populates="sessions")
    exercise = relationship("Exercise", back_populates="sessions")

class UserSettings(Base):
    __tablename__ = "user_settings"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    theme_mode = Column(Enum(ThemeModeEnum), default=ThemeModeEnum.SYSTEM)
    accent_palette_index = Column(Integer, default=0)
    tuning_standard = Column(String(100), default="A4 = 440 Hz (Standard)")
    metronome_count_in = Column(Boolean, default=True)
    metronome_click = Column(Boolean, default=True)
    auto_connect_midi = Column(Boolean, default=True)
    latency_profile = Column(String(50), default="Low Latency (16ms)")
    audio_feedback = Column(Boolean, default=True)
    noise_cancellation = Column(Float, default=0.75)
    mic_gain = Column(Float, default=0.8)
    daily_reminders = Column(Boolean, default=True)
    detailed_ai_tips = Column(Boolean, default=True)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", back_populates="settings")
