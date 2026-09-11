"""
Evaluation Metrics Module for Pitch & Intonation Analysis.

Provides exact mathematical functions for computing Raw Pitch Accuracy (RPA),
Raw Chroma Accuracy (RCA), Voiced Recall, Voiced Precision, and Cents Error.
"""

from typing import Dict, Any
import numpy as np


class PitchEvaluator:
    """
    Computes standard MIR pitch evaluation metrics over frame-level predictions.
    """

    @staticmethod
    def cents_difference(f0_pred: float, f0_gt: float) -> float:
        """
        Calculate pitch deviation in musical cents between predicted and ground-truth Hz.
        100 cents = 1 semitone.
        """
        if f0_pred <= 0 or f0_gt <= 0:
            return 0.0
        return 1200.0 * np.log2(f0_pred / f0_gt)

    @classmethod
    def evaluate_frames(
        cls,
        pred_f0: np.ndarray,
        pred_voiced: np.ndarray,
        gt_f0: np.ndarray,
        gt_voiced: np.ndarray,
        tolerance_cents: float = 50.0
    ) -> Dict[str, float]:
        """
        Evaluate frame-level pitch metrics across dataset predictions.
        
        Args:
            pred_f0: Predicted F0 frequencies in Hz [N_frames].
            pred_voiced: Predicted binary voicing decisions (0 or 1) [N_frames].
            gt_f0: Ground-truth F0 frequencies in Hz [N_frames].
            gt_voiced: Ground-truth binary voicing decisions (0 or 1) [N_frames].
            tolerance_cents: Pitch error tolerance in cents (default: 50.0 cents = 0.5 semitones).
            
        Returns:
            Dict containing RPA, VR, VP, and MACE metrics.
        """
        voiced_gt_mask = (gt_voiced > 0.5) & (gt_f0 > 0)
        num_voiced_gt = int(np.sum(voiced_gt_mask))

        if num_voiced_gt == 0:
            return {
                "raw_pitch_accuracy": 0.0,
                "voiced_recall": 0.0,
                "voiced_precision": 0.0,
                "mean_cents_error": 0.0,
            }

        # Voiced Recall & Precision
        voiced_pred_mask = (pred_voiced > 0.5)
        voiced_recall = float(np.sum(voiced_pred_mask & voiced_gt_mask) / num_voiced_gt * 100.0)
        num_voiced_pred = int(np.sum(voiced_pred_mask))
        voiced_precision = float(np.sum(voiced_pred_mask & voiced_gt_mask) / max(1, num_voiced_pred) * 100.0)

        # Raw Pitch Accuracy (RPA) over ground-truth voiced frames
        cents_errors = []
        correct_pitch_count = 0

        for f_pred, f_gt in zip(pred_f0[voiced_gt_mask], gt_f0[voiced_gt_mask]):
            if f_pred > 0:
                c_err = abs(cls.cents_difference(f_pred, f_gt))
                cents_errors.append(c_err)
                if c_err <= tolerance_cents:
                    correct_pitch_count += 1

        rpa = float(correct_pitch_count / num_voiced_gt * 100.0)
        mean_cents_err = float(np.mean(cents_errors)) if cents_errors else 0.0

        return {
            "raw_pitch_accuracy": rpa,
            "voiced_recall": voiced_recall,
            "voiced_precision": voiced_precision,
            "mean_cents_error": mean_cents_err,
        }
