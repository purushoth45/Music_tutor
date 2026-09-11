import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from typing import Dict, Any, List, Optional

try:
    from sqlalchemy.orm import Session
    from app.models import PracticeSession, SessionTypeEnum, User, Exercise
except ImportError:
    Session = Any  # type: ignore
    PracticeSession = None  # type: ignore
    SessionTypeEnum = None  # type: ignore
    User = None  # type: ignore
    Exercise = None  # type: ignore

from app.audio_engine.inference.pitch_inference import PitchInferenceEngine
from app.audio_engine.analysis.pitch_analysis import PitchAnalyzer
from app.audio_engine.scoring.performance_scorer import PerformanceScorer
from app.audio_engine.feedback.feedback_generator import FeedbackGenerator


EXERCISE_PRESETS: Dict[str, List[str]] = {
    "beg_1": ["C4", "E4", "G4"],
    "b1": ["C4", "E4", "G4"],
    "beg_2": ["C4", "D4", "E4", "F4"],
    "b2": ["C4", "D4", "E4", "F4", "G4"],
    "beg_3": ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"],
    "b3": ["C4", "E4", "G4", "C5"],
    "beginner": ["C4", "D4", "E4", "G4"],
    "mod_1": ["C4", "E4", "G4", "F4", "A4", "C5", "G4", "B4", "D5"],
    "m1": ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"],
    "moderate": ["C4", "D4", "E4", "F4", "G4", "A4", "B4", "C5"],
    "pro_1": ["D4", "F4", "A4", "C5", "G4", "B4", "D5", "F5"],
    "p1": ["C4", "C#4", "D4", "D#4", "E4", "F4", "F#4", "G4", "G#4", "A4", "A#4", "B4", "C5"],
    "pro": ["D4", "F4", "A4", "C5", "G4", "B4", "D5", "F5"],
}


