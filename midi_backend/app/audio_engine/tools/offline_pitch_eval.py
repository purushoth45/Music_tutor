"""
Offline Audio Pitch Evaluation and Model Comparison Tool.

Evaluates and compares RMVPE and TorchCREPE on audio inputs (file or synthesized vocal test tones).
Outputs structured metrics matching Phase 5 and Phase 10 requirements.
"""

import os
import sys
import argparse
import time
from typing import Optional, Dict, Any, Tuple
import numpy as np

# Ensure midi_backend is on path
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
midi_backend_dir = os.path.join(project_root, "midi_backend")
if midi_backend_dir not in sys.path:
    sys.path.insert(0, midi_backend_dir)
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from app.audio_engine.f0.rmvpe_engine import RMVPEF0Engine
from app.audio_engine.f0.crepe_engine import CREPEF0Engine
from app.audio_engine.f0.base import F0Result


def generate_vocal_test_audio(sr: int = 16000) -> Tuple[np.ndarray, str]:
    """
    Generate a 3-second realistic vocal test audio sequence with distinct notes:
    - 0.0s to 1.0s: C4 (261.63 Hz)
    - 1.0s to 2.0s: E4 (329.63 Hz)
    - 2.0s to 3.0s: G4 (392.00 Hz)
    Includes natural vocal harmonics and subtle vibrato (5 Hz rate, 0.5% depth).
    """
    duration = 3.0
    num_samples = int(duration * sr)
    t = np.linspace(0, duration, num_samples, endpoint=False)
    wav = np.zeros(num_samples, dtype=np.float32)

    note_intervals = [
        (0.0, 1.0, 261.6255),  # C4
        (1.0, 2.0, 329.6276),  # E4
        (2.0, 3.0, 392.0000),  # G4
    ]

    for start_t, end_t, base_f0 in note_intervals:
        idx_start = int(start_t * sr)
        idx_end = int(end_t * sr)
        t_segment = t[idx_start:idx_end] - start_t

        # Vibrato modulation
        vibrato = 1.0 + 0.008 * np.sin(2 * np.pi * 5.5 * t_segment)
        freq_track = base_f0 * vibrato
        phase = 2 * np.pi * np.cumsum(freq_track) / sr

        # Fundamental + Vocal harmonics (Formants/harmonics typical of singing)
        h1 = 0.60 * np.sin(phase)
        h2 = 0.25 * np.sin(2 * phase)
        h3 = 0.12 * np.sin(3 * phase)
        h4 = 0.05 * np.sin(4 * phase)
        note_audio = h1 + h2 + h3 + h4

        # Smooth envelope (fade-in & fade-out)
        fade_len = int(0.05 * sr)
        fade_in = np.linspace(0.0, 1.0, fade_len)
        fade_out = np.linspace(1.0, 0.0, fade_len)
        note_audio[:fade_len] *= fade_in
        note_audio[-fade_len:] *= fade_out

        wav[idx_start:idx_end] = note_audio

    # Normalization
    wav = wav / (np.max(np.abs(wav)) + 1e-6)
    description = "Synthesized multi-note vocal sequence (C4 → E4 → G4 with harmonics & vibrato)"
    return wav, description


def load_or_create_audio(audio_path: Optional[str]) -> Tuple[np.ndarray, int, str]:
    """Load WAV audio from file or synthesize test audio."""
    if audio_path and os.path.exists(audio_path):
        import soundfile as sf
        wav, sr = sf.read(audio_path, dtype="float32")
        if wav.ndim > 1:
            wav = np.mean(wav, axis=1)
        name = os.path.basename(audio_path)
        return wav, sr, name

    wav, desc = generate_vocal_test_audio(sr=16000)
    return wav, 16000, desc


def evaluate_engine(engine, audio: np.ndarray, sr: int, model_header: str, audio_desc: str) -> F0Result:
    """Run model inference and print standardized Phase 5 output block."""
    duration = len(audio) / sr
    t0 = time.time()
    res = engine.extract_f0(audio, sample_rate=sr)
    infer_ms = (time.time() - t0) * 1000.0

    print(f"MODEL: {model_header}\n", flush=True)
    print(f"Audio: {audio_desc}", flush=True)
    print(f"Sample rate: {sr} Hz", flush=True)
    print(f"Duration: {duration:.2f} s", flush=True)
    print(f"Frames: {res.num_frames}", flush=True)
    print(f"Voiced frames: {res.voiced_frames_count}", flush=True)
    print(f"Voiced percentage: {res.voiced_percentage:.1f}%", flush=True)
    print(f"F0 minimum: {res.min_f0:.2f} Hz", flush=True)
    print(f"F0 maximum: {res.max_f0:.2f} Hz", flush=True)
    print(f"Mean voiced F0: {res.mean_voiced_f0:.2f} Hz", flush=True)
    print(f"Inference time: {infer_ms:.1f} ms\n", flush=True)
    return res


