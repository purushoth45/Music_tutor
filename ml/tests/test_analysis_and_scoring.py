import sys
import os
sys.path.insert(0, os.path.abspath("midi_backend"))
sys.path.insert(0, os.path.abspath("."))

import unittest
from app.audio_engine.analysis.pitch_analysis import PitchAnalyzer
from app.audio_engine.scoring.performance_scorer import PerformanceScorer
from app.audio_engine.feedback.feedback_generator import FeedbackGenerator
from app.services.audio_ai_service import AudioAIService


from app.audio_engine.inference.pitch_inference import PitchInferenceEngine


class TestAnalysisAndScoring(unittest.TestCase):

    def setUp(self):
        self.analyzer = PitchAnalyzer()
        self.scorer = PerformanceScorer()
        self.feedback_gen = FeedbackGenerator()
        self.service = AudioAIService()

    def test_hz_to_note_conversion(self):
        self.assertEqual(self.analyzer.hz_to_note_name(440.0), "A4")
        self.assertEqual(self.analyzer.hz_to_note_name(261.63), "C4")
        self.assertIsNone(self.analyzer.hz_to_note_name(0.0))

    def test_cents_deviation_calculation(self):
        # Exact pitch (0 cents diff)
        self.assertAlmostEqual(self.analyzer.calculate_cents_deviation(440.0, 440.0), 0.0)
        # 1 semitone sharp = 100 cents
        self.assertAlmostEqual(self.analyzer.calculate_cents_deviation(466.16, 440.0), 100.0, delta=1.0)
        # 1 semitone flat = -100 cents
        self.assertAlmostEqual(self.analyzer.calculate_cents_deviation(415.30, 440.0), -100.0, delta=1.0)

    def test_performance_scoring(self):
        analysis_data = {"detected_notes": ["C4", "E4", "G4"]}
        target_notes = ["C4", "E4", "G4"]
        scores = self.scorer.compute_scores(analysis_data, target_notes)

        self.assertEqual(scores["accuracy_score"], 100)
        self.assertGreater(scores["overall_score"], 0)

    def test_feedback_generator(self):
        score_data = {"accuracy_score": 95, "stability_score": 9.0}
        feedback = self.feedback_gen.generate_feedback(score_data, ["C4", "E4"])
        self.assertIn("Outstanding", feedback)

    def test_unloaded_model_controlled_response(self):
        # Test that without model weights, the service returns controlled model_not_available response
        unloaded_service = AudioAIService(
            inference_engine=PitchInferenceEngine(model_dir="non_existent_path")
        )
        response = unloaded_service.process_audio_practice(
            db=None,  # Not queried when model is not available
            user_id=1,
            audio_bytes=b"dummy_audio_bytes"
        )
        self.assertEqual(response["status"], "model_not_available")
        self.assertFalse(response["is_trained_model"])
        self.assertIn("No trained ML model", response["message"])

    def test_loaded_pretrained_model_practice(self):
        # Test real evaluation pipeline with loaded pretrained model
        import io
        import soundfile as sf
        import numpy as np
        sr = 16000
        t = np.linspace(0, 1.0, sr, endpoint=False)
        sine = (0.7 * np.sin(2 * np.pi * 440.0 * t)).astype(np.float32)
        buf = io.BytesIO()
        sf.write(buf, sine, sr, format='WAV')
        audio_bytes = buf.getvalue()

        response = self.service.process_audio_practice(
            db=None,
            user_id=1,
            audio_bytes=audio_bytes,
            target_notes=["A4"]
        )
        self.assertTrue(response["is_pretrained_model"])
        self.assertEqual(response["model_source"], "pretrained")
        self.assertIn("A4", response["detected_notes"])
        self.assertGreaterEqual(response["accuracy_score"], 80)
        self.assertIn("feedback", response)


if __name__ == "__main__":
    unittest.main()