class AudioAIService:
    """
    Orchestrates the Audio AI evaluation pipeline and database session recording.
    """

    def __init__(self, inference_engine: Optional[PitchInferenceEngine] = None):
        self.inference_engine = inference_engine or PitchInferenceEngine()
        self.analyzer = PitchAnalyzer()
        self.scorer = PerformanceScorer()
        self.feedback_gen = FeedbackGenerator()

    def process_audio_practice(
        self,
        db: Optional[Session],
        user_id: int,
        audio_bytes: bytes,
        exercise_id: Optional[str] = None,
        target_notes: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        Process audio recording, run evaluation pipeline, and record session in database.
        """
        # Resolve target notes from exercise or defaults
        if not target_notes and exercise_id:
            if db and Exercise is not None:
                try:
                    ex = db.query(Exercise).filter(Exercise.id == exercise_id).first()
                    if ex and ex.notes_sequence:
                        if isinstance(ex.notes_sequence, list):
                            target_notes = ex.notes_sequence
                        elif isinstance(ex.notes_sequence, str):
                            import json
                            target_notes = json.loads(ex.notes_sequence)
                except Exception:
                    pass
            if not target_notes:
                target_notes = EXERCISE_PRESETS.get(str(exercise_id).lower())

        target_notes = target_notes or ["C4", "D4", "E4", "G4"]

        # 1. Check if model is available
        if not self.inference_engine.is_loaded:
            return {
                "status": "model_not_available",
                "message": "No trained ML model checkpoint available. Model training is pending dataset ingestion.",
                "is_trained_model": False,
                "is_pretrained_model": False,
                "model_source": "none",
                "session_id": None,
                "accuracy_score": 0,
                "stability_score": 0.0,
                "timing_score": 0,
                "overall_score": 0,
                "detected_notes": [],
                "feedback": "AI model training pending. Please train the MusicTutorPitchNet model on a dataset before running inference.",
            }

        # 2. Run Pitch Model Inference
        inference_res = self.inference_engine.run_inference(audio_bytes)
        f0_seq = inference_res.get("f0_sequence", [])
        f0_result = inference_res.get("f0_result")

        # 3. Run Analysis Engine (with note segmentation & temporal alignment)
        analysis_res = self.analyzer.analyze_sequence(
            f0_result if f0_result is not None else f0_seq,
            target_notes
        )

        # 4. Compute Comprehensive Scores
        score_res = self.scorer.compute_scores(analysis_res, target_notes)

        # 5. Generate Coaching Feedback
        feedback_text = self.feedback_gen.generate_feedback(
            score_res, analysis_res.get("segmented_notes", analysis_res.get("detected_notes", []))
        )
        detailed_tips = self.feedback_gen.generate_detailed_feedback(score_res, analysis_res)

        # 6. Persist Practice Session in MySQL (if db session provided)
        session_id = None
        if db is not None and PracticeSession is not None and SessionTypeEnum is not None:
            try:
                db_exercise_id = None
                if exercise_id:
                    if Exercise and db.query(Exercise).filter(Exercise.id == exercise_id).first():
                        db_exercise_id = exercise_id
                    else:
                        mapped_id = exercise_id.replace("beg_", "b").replace("mod_", "m").replace("pro_", "p")
                        if Exercise and db.query(Exercise).filter(Exercise.id == mapped_id).first():
                            db_exercise_id = mapped_id

                session_record = PracticeSession(
                    user_id=user_id,
                    exercise_id=db_exercise_id,
                    session_type=SessionTypeEnum.AUDIO,
                    accuracy_score=score_res["accuracy_score"],
                    stability_score=int(round(score_res["stability_score"])),
                    duration_seconds=30,
                    notes_evaluated={
                        "detected": analysis_res.get("segmented_notes", []),
                        "evaluations": score_res.get("note_evaluations", [])
                    },
                    ai_feedback=feedback_text,
                )
                db.add(session_record)
                db.commit()
                db.refresh(session_record)
                session_id = session_record.id
            except Exception as e:
                import logging
                logging.getLogger("AudioAIService").error(f"Error saving practice session: {e}")
                if hasattr(db, 'rollback'):
                    db.rollback()


        # Discrete note sequence for UI display (C4 -> D4 -> E4 -> G4)
        discrete_detected = analysis_res.get("segmented_notes", [])
        if not discrete_detected:
            raw_det = analysis_res.get("detected_notes", [])
            collapsed = []
            for n in raw_det:
                if not collapsed or collapsed[-1] != n:
                    collapsed.append(n)
            discrete_detected = collapsed

        # Structured note detections for Flutter NoteCapsules
        notes_list = []
        note_evals = score_res.get("note_evaluations", [])
        if note_evals:
            for ev in note_evals:
                note_str = ev.get("detected") or ev.get("target")
                if note_str:
                    is_correct = ev.get("matched", False)
                    notes_list.append({
                        "note": str(note_str),
                        "accuracy": 100 if is_correct else 60,
                        "status": ev.get("status", "unknown")
                    })
        elif discrete_detected:
            for n in discrete_detected:
                notes_list.append({
                    "note": str(n),
                    "accuracy": score_res["accuracy_score"],
                    "status": "detected"
                })

        return {
            "session_id": session_id,
            "user_id": user_id,
            "exercise_id": exercise_id,
            "target_notes": target_notes,
            "detected_notes": discrete_detected,
            "segmented_notes": analysis_res.get("segmented_notes", []),
            "frame_level_notes": analysis_res.get("detected_notes", []),
            "notes": notes_list,
            "aligned_pairs": analysis_res.get("aligned_pairs", []),
            "note_evaluations": score_res.get("note_evaluations", []),
            "accuracy_score": score_res["accuracy_score"],
            "note_accuracy": score_res.get("note_accuracy", score_res["accuracy_score"]),
            "pitch_accuracy": score_res.get("pitch_accuracy", score_res["accuracy_score"]),
            "stability_score": score_res["stability_score"],
            "timing_score": score_res["timing_score"],
            "timing_accuracy": score_res["timing_score"],
            "overall_score": score_res["overall_score"],
            "feedback": feedback_text,
            "detailed_feedback": detailed_tips,
            "coaching_tips": detailed_tips,
            "model_source": inference_res.get("model_source", "pretrained"),
            "model_name": inference_res.get("model_name", "RMVPE"),
            "is_pretrained_model": inference_res.get("is_pretrained_model", True),
            "is_trained_model": inference_res.get("is_trained_model", True),
        }