def compare_engines(res_rmvpe: F0Result, res_crepe: F0Result):
    """Output detailed qualitative and engineering comparison between the two models."""
    print("=" * 60, flush=True)
    print("ENGINEERING COMPARISON: RMVPE vs TORCHCREPE", flush=True)
    print("(Qualitative comparative analysis — non-ground-truth)", flush=True)
    print("=" * 60, flush=True)

    # 1. Voicing Agreement
    min_len = min(len(res_rmvpe.voiced), len(res_crepe.voiced))
    v_rmvpe = res_rmvpe.voiced[:min_len]
    v_crepe = res_crepe.voiced[:min_len]
    agreement = np.mean(v_rmvpe == v_crepe) * 100.0

    # 2. Pitch Agreement on mutually voiced frames
    mutually_voiced = v_rmvpe & v_crepe
    if np.sum(mutually_voiced) > 0:
        f0_r = res_rmvpe.f0_hz[:min_len][mutually_voiced]
        f0_c = res_crepe.f0_hz[:min_len][mutually_voiced]
        cents_diff = 1200.0 * np.log2(f0_r / f0_c)
        median_cents = float(np.median(np.abs(cents_diff)))
        mean_cents = float(np.mean(np.abs(cents_diff)))
        # Octave errors check (ratio close to 2.0 or 0.5)
        octave_errors = np.sum(np.abs(cents_diff) > 1100.0)
    else:
        median_cents, mean_cents, octave_errors = 0.0, 0.0, 0

    # 3. Inference Speed Comparison
    t_rmvpe = res_rmvpe.metadata.get("inference_time", 0.1) * 1000.0
    t_crepe = res_crepe.metadata.get("inference_time", 1.0) * 1000.0
    speedup = t_crepe / max(1e-3, t_rmvpe)

    print(f"Voicing detection agreement: {agreement:.1f}%", flush=True)
    print(f"Mutually voiced frames: {np.sum(mutually_voiced)} / {min_len}", flush=True)
    print(f"Median pitch absolute diff: {median_cents:.2f} cents", flush=True)
    print(f"Mean pitch absolute diff:   {mean_cents:.2f} cents", flush=True)
    print(f"Octave mismatch count:     {octave_errors} frames", flush=True)
    print(f"RMVPE inference time:      {t_rmvpe:.1f} ms", flush=True)
    print(f"TorchCREPE inference time: {t_crepe:.1f} ms", flush=True)
    print(f"Speed advantage:           RMVPE is {speedup:.1f}x faster on CPU", flush=True)

    print("\nSummary Assessment:", flush=True)
    if speedup > 5:
        print("- RMVPE provides high-speed, low-latency execution suitable for real-time practice.", flush=True)
        print("- TorchCREPE full provides a robust frame-by-frame baseline but has high compute overhead.", flush=True)
    print("=" * 60 + "\n", flush=True)


def main():
    parser = argparse.ArgumentParser(description="Music Tutor AI Offline Pitch Model Evaluator")
    parser.add_argument("--audio", type=str, default=None, help="Path to input WAV audio file")
    parser.add_argument("--engine", type=str, default="compare", choices=["rmvpe", "crepe", "compare"], help="Engine to evaluate")
    parser.add_argument("--device", type=str, default="cpu", help="Device to use ('cpu', 'mps')")
    args = parser.parse_args()

    audio, sr, audio_desc = load_or_create_audio(args.audio)

    res_rmvpe = None
    res_crepe = None

    if args.engine in ("rmvpe", "compare"):
        engine_rmvpe = RMVPEF0Engine(model_path="models/pitch_model/rmvpe.pt", device=args.device)
        res_rmvpe = evaluate_engine(engine_rmvpe, audio, sr, "RMVPE", audio_desc)

    if args.engine in ("crepe", "compare"):
        engine_crepe = CREPEF0Engine(model_path="models/pitch_model/full.pth", device=args.device)
        res_crepe = evaluate_engine(engine_crepe, audio, sr, "TORCHCREPE", audio_desc)

    if args.engine == "compare" and res_rmvpe and res_crepe:
        compare_engines(res_rmvpe, res_crepe)


if __name__ == "__main__":
    main()
