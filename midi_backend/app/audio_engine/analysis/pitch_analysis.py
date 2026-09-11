"""
Pitch Analysis Module.

Converts raw frame-level pitch sequences into musical note detections,
computes intonation cents errors, segments sustained musical notes,
and evaluates temporal alignment against exercise target notes.
"""

from typing import List, Dict, Any, Tuple, Optional, Union
import numpy as np


class PitchAnalyzer:
    """
    Analyzes raw predicted pitch tracks against expected musical exercises.
    """

    NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']

    @classmethod
    def hz_to_note_name(cls, f0_hz: float) -> Optional[str]:
        """Convert Hz frequency to standard scientific pitch notation (e.g. 440 Hz -> A4)."""
        if f0_hz <= 0:
            return None
        midi_num = int(round(69.0 + 12.0 * np.log2(f0_hz / 440.0)))
        note_idx = midi_num % 12
        octave = (midi_num // 12) - 1
        return f"{cls.NOTE_NAMES[note_idx]}{octave}"

    @classmethod
    def note_name_to_hz(cls, note_name: str) -> Optional[float]:
        """Convert scientific pitch notation (e.g. 'A4', 'C#4', 'Db4') to reference Hz."""
        if not note_name or len(note_name) < 2:
            return None

        name = note_name.strip()
        octave_str = ""
        while name and (name[-1].isdigit() or name[-1] == '-'):
            octave_str = name[-1] + octave_str
            name = name[:-1]

        if not octave_str:
            return None

        try:
            octave = int(octave_str)
        except ValueError:
            return None

        pitch_class = name.upper()
        # Handle flats
        flat_map = {'DB': 'C#', 'EB': 'D#', 'GB': 'F#', 'AB': 'G#', 'BB': 'A#'}
        pitch_class = flat_map.get(pitch_class, pitch_class)

        if pitch_class not in cls.NOTE_NAMES:
            return None

        note_idx = cls.NOTE_NAMES.index(pitch_class)
        midi_num = (octave + 1) * 12 + note_idx
        return float(440.0 * (2.0 ** ((midi_num - 69.0) / 12.0)))

    @classmethod
    def hz_to_note_info(cls, f0_hz: float) -> Optional[Dict[str, Any]]:
        """
        Convert frequency in Hz to full pitch and musical note metrics.
        
        Returns:
            Dict with note_name, midi_val, nearest_midi, reference_hz, cents_deviation.
        """
        if f0_hz <= 0 or np.isnan(f0_hz) or np.isinf(f0_hz):
            return None

        midi_val = 69.0 + 12.0 * np.log2(f0_hz / 440.0)
        nearest_midi = int(round(midi_val))
        note_idx = nearest_midi % 12
        octave = (nearest_midi // 12) - 1
        note_name = f"{cls.NOTE_NAMES[note_idx]}{octave}"

        reference_hz = 440.0 * (2.0 ** ((nearest_midi - 69.0) / 12.0))
        cents_deviation = 1200.0 * np.log2(f0_hz / reference_hz)

        return {
            "note_name": note_name,
            "midi_val": float(midi_val),
            "nearest_midi": nearest_midi,
            "reference_hz": float(reference_hz),
            "cents_deviation": float(cents_deviation),
            "detected_hz": float(f0_hz),
        }

    @staticmethod
    def calculate_cents_deviation(detected_hz: float, expected_hz: float) -> float:
        """Compute pitch deviation in cents between detected and expected frequency."""
        if detected_hz <= 0 or expected_hz <= 0 or np.isnan(detected_hz) or np.isnan(expected_hz):
            return 0.0
        return float(1200.0 * np.log2(detected_hz / expected_hz))

    def segment_notes(
        self,
        f0_sequence: List[float],
        hop_sec: float = 0.010,
        min_duration_sec: float = 0.08
    ) -> List[Dict[str, Any]]:
        """
        Segment continuous frame-level F0 track into discrete musical note events.
        
        Filters out transient flutter shorter than min_duration_sec.
        
        Returns:
            List of note event dicts:
            [{'note': 'C4', 'start_time': 0.1, 'end_time': 0.6, 'duration': 0.5,
              'mean_f0': 261.4, 'cents_deviation': -1.2, 'frame_count': 50}, ...]
        """
        min_frames = max(1, int(round(min_duration_sec / hop_sec)))
        events: List[Dict[str, Any]] = []

        current_note: Optional[str] = None
        current_f0s: List[float] = []
        start_frame: int = 0

        for idx, f0 in enumerate(f0_sequence):
            if f0 > 0:
                note = self.hz_to_note_name(f0)
            else:
                note = None

            if note == current_note:
                if note is not None:
                    current_f0s.append(f0)
            else:
                # Note changed or went unvoiced
                if current_note is not None and len(current_f0s) >= min_frames:
                    mean_f0 = float(np.mean(current_f0s))
                    ref_hz = self.note_name_to_hz(current_note) or mean_f0
                    cents = self.calculate_cents_deviation(mean_f0, ref_hz)
                    events.append({
                        "note": current_note,
                        "start_time": float(start_frame * hop_sec),
                        "end_time": float(idx * hop_sec),
                        "duration": float(len(current_f0s) * hop_sec),
                        "mean_f0": mean_f0,
                        "cents_deviation": float(cents),
                        "frame_count": len(current_f0s),
                    })

                current_note = note
                current_f0s = [f0] if note is not None else []
                start_frame = idx

        # Close final note event
        if current_note is not None and len(current_f0s) >= min_frames:
            mean_f0 = float(np.mean(current_f0s))
            ref_hz = self.note_name_to_hz(current_note) or mean_f0
            cents = self.calculate_cents_deviation(mean_f0, ref_hz)
            events.append({
                "note": current_note,
                "start_time": float(start_frame * hop_sec),
                "end_time": float(len(f0_sequence) * hop_sec),
                "duration": float(len(current_f0s) * hop_sec),
                "mean_f0": mean_f0,
                "cents_deviation": float(cents),
                "frame_count": len(current_f0s),
            })

        return events

    @staticmethod
    def align_note_sequences(
        detected_notes: List[str], target_notes: List[str]
    ) -> List[Tuple[Optional[str], Optional[str]]]:
        """
        Align detected musical notes sequence with target musical notes using Needleman-Wunsch.
        
        Returns:
            List of (target_note, detected_note) tuples.
        """
        if not target_notes and not detected_notes:
            return []
        if not target_notes:
            return [(None, d) for d in detected_notes]
        if not detected_notes:
            return [(t, None) for t in target_notes]

        n = len(target_notes)
        m = len(detected_notes)

        # Dynamic programming scoring matrix
        match_score = 2
        mismatch_score = -1
        gap_penalty = -1

        dp = np.zeros((n + 1, m + 1), dtype=int)
        for i in range(n + 1):
            dp[i, 0] = i * gap_penalty
        for j in range(m + 1):
            dp[0, j] = j * gap_penalty

        for i in range(1, n + 1):
            for j in range(1, m + 1):
                t_n = target_notes[i - 1]
                d_n = detected_notes[j - 1]
                score = match_score if t_n == d_n else mismatch_score
                dp[i, j] = max(
                    dp[i - 1, j - 1] + score,
                    dp[i - 1, j] + gap_penalty,
                    dp[i, j - 1] + gap_penalty
                )

        # Traceback
        aligned_pairs: List[Tuple[Optional[str], Optional[str]]] = []
        i, j = n, m
        while i > 0 or j > 0:
            if i > 0 and j > 0:
                t_n = target_notes[i - 1]
                d_n = detected_notes[j - 1]
                score = match_score if t_n == d_n else mismatch_score
                if dp[i, j] == dp[i - 1, j - 1] + score:
                    aligned_pairs.append((t_n, d_n))
                    i -= 1
                    j -= 1
                    continue

            if i > 0 and (j == 0 or dp[i, j] == dp[i - 1, j] + gap_penalty):
                aligned_pairs.append((target_notes[i - 1], None))
                i -= 1
            else:
                aligned_pairs.append((None, detected_notes[j - 1]))
                j -= 1

        aligned_pairs.reverse()
        return aligned_pairs

    def analyze_sequence(
        self, f0_sequence: Union[List[float], Any], target_notes: List[str]
    ) -> Dict[str, Any]:
        """
        Analyze continuous F0 pitch sequence against target note list.
        
        Args:
            f0_sequence: List of frame F0 values in Hz or F0Result object.
            target_notes: List of expected target note strings (e.g. ['C4', 'E4', 'G4']).
            
        Returns:
            Dict containing detected note segments, cents deviation list, and stability statistics.
        """
        # Handle F0Result or raw list
        if hasattr(f0_sequence, 'f0_hz'):
            raw_f0s = f0_sequence.f0_hz.tolist()
            hop_sec = float(getattr(f0_sequence, 'hop_length', 160) / getattr(f0_sequence, 'sample_rate', 16000))
        else:
            raw_f0s = [float(x) for x in f0_sequence]
            hop_sec = 0.010

        detected_notes: List[str] = []
        cents_deviations: List[float] = []
        voiced_f0s = [f for f in raw_f0s if f > 0]

        for f0 in raw_f0s:
            if f0 > 0:
                note_info = self.hz_to_note_info(f0)
                if note_info:
                    detected_notes.append(note_info["note_name"])
                    cents_deviations.append(note_info["cents_deviation"])

        # Discrete note segmentation
        note_events = self.segment_notes(raw_f0s, hop_sec=hop_sec)
        segmented_notes = [ev["note"] for ev in note_events]

        # Sequence alignment
        aligned_pairs = self.align_note_sequences(segmented_notes, target_notes)

        # Matched notes ratio
        matched_notes = [d for t, d in aligned_pairs if t is not None and t == d]
        note_accuracy = int(round((len(matched_notes) / max(1, len(target_notes))) * 100.0))
        note_accuracy = min(100, max(0, note_accuracy))

        # Pitch intonation error on voiced frames
        if cents_deviations:
            mean_abs_cents = float(np.mean(np.abs(cents_deviations)))
            pitch_accuracy = int(round(max(0.0, 100.0 - mean_abs_cents)))
        else:
            pitch_accuracy = 0

        stability_var = float(np.var(voiced_f0s)) if voiced_f0s else 0.0

        return {
            "detected_notes": detected_notes,              # Frame-level notes (backward compatibility)
            "segmented_notes": segmented_notes,            # Discrete sung note events
            "note_events": note_events,                    # Timestamped note objects
            "aligned_pairs": aligned_pairs,                # Alignment [(target, sung), ...]
            "target_notes": target_notes,
            "cents_deviations": cents_deviations,
            "stability_variance": stability_var,
            "note_accuracy": note_accuracy,
            "pitch_accuracy": pitch_accuracy,
            "voiced_frames": len(voiced_f0s),
            "total_frames": len(raw_f0s),
        }
