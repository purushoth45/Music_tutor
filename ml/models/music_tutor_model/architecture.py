"""
Neural Pitch Model Architecture Module.

Defines the feature extraction backbone (Conv2D / Conv1D layers)
and temporal modeling layers (BiGRU / Transformer) for frame-level pitch prediction.
"""

from typing import Tuple, Dict, Any


class ConvBackbone:
    """
    Convolutional feature extractor converting raw audio or spectrogram frames
    into deep time-frequency embeddings.
    """

    def __init__(self, in_channels: int = 1, out_channels: int = 128):
        self.in_channels = in_channels
        self.out_channels = out_channels

    def get_output_dims(self, input_shape: Tuple[int, ...]) -> Tuple[int, ...]:
        """
        Compute output tensor dimension given input tensor shape.
        """
        # Placeholder dimension calculator
        return (input_shape[0], self.out_channels, input_shape[-1])


class TemporalEncoder:
    """
    Recurrent / Transformer temporal encoder for modeling pitch contours over time.
    """

    def __init__(self, input_dim: int = 128, hidden_dim: int = 256, num_layers: int = 2):
        self.input_dim = input_dim
        self.hidden_dim = hidden_dim
        self.num_layers = num_layers

    def get_output_dim(self) -> int:
        return self.hidden_dim * 2  # Bidirectional output
