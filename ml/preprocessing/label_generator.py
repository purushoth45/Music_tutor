"""
Label Generator Module for Music Tutor ML Pipeline.

Converts ground-truth pitch annotations into frame-aligned target tensors
(F0 frequency in Hz, binary voicing targets, note indices).
"""

from typing import Tuple, List, Optional
import numpy as np


class LabelGenerator:
    """
    Generates aligned pitch and voicing training targets from dataset annotations.
    """

    def __init__(self, hop_length: int = 160, sample_rate: int = 16000):
        self.hop_length = hop_length
        self.sample_rate = sample_rate
        self.frame_duration = hop_length / sample_rate  # e.g., 0.01s = 10ms

    def generate_frame_targets(
        self, timestamps: np.ndarray, f0_values: np.ndarray, total_duration: float
    ) -> Tuple[np.ndarray, np.ndarray]:
        """
        Align continuous ground-truth F0 values to discrete 10ms time frames.
        
        Args:
            timestamps: 1D array of ground truth timestamp offsets (seconds).
            f0_values: 1D array of corresponding F0 frequency values in Hz.
            total_duration: Total audio clip duration in seconds.
            
        Returns:
            Tuple of (f0_targets, voiced_targets) for each frame.
            - f0_targets: 1D array of shape [num_frames] with Hz values.
            - voiced_targets: 1D array of shape [num_frames] with binary 0/1 voicing.
        """
        num_frames = int(np.ceil(total_duration / self.frame_duration))
        f0_targets = np.zeros(num_frames, dtype=np.float32)
        voiced_targets = np.zeros(num_frames, dtype=np.float32)

        for ts, f0 in zip(timestamps, f0_values):
            frame_idx = int(np.round(ts / self.frame_duration))
            if 0 <= frame_idx < num_frames:
                f0_targets[frame_idx] = max(0.0, float(f0))
                voiced_targets[frame_idx] = 1.0 if f0 > 0.0 else 0.0

        return f0_targets, voiced_targets

    @staticmethod
    def hz_to_midi(f0_hz: float) -> Optional[float]:
        """Convert frequency in Hz to fractional MIDI note number."""
        if f0_hz <= 0:
            return None
        return 69.0 + 12.0 * np.log2(f0_hz / 440.0)

    @staticmethod
    def midi_to_hz(midi_note: float) -> float:
        """Convert fractional MIDI note number to frequency in Hz."""
        return 440.0 * (2.0 ** ((midi_note - 69.0) / 12.0))
