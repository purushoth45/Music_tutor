"""
Main Training Execution Script.

Entrypoint for initiating training routines for the Music Tutor Neural Pitch Model.
"""

import sys
import argparse
from ml.training.config import TrainingConfig, AudioConfig
from ml.training.trainer import ModelTrainer


def main():
    parser = argparse.ArgumentParser(description="Train Music Tutor Neural Pitch Model")
    parser.add_argument("--epochs", type=int, default=100, help="Number of training epochs")
    parser.add_argument("--batch-size", type=int, default=32, help="Training batch size")
    parser.add_argument("--lr", type=float, default=1e-3, help="Learning rate")
    args = parser.parse_args()

    train_config = TrainingConfig(
        num_epochs=args.epochs,
        batch_size=args.batch_size,
        learning_rate=args.lr
    )
    audio_config = AudioConfig()

    print("==================================================================")
    print(" MUSIC TUTOR - ML PITCH DETECTOR TRAINING PIPELINE")
    print("==================================================================")
    print(f" Config: Epochs={train_config.num_epochs}, Batch={train_config.batch_size}, LR={train_config.learning_rate}")
    print(" Status: Pipeline initialized. Awaiting dataset ingestion.")
    print(" NOTE: Run dataset preprocessing scripts prior to model training.")
    print("==================================================================")

    trainer = ModelTrainer(train_config, audio_config)
    # TODO: Connect dataset loader and invoke trainer.fit(train_loader, val_loader)


if __name__ == "__main__":
    main()
