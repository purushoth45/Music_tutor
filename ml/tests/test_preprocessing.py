"""
Unit tests for Audio Preprocessing, Feature Extraction, and Label Generation.
"""

import unittest
import numpy as np
from ml.preprocessing.audio_preprocessor import AudioPreprocessor
from ml.preprocessing.feature_extractor import FeatureExtractor
from ml.preprocessing.label_generator import LabelGenerator


class TestAudioPreprocessing(unittest.TestCase):

    def setUp(self):
        self.preprocessor = AudioPreprocessor(target_sample_rate=16000, mono=True)
        self.feature_extractor = FeatureExtractor(sample_rate=16000)
        self.label_generator = LabelGenerator(hop_length=160, sample_rate=16000)

    def test_audio_resampling_and_framing(self):
        # 1-second 440Hz sine wave
        t = np.linspace(0, 1.0, 16000, endpoint=False)
        sine_wave = 0.5 * np.sin(2 * np.pi * 440 * t)

        processed, sr = self.preprocessor.process_waveform(sine_wave, 16000)
        self.assertEqual(sr, 16000)
        self.assertAlmostEqual(float(np.max(np.abs(processed))), 1.0)

        frames = self.preprocessor.create_frames(processed, frame_length=640, hop_length=160)
        self.assertGreater(len(frames), 0)
        self.assertEqual(frames.shape[1], 640)

    def test_feature_extractor_dimensions(self):
        dummy_audio = np.random.randn(16000).astype(np.float32)
        mel_spec = self.feature_extractor.extract_mel_spectrogram(dummy_audio)
        self.assertEqual(mel_spec.shape[0], 128)

        stft_spec = self.feature_extractor.extract_stft(dummy_audio)
        self.assertEqual(stft_spec.shape[0], 513)

    def test_hz_midi_conversions(self):
        midi_a4 = LabelGenerator.hz_to_midi(440.0)
        self.assertAlmostEqual(midi_a4, 69.0)

        hz_a4 = LabelGenerator.midi_to_hz(69.0)
        self.assertAlmostEqual(hz_a4, 440.0)

    def test_frame_label_alignment(self):
        timestamps = np.array([0.0, 0.01, 0.02, 0.03])
        f0_values = np.array([440.0, 440.0, 0.0, 0.0])
        f0_targets, voiced_targets = self.label_generator.generate_frame_targets(
            timestamps, f0_values, total_duration=0.05
        )
        self.assertEqual(len(f0_targets), len(voiced_targets))
        self.assertEqual(voiced_targets[0], 1.0)
        self.assertEqual(voiced_targets[2], 0.0)


if __name__ == "__main__":
    unittest.main()
