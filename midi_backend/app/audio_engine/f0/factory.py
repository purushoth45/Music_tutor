"""
F0 Engine Factory.

Provides a unified factory function to obtain configured F0 engines (RMVPE, CREPE).
Configurable via parameter or F0_ENGINE environment variable.
"""

import os
from typing import Optional, Dict
from app.audio_engine.f0.base import F0Engine
from app.audio_engine.f0.rmvpe_engine import RMVPEF0Engine
from app.audio_engine.f0.crepe_engine import CREPEF0Engine

_ENGINE_CACHE: Dict[str, F0Engine] = {}


def get_f0_engine(
    engine_name: Optional[str] = None,
    rmvpe_path: str = "models/pitch_model/rmvpe.pt",
    crepe_path: str = "models/pitch_model/full.pth",
    device: Optional[str] = None
) -> F0Engine:
    """
    Get or create an F0 extraction engine instance.
    
    Args:
        engine_name: 'rmvpe' or 'crepe'. Defaults to F0_ENGINE env var or 'rmvpe'.
        rmvpe_path: Path to rmvpe.pt checkpoint.
        crepe_path: Path to full.pth checkpoint.
        device: Device to use ('cpu', 'mps', 'cuda').
        
    Returns:
        F0Engine instance.
    """
    target = (engine_name or os.environ.get("F0_ENGINE", "rmvpe")).strip().lower()
    cache_key = f"{target}:{rmvpe_path}:{crepe_path}:{device}"

    if cache_key in _ENGINE_CACHE:
        return _ENGINE_CACHE[cache_key]

    if target == "rmvpe":
        engine = RMVPEF0Engine(model_path=rmvpe_path, device=device)
    elif target in ("crepe", "torchcrepe"):
        engine = CREPEF0Engine(model_path=crepe_path, device=device)
    else:
        raise ValueError(f"Unknown F0 engine '{target}'. Supported engines: 'rmvpe', 'crepe'")

    _ENGINE_CACHE[cache_key] = engine
    return engine
