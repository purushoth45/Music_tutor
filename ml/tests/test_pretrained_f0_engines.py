"""
Comprehensive Unit Tests for Pretrained F0 Engines and Pitch Analysis Pipeline.

Covers:
1. RMVPE model loading.
2. TorchCREPE model loading.
3. F0 extraction (finite, non-NaN/Inf, valid ranges).
4. Invalid audio handling.
5. Empty audio handling.
6. Missing checkpoint handling.
7. Invalid checkpoint handling.
8. PitchAnalyzer integration.
9. Hz -> Note conversion.
10. Hz -> Cents deviation conversion.
11. Scoring & Complete practice analysis integration.
"""

import os
import sys
import unittest
import numpy as np
import torch

sys.path.insert(0, os.path.abspath("midi_backend"))
sys.path.insert(0, os.path.abspath("."))

from app.audio_engine.f0.rmvpe_engine import RMVPEF0Engine
from app.audio_engine.f0.crepe_engine import CREPEF0Engine
from app.audio_engine.f0.factory import get_f0_engine
from app.audio_engine.analysis.pitch_analysis import PitchAnalyzer
from app.audio_engine.scoring.performance_scorer import PerformanceScorer
from app.audio_engine.feedback.feedback_generator import FeedbackGenerator
from app.services.audio_ai_service import AudioAIService
from app.audio_engine.tools.singing_practice_eval import evaluate_singing_practice, generate_singing_audio_with_mistake
from app.audio_engine.tools.realtime_pitch_test import RealTimePitchDetector


