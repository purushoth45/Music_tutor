"""
End-to-End Singing Practice Evaluation Tool.

Executes the complete Music Tutor evaluation pipeline:
Student singing audio
  ↓
Pretrained RMVPE/CREPE
  ↓
Detected F0 contour
  ↓
Musical note segmentation
  ↓
TARGET NOTES
  ↓
Temporal & sequence alignment
  ↓
PerformanceScorer
  (Pitch accuracy, Timing accuracy, Note accuracy, Stability, Overall score)
  ↓
FeedbackGenerator
  (Actionable coaching tips)
"""

import os
import sys
import argparse
import time
from typing import List, Tuple, Optional, Dict, Any
import numpy as np

# Ensure midi_backend and project root are on sys.path
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
midi_backend_dir = os.path.join(project_root, "midi_backend")
if midi_backend_dir not in sys.path:
    sys.path.insert(0, midi_backend_dir)
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from app.audio_engine.f0.base import F0Result, resolve_model_path
from app.audio_engine.f0.rmvpe_engine import RMVPEF0Engine
from app.audio_engine.f0.crepe_engine import CREPEF0Engine
from app.audio_engine.analysis.pitch_analysis import PitchAnalyzer
from app.audio_engine.scoring.performance_scorer import PerformanceScorer
from app.audio_engine.feedback.feedback_generator import FeedbackGenerator


def generate_singing_audio_with_mistake(
    target_notes: List[str],
    mistake_index: int = 2,
    mistake_note: str = "D#4",
    sr: int = 16000,
    note_duration: float = 0.70
) -> Tuple[np.ndarray, List[str], str]:
    """
    Generate realistic singing audio sequence matching target_notes,
    with one intentional singing pitch error (e.g. singing D#4 instead of E4)
    to test alignment, intonation evaluation, and feedback generation.
    """
    # Build sung notes sequence
    sung_notes = list(target_notes)
    if 0 <= mistake_index < len(sung_notes):
        sung_notes[mistake_index] = mistake_note

    total_duration = note_duration * len(sung_notes)
    total_samples = int(total_duration * sr)
    wav = np.zeros(total_samples, dtype=np.float32)

    for i, note in enumerate(sung_notes):
        freq = PitchAnalyzer.note_name_to_hz(note) or 440.0
        idx_start = int(i * note_duration * sr)
        idx_end = int((i + 1) * note_duration * sr)
        n_samples = idx_end - idx_start
        t = np.linspace(0, note_duration, n_samples, endpoint=False)

        # Natural vocal vibrato (5.5 Hz rate, 0.6% frequency modulation)
        vibrato = 1.0 + 0.006 * np.sin(2.0 * np.pi * 5.5 * t)
        inst_freq = freq * vibrato
        phase = 2.0 * np.pi * np.cumsum(inst_freq) / sr

        # Vocal formants / harmonics
        h1 = 0.60 * np.sin(phase)
        h2 = 0.25 * np.sin(2.0 * phase)
        h3 = 0.10 * np.sin(3.0 * phase)
        h4 = 0.05 * np.sin(4.0 * phase)
        note_audio = h1 + h2 + h3 + h4

        # Natural envelope (fade in / fade out)
        fade_samples = int(0.04 * sr)
        if fade_samples > 0 and n_samples > 2 * fade_samples:
            fade_in = np.linspace(0.0, 1.0, fade_samples)
            fade_out = np.linspace(1.0, 0.0, fade_samples)
            note_audio[:fade_samples] *= fade_in
            note_audio[-fade_samples:] *= fade_out

        wav[idx_start:idx_end] = note_audio

    # Normalization
    max_val = np.max(np.abs(wav))
    if max_val > 1e-6:
        wav = wav / max_val * 0.85

    description = (
        f"Synthesized singing tone ({' → '.join(sung_notes)}) with natural harmonics & vibrato "
        f"[Note {mistake_index + 1} intentionally sung as {mistake_note}]"
    )
    return wav, sung_notes, description


def load_audio_file(audio_path: str, target_sr: int = 16000) -> Tuple[np.ndarray, int, str]:
    """Load WAV/FLAC audio from file and resample to target_sr if needed."""
    import soundfile as sf
    wav, sr = sf.read(audio_path, dtype="float32")
    if wav.ndim > 1:
        wav = np.mean(wav, axis=1)

    if sr != target_sr:
        import scipy.signal
        num_samples = int(round(len(wav) * target_sr / sr))
        wav = scipy.signal.resample(wav, num_samples).astype(np.float32)
        sr = target_sr

    desc = f"Audio file: {os.path.basename(audio_path)}"
    return wav, sr, desc


