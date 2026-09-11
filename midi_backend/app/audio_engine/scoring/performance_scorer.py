"""
Performance Scorer Module.

Calculates mathematically transparent, multi-dimensional performance scores:
- Pitch Accuracy Score [0 - 100%]
- Note Accuracy Score [0 - 100%]
- Timing Score [0 - 100%]
- Stability Rating [0.0 - 10.0]
- Overall Combined Score [0 - 100%]
"""

from typing import Dict, Any, List
import numpy as np


class PerformanceScorer:
    """
    Computes weighted performance metrics from musical analysis output.
    """

    def compute_scores(
        self, analysis_result: Dict[str, Any], target_notes: List[str]
    ) -> Dict[str, Any]:
        """
        Compute transparent performance scores.
        
        Args:
            analysis_result: Dict containing analysis data (detected_notes, cents_deviations, etc.).
            target_notes: List of target exercise notes.
            
        Returns:
            Dict containing accuracy_score, note_accuracy, pitch_accuracy,
            stability_score, timing_score, overall_score, and note evaluations.
        """
        detected = analysis_result.get("detected_notes", [])
        segmented = analysis_result.get("segmented_notes", [])
        aligned_pairs = analysis_result.get("aligned_pairs", [])
        cents_deviations = analysis_result.get("cents_deviations", [])
        stability_var = analysis_result.get("stability_variance", 0.0)

        if not detected or not target_notes:
            return {
                "accuracy_score": 0,
                "note_accuracy": 0,
                "pitch_accuracy": 0,
                "stability_score": 0.0,
                "timing_score": 0,
                "overall_score": 0,
                "note_evaluations": [],
            }

        # 1. Note Accuracy: how many target notes were sung correctly in sequence
        if aligned_pairs:
            matched_pairs = [p for p in aligned_pairs if p[0] is not None and p[0] == p[1]]
            note_accuracy = int(round((len(matched_pairs) / max(1, len(target_notes))) * 100.0))
        elif segmented:
            matched_count = sum(1 for s in segmented if s in target_notes)
            note_accuracy = int(round((matched_count / max(1, len(target_notes))) * 100.0))
        else:
            matched_count = sum(1 for d in detected if d in target_notes)
            note_accuracy = int(round((matched_count / max(1, len(target_notes))) * 100.0))

        note_accuracy = min(100, max(0, note_accuracy))

        # 2. Pitch Accuracy: intonation accuracy (cents error on voiced frames)
        if cents_deviations:
            mean_abs_cents = float(np.mean(np.abs(cents_deviations)))
            # 0 cents error -> 100%, 50 cents error -> 50%, >= 100 cents error -> 0%
            pitch_acc = max(0.0, 100.0 - mean_abs_cents)
            pitch_accuracy = int(round(pitch_acc))
        else:
            # Fallback to note accuracy if no fine cents available
            pitch_accuracy = note_accuracy

        pitch_accuracy = min(100, max(0, pitch_accuracy))

        # 3. Stability Score [0.0 - 10.0]
        # Low variance in sustained pitch indicates rock-solid vocal support
        if stability_var <= 0.0:
            stability_score = 8.5
        else:
            # variance of 25 Hz^2 -> std ~ 5Hz -> stability ~ 9.0
            # variance of 400 Hz^2 -> std ~ 20Hz -> stability ~ 6.0
            std_dev = np.sqrt(stability_var)
            stability_score = max(1.0, min(10.0, 10.0 - (std_dev / 5.0)))
            stability_score = round(float(stability_score), 1)

        # 4. Timing Score [0 - 100]
        note_events = analysis_result.get("note_events", [])
        if note_events and len(note_events) > 1:
            durations = [ev["duration"] for ev in note_events]
            dur_cv = float(np.std(durations) / (np.mean(durations) + 1e-6))
            timing_score = int(round(max(40, min(100, 100 - (dur_cv * 40)))))
        else:
            timing_score = 85

        # 5. Overall Composite Score [0 - 100%]
        overall = int(round(
            0.40 * pitch_accuracy +
            0.30 * note_accuracy +
            0.15 * timing_score +
            0.15 * (stability_score * 10.0)
        ))
        overall = min(100, max(0, overall))

        # Backward compatibility: accuracy_score represents overall accuracy
        accuracy_score = note_accuracy if note_accuracy > 0 else pitch_accuracy

        # Per-note evaluations
        note_evaluations = []
        if aligned_pairs:
            for target, detected_note in aligned_pairs:
                if target is not None and detected_note is not None:
                    is_match = (target == detected_note)
                    note_evaluations.append({
                        "target": target,
                        "detected": detected_note,
                        "matched": is_match,
                        "status": "correct" if is_match else "incorrect"
                    })
                elif target is not None:
                    note_evaluations.append({
                        "target": target,
                        "detected": None,
                        "matched": False,
                        "status": "missed"
                    })
                elif detected_note is not None:
                    note_evaluations.append({
                        "target": None,
                        "detected": detected_note,
                        "matched": False,
                        "status": "extra"
                    })

        return {
            "accuracy_score": accuracy_score,
            "note_accuracy": note_accuracy,
            "pitch_accuracy": pitch_accuracy,
            "stability_score": float(stability_score),
            "timing_score": timing_score,
            "overall_score": overall,
            "note_evaluations": note_evaluations,
        }