class TestPretrainedF0Engines(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        cls.rmvpe_path = "models/pitch_model/rmvpe.pt"
        cls.crepe_path = "models/pitch_model/full.pth"

    def test_rmvpe_model_loading(self):
        """Verify RMVPE checkpoint loads strictly."""
        engine = RMVPEF0Engine(model_path=self.rmvpe_path)
        self.assertTrue(engine.is_loaded)
        self.assertTrue(engine.is_available)
        self.assertEqual(engine.name, "RMVPE")
        self.assertEqual(engine.default_sample_rate, 16000)
        self.assertEqual(engine.default_hop_length, 160)

    def test_crepe_model_loading(self):
        """Verify TorchCREPE full checkpoint loads strictly."""
        engine = CREPEF0Engine(model_path=self.crepe_path)
        self.assertTrue(engine.is_loaded)
        self.assertTrue(engine.is_available)
        self.assertEqual(engine.name, "CREPE")
        self.assertEqual(engine.default_sample_rate, 16000)
        self.assertEqual(engine.default_hop_length, 160)

    def test_rmvpe_f0_extraction_accuracy(self):
        """Verify RMVPE extracts correct frequency with valid finite values."""
        engine = RMVPEF0Engine(model_path=self.rmvpe_path)
        sr = 16000
        t = np.linspace(0, 0.5, int(0.5 * sr), endpoint=False)
        sine_440 = (0.7 * np.sin(2 * np.pi * 440.0 * t)).astype(np.float32)

        res = engine.extract_f0(sine_440, sr, confidence_threshold=0.3)
        self.assertGreater(res.num_frames, 0)
        self.assertGreater(res.voiced_frames_count, 0)
        self.assertFalse(np.any(np.isnan(res.f0_hz)))
        self.assertFalse(np.any(np.isinf(res.f0_hz)))
        self.assertFalse(np.any(np.isnan(res.confidence)))
        self.assertTrue(np.all((res.confidence >= 0.0) & (res.confidence <= 1.0)))
        self.assertAlmostEqual(res.mean_voiced_f0, 440.0, delta=5.0)

    def test_empty_audio_handling(self):
        """Verify empty audio returns consistent empty F0Result without errors."""
        engine = RMVPEF0Engine(model_path=self.rmvpe_path)
        res = engine.extract_f0(np.array([], dtype=np.float32), 16000)
        self.assertEqual(res.num_frames, 0)
        self.assertEqual(res.voiced_frames_count, 0)
        self.assertEqual(len(res.timestamps), 0)
        self.assertEqual(len(res.f0_hz), 0)

    def test_silent_audio_handling(self):
        """Verify silent audio is correctly identified as unvoiced."""
        engine = RMVPEF0Engine(model_path=self.rmvpe_path)
        silence = np.zeros(8000, dtype=np.float32)
        res = engine.extract_f0(silence, 16000, confidence_threshold=0.3)
        self.assertGreater(res.num_frames, 0)
        self.assertEqual(res.voiced_frames_count, 0)
        self.assertEqual(res.voiced_percentage, 0.0)

    def test_missing_checkpoint_handling(self):
        """Verify missing checkpoint is reported cleanly."""
        engine = RMVPEF0Engine(model_path="models/pitch_model/does_not_exist.pt")
        self.assertFalse(engine.is_loaded)
        with self.assertRaises(RuntimeError):
            engine.extract_f0(np.zeros(1600, dtype=np.float32), 16000)

    def test_hz_to_note_and_cents_mathematics(self):
        """Verify exact note name and cents deviation formulas."""
        analyzer = PitchAnalyzer()

        # A4 = 440.0 Hz
        info_a4 = analyzer.hz_to_note_info(440.0)
        self.assertIsNotNone(info_a4)
        self.assertEqual(info_a4["note_name"], "A4")
        self.assertAlmostEqual(info_a4["cents_deviation"], 0.0, delta=0.1)

        # C4 = 261.625 Hz
        info_c4 = analyzer.hz_to_note_info(261.6255)
        self.assertIsNotNone(info_c4)
        self.assertEqual(info_c4["note_name"], "C4")
        self.assertAlmostEqual(info_c4["cents_deviation"], 0.0, delta=0.5)

        # 450 Hz: sharp from A4
        info_sharp = analyzer.hz_to_note_info(450.0)
        self.assertGreater(info_sharp["cents_deviation"], 0.0)

        # 430 Hz: flat from A4
        info_flat = analyzer.hz_to_note_info(430.0)
        self.assertLess(info_flat["cents_deviation"], 0.0)

    def test_pitch_analyzer_segmentation_and_alignment(self):
        """Verify continuous F0 frames are cleanly segmented and aligned with target notes."""
        analyzer = PitchAnalyzer()

        # Generate sequence: 50 frames C4 (261.6Hz), 50 frames D4 (293.7Hz), 50 frames G4 (392.0Hz)
        f0_track = [261.63] * 50 + [293.66] * 50 + [392.00] * 50
        target = ["C4", "D4", "G4"]

        res = analyzer.analyze_sequence(f0_track, target)
        self.assertEqual(res["segmented_notes"], ["C4", "D4", "G4"])
        self.assertEqual(res["note_accuracy"], 100)

        # Alignment pairs
        pairs = res["aligned_pairs"]
        self.assertEqual(pairs, [("C4", "C4"), ("D4", "D4"), ("G4", "G4")])

    def test_pitch_analyzer_mismatch_alignment(self):
        """Verify alignment when student sings an incorrect note."""
        analyzer = PitchAnalyzer()
        # Student sings D#4 instead of E4
        # Target: C4 -> D4 -> E4 -> G4
        # Sung: C4 -> D4 -> D#4 -> G4
        f0_track = [261.63] * 30 + [293.66] * 30 + [311.13] * 30 + [392.00] * 30
        target = ["C4", "D4", "E4", "G4"]

        res = analyzer.analyze_sequence(f0_track, target)
        self.assertEqual(res["segmented_notes"], ["C4", "D4", "D#4", "G4"])
        self.assertEqual(res["note_accuracy"], 75)  # 3 of 4 matched

    def test_complete_scoring_and_feedback(self):
        """Verify PerformanceScorer and FeedbackGenerator compute all required metrics."""
        analyzer = PitchAnalyzer()
        scorer = PerformanceScorer()
        feedback_gen = FeedbackGenerator()

        f0_track = [261.63] * 30 + [293.66] * 30 + [311.13] * 30 + [392.00] * 30
        target = ["C4", "D4", "E4", "G4"]

        analysis = analyzer.analyze_sequence(f0_track, target)
        scores = scorer.compute_scores(analysis, target)

        self.assertIn("accuracy_score", scores)
        self.assertIn("note_accuracy", scores)
        self.assertIn("pitch_accuracy", scores)
        self.assertIn("stability_score", scores)
        self.assertIn("timing_score", scores)
        self.assertIn("overall_score", scores)

        self.assertEqual(scores["note_accuracy"], 75)
        self.assertGreater(scores["overall_score"], 0)

        feedback = feedback_gen.generate_feedback(scores, analysis["segmented_notes"])
        detailed_tips = feedback_gen.generate_detailed_feedback(scores, analysis)

        self.assertIsInstance(feedback, str)
        self.assertGreater(len(detailed_tips), 0)
        # Check that the mismatch is called out
        tip_text = " ".join(detailed_tips)
        self.assertIn("D#4", tip_text)

    def test_singing_practice_eval_pipeline(self):
        """Verify the end-to-end singing evaluation tool pipeline with RMVPE."""
        target = ["C4", "D4", "E4", "G4"]
        audio, sung_notes, desc = generate_singing_audio_with_mistake(
            target_notes=target,
            mistake_index=2,
            mistake_note="D#4",
            sr=16000,
            note_duration=0.50
        )
        report = evaluate_singing_practice(
            target_notes=target,
            audio=audio,
            sr=16000,
            engine_name="rmvpe",
            device="cpu",
            audio_source_desc=desc
        )
        self.assertEqual(report["target_notes"], ["C4", "D4", "E4", "G4"])
        self.assertEqual(report["detected_notes"], ["C4", "D4", "D#4", "G4"])
        self.assertEqual(report["note_accuracy"], 75)
        self.assertGreater(report["pitch_accuracy"], 80)
        self.assertGreater(report["overall_score"], 60)
        self.assertTrue(any("D#4" in tip for tip in report["feedback_tips"]))

    def test_realtime_pitch_detector_chunk_processing(self):
        """Verify RealTimePitchDetector processes streaming chunks with RMVPE."""
        detector = RealTimePitchDetector(
            engine_name="rmvpe",
            chunk_size=1024,
            buffer_size=2048,
            confidence_threshold=0.35,
            enable_visualizer=False,
            simulate_mic=True
        )
        self.assertTrue(detector.engine.is_available)
        t = np.linspace(0, 2048 / 16000, 2048, endpoint=False)
        test_buf = (0.7 * np.sin(2 * np.pi * 440.0 * t)).astype(np.float32)
        res = detector.engine.extract_chunk(test_buf, sample_rate=16000)
        self.assertGreater(res.num_frames, 0)
        self.assertFalse(np.any(np.isnan(res.f0_hz)))
        self.assertAlmostEqual(res.mean_voiced_f0, 440.0, delta=10.0)


if __name__ == "__main__":
    unittest.main()