def evaluate_singing_practice(
    target_notes: List[str],
    audio: np.ndarray,
    sr: int = 16000,
    engine_name: str = "rmvpe",
    device: str = "cpu",
    audio_source_desc: str = "Audio"
) -> Dict[str, Any]:
    """
    Run the full end-to-end singing practice evaluation pipeline.
    """
    # 1. Initialize F0 Engine
    if engine_name.lower() == "crepe":
        model_path = resolve_model_path("models/pitch_model/full.pth")
        engine = CREPEF0Engine(model_path=model_path, device=device)
    else:
        model_path = resolve_model_path("models/pitch_model/rmvpe.pt")
        engine = RMVPEF0Engine(model_path=model_path, device=device)

    if not engine.is_loaded:
        raise RuntimeError(f"F0 engine '{engine.name}' failed to load checkpoint from {engine.model_path}")

    # 2. Pretrained F0 Extraction
    t0 = time.time()
    f0_result: F0Result = engine.extract_f0(audio, sample_rate=sr)
    f0_time_ms = (time.time() - t0) * 1000.0

    # 3. Note Segmentation & Temporal Alignment
    analyzer = PitchAnalyzer()
    analysis_result = analyzer.analyze_sequence(f0_result, target_notes)

    # 4. Multi-Dimensional Performance Scoring
    scorer = PerformanceScorer()
    score_result = scorer.compute_scores(analysis_result, target_notes)

    # 5. Personalized Coaching Feedback Generation
    feedback_gen = FeedbackGenerator()
    feedback_summary = feedback_gen.generate_feedback(
        score_result,
        analysis_result.get("segmented_notes", [])
    )
    detailed_tips = feedback_gen.generate_detailed_feedback(
        score_result,
        analysis_result
    )

    detected_sequence = analysis_result.get("segmented_notes", [])

    return {
        "engine_name": engine.name,
        "audio_desc": audio_source_desc,
        "duration_sec": len(audio) / sr,
        "sample_rate": sr,
        "f0_inference_ms": f0_time_ms,
        "target_notes": target_notes,
        "detected_notes": detected_sequence,
        "aligned_pairs": analysis_result.get("aligned_pairs", []),
        "pitch_accuracy": score_result.get("pitch_accuracy", 0),
        "timing_accuracy": score_result.get("timing_score", 0),
        "note_accuracy": score_result.get("note_accuracy", 0),
        "stability_score": score_result.get("stability_score", 0.0),
        "overall_score": score_result.get("overall_score", 0),
        "feedback_summary": feedback_summary,
        "feedback_tips": detailed_tips,
        "f0_result": f0_result,
    }


def print_evaluation_report(report: Dict[str, Any]):
    """
    Print formatted evaluation report matching exact required specification.
    """
    target_str = " → ".join(report["target_notes"])
    detected_str = " → ".join(report["detected_notes"]) if report["detected_notes"] else "(No voiced notes detected)"

    print("=" * 60, flush=True)
    print("MUSIC TUTOR AI: COMPLETE SINGING PRACTICE EVALUATION", flush=True)
    print("=" * 60, flush=True)
    print(f"Audio Source: {report['audio_desc']}", flush=True)
    print(f"F0 Engine:    {report['engine_name']} (Pretrained, strict checkpoint)", flush=True)
    print(f"Duration:     {report['duration_sec']:.2f} s | Sample Rate: {report['sample_rate']} Hz", flush=True)
    print(f"Inference:    {report['f0_inference_ms']:.1f} ms", flush=True)
    print("-" * 60, flush=True)
    print(f"\nTarget:\n{target_str}\n", flush=True)
    print(f"Detected:\n{detected_str}\n", flush=True)
    print("Result:", flush=True)
    print(f"Pitch Accuracy:  {report['pitch_accuracy']}%", flush=True)
    print(f"Timing Accuracy: {report['timing_accuracy']}%", flush=True)
    print(f"Note Accuracy:   {report['note_accuracy']}%", flush=True)
    print(f"Stability:       {report['stability_score']:.1f} / 10.0 ({int(report['stability_score'] * 10)}%)", flush=True)
    print(f"Overall Score:   {report['overall_score']}%\n", flush=True)
    print("Feedback:", flush=True)
    for tip in report["feedback_tips"]:
        print(f"- {tip}", flush=True)
    print("=" * 60, flush=True)


def parse_target_notes(target_arg: Optional[str]) -> List[str]:
    """Parse space, comma, or arrow separated target notes string."""
    if not target_arg:
        return ["C4", "D4", "E4", "G4"]
    cleaned = target_arg.replace("→", " ").replace("->", " ").replace(",", " ")
    tokens = [t.strip().upper() for t in cleaned.split() if t.strip()]
    return tokens or ["C4", "D4", "E4", "G4"]


def main():
    parser = argparse.ArgumentParser(
        description="Music Tutor AI Complete Singing Practice Evaluation Tool"
    )
    parser.add_argument(
        "--target",
        type=str,
        default="C4 D4 E4 G4",
        help="Target melody sequence (e.g. 'C4 D4 E4 G4' or 'C4 → D4 → E4 → G4')"
    )
    parser.add_argument(
        "--audio",
        type=str,
        default=None,
        help="Path to student singing audio file (.wav, .flac). If omitted, generates synthetic test singing."
    )
    parser.add_argument(
        "--engine",
        type=str,
        default="rmvpe",
        choices=["rmvpe", "crepe"],
        help="Pretrained F0 engine to use"
    )
    parser.add_argument(
        "--device",
        type=str,
        default="cpu",
        help="Compute device ('cpu', 'mps')"
    )
    args = parser.parse_args()

    target_notes = parse_target_notes(args.target)

    if args.audio and os.path.exists(args.audio):
        audio, sr, audio_desc = load_audio_file(args.audio)
    else:
        if args.audio:
            print(f"[Warning] Audio file '{args.audio}' not found. Falling back to synthetic singing test audio.", flush=True)
        # Synthetic test audio with intentional note mistake at index 2 (singing D#4 instead of E4)
        audio, sung_notes, audio_desc = generate_singing_audio_with_mistake(
            target_notes=target_notes,
            mistake_index=2,
            mistake_note="D#4",
            sr=16000,
            note_duration=0.70
        )

    report = evaluate_singing_practice(
        target_notes=target_notes,
        audio=audio,
        sr=16000,
        engine_name=args.engine,
        device=args.device,
        audio_source_desc=audio_desc
    )

    print_evaluation_report(report)


if __name__ == "__main__":
    main()
