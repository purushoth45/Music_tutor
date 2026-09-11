"""
Dataset Builder Module for Music Tutor ML Pipeline.

Scans dataset directories, parses ground-truth annotations, creates train/val/test
splits, and saves index metadata CSV files.
"""

import os
from typing import List, Dict, Any
import numpy as np


class DatasetBuilder:
    """
    Builds dataset manifest CSV files for PyTorch DataLoader ingestion.
    """

    def __init__(self, dataset_dir: str, output_dir: str):
        self.dataset_dir = dataset_dir
        self.output_dir = output_dir

    def scan_dataset(self) -> List[Dict[str, Any]]:
        """
        Scan dataset raw directory and match audio tracks with annotation files.
        
        Returns:
            List of track metadata dictionaries.
        """
        tracks = []
        raw_dir = os.path.join(self.dataset_dir, "raw")
        if not os.path.exists(raw_dir):
            return tracks

        # Scan dataset folder structure
        for root, _, files in os.walk(raw_dir):
            for file in files:
                if file.endswith(".wav") or file.endswith(".flac"):
                    audio_path = os.path.join(root, file)
                    tracks.append({
                        "audio_path": audio_path,
                        "annotation_path": "",
                        "dataset_name": os.path.basename(root),
                    })

        return tracks

    def create_splits(
        self,
        tracks: List[Dict[str, Any]],
        train_ratio: float = 0.8,
        val_ratio: float = 0.1,
        seed: int = 42
    ) -> Dict[str, List[Dict[str, Any]]]:
        """
        Create deterministic train/validation/test splits.
        """
        np.random.seed(seed)
        shuffled = tracks.copy()
        np.random.shuffle(shuffled)

        n_total = len(shuffled)
        n_train = int(n_total * train_ratio)
        n_val = int(n_total * val_ratio)

        return {
            "train": shuffled[:n_train],
            "validation": shuffled[n_train:n_train + n_val],
            "test": shuffled[n_train + n_val:]
        }
