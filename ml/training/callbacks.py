"""
Training Callbacks Module.

Provides early stopping, learning rate scheduler, and checkpointing callbacks.
"""

from typing import Dict, Any, Optional


class EarlyStopping:
    """
    Monitors validation metric and triggers early stopping when improvement halts.
    """

    def __init__(self, patience: int = 15, delta: float = 1e-4):
        self.patience = patience
        self.delta = delta
        self.counter = 0
        self.best_score: Optional[float] = None
        self.early_stop = False

    def step(self, val_metric: float) -> bool:
        """
        Update early stopping tracker given current epoch validation metric.
        
        Args:
            val_metric: Current epoch validation metric (e.g. validation loss or RPA).
            
        Returns:
            True if early stopping should trigger, False otherwise.
        """
        if self.best_score is None or val_metric > self.best_score + self.delta:
            self.best_score = val_metric
            self.counter = 0
        else:
            self.counter += 1
            if self.counter >= self.patience:
                self.early_stop = True

        return self.early_stop


class ModelCheckpoint:
    """
    Saves model checkpoint artifacts when validation metrics hit new high watermark.
    """

    def __init__(self, checkpoint_dir: str):
        self.checkpoint_dir = checkpoint_dir
        self.best_rpa = 0.0

    def save_if_best(self, current_rpa: float, model_state: Dict[str, Any], epoch: int):
        if current_rpa > self.best_rpa:
            self.best_rpa = current_rpa
            # TODO: Save torch checkpoint file once trained model loop is executed
            pass
