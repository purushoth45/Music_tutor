"""
Pitch & Voicing Loss Module.

Defines joint multi-task loss functions combining F0 pitch regression loss
and binary voicing classification loss.
"""

from typing import Dict, Any, Tuple


class JointPitchLoss:
    """
    Multi-task loss for joint pitch frequency estimation and voicing classification.
    """

    def __init__(self, f0_weight: float = 1.0, voiced_weight: float = 1.0):
        self.f0_weight = f0_weight
        self.voiced_weight = voiced_weight

    def compute_loss(
        self,
        pred_f0: Any,
        pred_voiced: Any,
        target_f0: Any,
        target_voiced: Any
    ) -> Dict[str, float]:
        """
        Compute F0 pitch loss and voicing BCE loss.
        
        Args:
            pred_f0: Predicted F0 frequencies in Hz [B, T].
            pred_voiced: Predicted voicing logits/probabilities [B, T].
            target_f0: Ground-truth F0 frequencies in Hz [B, T].
            target_voiced: Ground-truth binary voicing flags [B, T].
            
        Returns:
            Dictionary containing 'total_loss', 'f0_loss', and 'voiced_loss'.
        """
        # Placeholder loss evaluation (will use PyTorch nn.L1Loss / BCEWithLogitsLoss)
        f0_loss = 0.0
        voiced_loss = 0.0
        total_loss = self.f0_weight * f0_loss + self.voiced_weight * voiced_loss

        return {
            "total_loss": total_loss,
            "f0_loss": f0_loss,
            "voiced_loss": voiced_loss,
        }
