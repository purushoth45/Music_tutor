"""
Unit tests for FastAPI Audio AI and Practice evaluation endpoints.
"""

import sys
import os
import io
import wave
import unittest
import numpy as np

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'midi_backend'))

from fastapi.testclient import TestClient
from app.main import app


class TestAudioAPIEndpoints(unittest.TestCase):
    """Test REST API audio evaluation endpoints."""

    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(app)

    def _generate_wav(self, frequencies, duration_per_note=0.4, sample_rate=16000):
        samples = []
        for freq in frequencies:
            t = np.linspace(0, duration_per_note, int(sample_rate * duration_per_note), endpoint=False)
            envelope = np.ones_like(t)
            fade = int(0.02 * sample_rate)
            envelope[:fade] = np.linspace(0, 1, fade)
            envelope[-fade:] = np.linspace(1, 0, fade)
            wave_data = 0.6 * np.sin(2 * np.pi * freq * t) * envelope
            samples.append(wave_data)
            samples.append(np.zeros(int(sample_rate * 0.05)))
        full = np.concatenate(samples).astype(np.float32)
        int_audio = (full * 32767).astype(np.int16)
        buf = io.BytesIO()
        with wave.open(buf, 'wb') as wf:
            wf.setnchannels(1)
            wf.setsampwidth(2)
            wf.setframerate(sample_rate)
            wf.writeframes(int_audio.tobytes())
        return buf.getvalue()

    def test_audio_ai_analyze_endpoint_correct_notes(self):
        """Test POST /api/audio-ai/analyze with correct note frequencies."""
        # C4 = 261.63, D4 = 293.66, E4 = 329.63, G4 = 392.00
        audio = self._generate_wav([261.63, 293.66, 329.63, 392.00])
        resp = self.client.post(
            "/api/audio-ai/analyze",
            data={"user_id": 1, "exercise_id": "beg_1", "target_notes": "C4, D4, E4, G4"},
            files={"file": ("singing.wav", audio, "audio/wav")}
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["target_notes"], ["C4", "D4", "E4", "G4"])
        self.assertEqual(data["detected_notes"], ["C4", "D4", "E4", "G4"])
        self.assertGreaterEqual(data["pitch_accuracy"], 80)
        self.assertEqual(data["note_accuracy"], 100)
        self.assertIn("feedback", data)
        self.assertIn("notes", data)
        self.assertEqual(len(data["notes"]), 4)

    def test_audio_ai_analyze_endpoint_incorrect_note(self):
        """Test POST /api/audio-ai/analyze with one wrong note (D#4 instead of E4)."""
        # C4 = 261.63, D4 = 293.66, D#4 = 311.13, G4 = 392.00
        audio = self._generate_wav([261.63, 293.66, 311.13, 392.00])
        resp = self.client.post(
            "/api/audio-ai/analyze",
            data={"user_id": 1, "exercise_id": "beg_1", "target_notes": "C4, D4, E4, G4"},
            files={"file": ("singing.wav", audio, "audio/wav")}
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertEqual(data["target_notes"], ["C4", "D4", "E4", "G4"])
        self.assertEqual(data["detected_notes"], ["C4", "D4", "D#4", "G4"])
        self.assertEqual(data["note_accuracy"], 75)
        self.assertIn("D#4", data["feedback"])

    def test_practice_evaluate_alias_endpoint(self):
        """Test POST /api/practice/evaluate alias endpoint."""
        audio = self._generate_wav([261.63, 329.63, 392.00])
        resp = self.client.post(
            "/api/practice/evaluate",
            data={"user_id": 1, "exercise_id": "beg_1"},
            files={"file": ("practice.wav", audio, "audio/wav")}
        )
        self.assertEqual(resp.status_code, 200)
        data = resp.json()
        self.assertIn("accuracy_score", data)
        self.assertIn("feedback", data)


if __name__ == "__main__":
    unittest.main()
