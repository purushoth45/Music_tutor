"""
Audio Preprocessor Module for Music Tutor ML Pipeline.

Provides reusable utilities for loading, resampling, normalizing,
and framing raw audio files into standardized formats.
"""

from typing import Tuple, Optional
import numpy as np


class AudioPreprocessor:
    """
    Handles standard audio preprocessing steps for pitch model ingestion.
    """

    def __init__(self, target_sample_rate: int = 16000, mono: bool = True):
        self.target_sample_rate = target_sample_rate
        self.mono = mono

    def process_waveform(
        self, audio_data: np.ndarray, orig_sr: int
    ) -> Tuple[np.ndarray, int]:
        """
        Resample, convert to mono, and normalize raw audio data.
        
        Args:
            audio_data: Raw audio waveform array.
            orig_sr: Original sampling rate of the audio data.
            
        Returns:
            Tuple of (processed_waveform, target_sample_rate)
        """
        waveform = audio_data.astype(np.float32)

        # Mono conversion if multi-channel
        if waveform.ndim > 1 and self.mono:
            waveform = np.mean(waveform, axis=0)

        # Peak normalization (-1.0 to 1.0)
        max_val = np.max(np.abs(waveform))
        if max_val > 0:
            waveform = waveform / max_val

        # Resampling placeholder (to be wired with scipy.signal / torchaudio)
        if orig_sr != self.target_sample_rate:
            # TODO: Implement precise polyphase resampling when torchaudio/scipy is connected
            pass

        return waveform, self.target_sample_rate

    def create_frames(
        self, waveform: np.ndarray, frame_length: int = 640, hop_length: int = 160
    ) -> np.ndarray:
        """
        Slice continuous 1D waveform into overlapping 2D frames.
        
        Args:
            waveform: 1D audio array.
            frame_length: Number of samples per frame context (e.g. 40ms @ 16kHz).
            hop_length: Frame hop step size (e.g. 10ms @ 16kHz = 160 samples).
            
        Returns:
            2D numpy array of shape [num_frames, frame_length].
        """
        if len(waveform) < frame_length:
            pad_width = frame_length - len(waveform)
            waveform = np.pad(waveform, (0, pad_width), mode='constant')

        num_frames = 1 + (len(waveform) - frame_length) // hop_length
        shape = (num_frames, frame_length)
        strides = (waveform.strides[0] * hop_length, waveform.strides[0])
        
        return np.lib.stride_tricks.as_strided(waveform, shape=shape, strides=strides)
