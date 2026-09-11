import sys
import os
from datetime import date

# Add parent directory to sys.path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.database import engine, SessionLocal, Base
from app.models import (
    User, Exercise, PracticeSession, UserProgress, UserSettings, TrainerAssignment,
    SkillLevelEnum, CategoryEnum, SessionTypeEnum, ThemeModeEnum, UserRoleEnum, AssignmentStatusEnum
)
from app.security import hash_password

def seed():
    print("Creating MySQL database tables if not exist...")
    Base.metadata.create_all(bind=engine)

    db = SessionLocal()
    try:
        # 1. Seed Demo Trainer
        trainer = db.query(User).filter(User.id == 1).first()
        if not trainer:
            print("Seeding default Trainer account...")
            trainer = User(
                id=1,
                username="Master Instructor",
                email="trainer@musictutor.ai",
                password_hash=hash_password("trainer123"),
                full_name="Prof. Alexander Vance",
                role=UserRoleEnum.TRAINER
            )
            db.add(trainer)
            db.commit()
            db.refresh(trainer)

        # 2. Seed Demo Trainee (Managed by Trainer 1)
        trainee = db.query(User).filter(User.id == 2).first()
        if not trainee:
            print("Seeding default Trainee account...")
            trainee = User(
                id=2,
                username="Music Learner",
                email="student1@musictutor.ai",
                password_hash=hash_password("student123"),
                full_name="Sarah Jenkins",
                role=UserRoleEnum.TRAINEE,
                trainer_id=trainer.id,
                skill_level=SkillLevelEnum.BEGINNER
            )
            db.add(trainee)
            db.commit()
            db.refresh(trainee)

        # 3. Seed Trainee Progress
        progress = db.query(UserProgress).filter(UserProgress.user_id == trainee.id).first()
        if not progress:
            print("Seeding trainee progress metrics...")
            progress = UserProgress(
                user_id=trainee.id,
                streak_days=15,
                total_sessions_played=12,
                average_accuracy=85,
                badges_count=5,
                last_practice_date=date.today()
            )
            db.add(progress)

        # 4. Seed Trainee Settings
        user_settings = db.query(UserSettings).filter(UserSettings.user_id == trainee.id).first()
        if not user_settings:
            print("Seeding default trainee settings...")
            user_settings = UserSettings(
                user_id=trainee.id,
                theme_mode=ThemeModeEnum.SYSTEM,
                accent_palette_index=0,
                tuning_standard="A4 = 440 Hz (Standard)"
            )
            db.add(user_settings)

        # 5. Seed Exercises
        exercises = [
            Exercise(
                id="b1",
                title="Single Key Notes & Pitch Match",
                description="Practice hitting individual notes with clean pitch accuracy.",
                skill_level=SkillLevelEnum.BEGINNER,
                category=CategoryEnum.MIDI,
                target_bpm=60,
                notes_sequence=["C4", "E4", "G4"],
                ai_tip="Focus on hitting C4 steadily before moving to E4."
            ),
            Exercise(
                id="b2",
                title="Middle C Pentascale",
                description="5-note consecutive pentascale drill for beginners.",
                skill_level=SkillLevelEnum.BEGINNER,
                category=CategoryEnum.MIDI,
                target_bpm=70,
                notes_sequence=["C4", "D4", "E4", "F4", "G4"],
                ai_tip="Keep your wrist relaxed while moving finger to finger."
            ),
            Exercise(
                id="b3",
                title="C Major Triad Arpeggio",
                description="Basic 3-note chord breakdown.",
                skill_level=SkillLevelEnum.BEGINNER,
                category=CategoryEnum.MIDI,
                target_bpm=75,
                notes_sequence=["C4", "E4", "G4", "C5"],
                ai_tip="Listen carefully to the octave jump to C5."
            ),
            Exercise(
                id="m1",
                title="Full C Major Scale",
                description="Ascending & descending 8-note major scale drill.",
                skill_level=SkillLevelEnum.MODERATE,
                category=CategoryEnum.MIDI,
                target_bpm=90,
                notes_sequence=["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"],
                ai_tip="Smooth finger crossover on the 4th note (F4)."
            ),
            Exercise(
                id="m2",
                title="G Major Scale Run",
                description="Ascending G Major scale with sharp F#4 note.",
                skill_level=SkillLevelEnum.MODERATE,
                category=CategoryEnum.MIDI,
                target_bpm=95,
                notes_sequence=["G4", "A4", "B4", "C5", "D5", "E5", "F#5", "G5"],
                ai_tip="Watch for the sharp note on F#5."
            ),
            Exercise(
                id="m3",
                title="A Minor Melodic Pattern",
                description="Natural minor scale pattern drill.",
                skill_level=SkillLevelEnum.MODERATE,
                category=CategoryEnum.MIDI,
                target_bpm=85,
                notes_sequence=["A4", "B4", "C5", "D5", "E5", "F5", "G5", "A5"],
                ai_tip="Emphasize the minor third interval tone."
            ),
            Exercise(
                id="p1",
                title="Chromatic Scale Speed Run",
                description="Full 12-semitone chromatic exercise at high tempo.",
                skill_level=SkillLevelEnum.PRO,
                category=CategoryEnum.MIDI,
                target_bpm=120,
                notes_sequence=["C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4", "C5"],
                ai_tip="Keep note duration perfectly equal at 120 BPM."
            ),
            Exercise(
                id="p2",
                title="Bach Two-Part Invention Fragment",
                description="Polyphonic counterpoint exercise for advanced fingers.",
                skill_level=SkillLevelEnum.PRO,
                category=CategoryEnum.MIDI,
                target_bpm=130,
                notes_sequence=["C5", "B4", "C5", "D5", "E5", "G4", "A4", "B4", "C5"],
                ai_tip="Maintain rhythm independence between finger transitions."
            ),
        ]

        for ex in exercises:
            existing = db.query(Exercise).filter(Exercise.id == ex.id).first()
            if not existing:
                print(f"Seeding exercise {ex.id}: {ex.title}")
                db.add(ex)

        # 6. Seed Trainer Assignment
        assignment = db.query(TrainerAssignment).filter(TrainerAssignment.id == 1).first()
        if not assignment:
            print("Seeding trainer exercise assignment...")
            assignment = TrainerAssignment(
                id=1,
                trainer_id=trainer.id,
                trainee_id=trainee.id,
                exercise_id="b2",
                status=AssignmentStatusEnum.IN_PROGRESS,
                notes="Please practice this 5-note pentascale drill before our next lesson."
            )
            db.add(assignment)

        db.commit()
        print("[OK] Database seeding completed successfully!")
    except Exception as e:
        db.rollback()
        print(f"[ERROR] Error seeding database: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    seed()
