"""
Real-Time Mac Microphone Pitch Detection & Live Pitch Visualizer.

Captures real-time audio from macOS microphone via sounddevice (CoreAudio) at 16 kHz mono,
feeds streaming audio buffers to pretrained neural F0 models (RMVPE / TorchCREPE),
and displays real-time frequency, musical note, cents intonation, confidence,
voiced status, inference latency, and updates/sec with an ANSI rolling pitch track.
"""

import os
import sys
import argparse
import time
import signal
import queue
from typing import Optional, Tuple
import numpy as np

# Ensure midi_backend and project root are on sys.path
project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../../.."))
midi_backend_dir = os.path.join(project_root, "midi_backend")
if midi_backend_dir not in sys.path:
    sys.path.insert(0, midi_backend_dir)
if project_root not in sys.path:
    sys.path.insert(0, project_root)

from app.audio_engine.f0.base import resolve_model_path, F0Result
from app.audio_engine.f0.rmvpe_engine import RMVPEF0Engine
from app.audio_engine.f0.crepe_engine import CREPEF0Engine
from app.audio_engine.analysis.pitch_analysis import PitchAnalyzer


class RealTimePitchDetector:
    """
    Streams live microphone audio, executes pretrained F0 neural inference,
    and renders dynamic terminal pitch diagnostics and visualizer.
    """

    SAMPLE_RATE = 16000

    def __init__(
        self,
        engine_name: str = "rmvpe",
        chunk_size: int = 1024,
        buffer_size: int = 2048,
        confidence_threshold: float = 0.35,
        device_index: Optional[int] = None,
        enable_visualizer: bool = True,
        simulate_mic: bool = False
    ):
        self.engine_name = engine_name.lower()
        self.chunk_size = chunk_size
        self.buffer_size = buffer_size
        self.confidence_threshold = confidence_threshold
        self.device_index = device_index
        self.enable_visualizer = enable_visualizer
        self.simulate_mic = simulate_mic

        self.audio_queue: queue.Queue = queue.Queue(maxsize=50)
        self.running = False
        self.ring_buffer = np.zeros(self.buffer_size, dtype=np.float32)

        # Load engine
        self._init_engine()

        # Metrics history
        self.frames_processed = 0
        self.voiced_count = 0
        self.latencies = []

    def _init_engine(self):
        """Load requested pretrained F0 model."""
        if self.engine_name == "crepe":
            path = resolve_model_path("models/pitch_model/full.pth")
            self.engine = CREPEF0Engine(model_path=path)
        else:
            path = resolve_model_path("models/pitch_model/rmvpe.pt")
            self.engine = RMVPEF0Engine(model_path=path)

        if not self.engine.is_loaded:
            raise RuntimeError(
                f"Failed to load checkpoint for {self.engine.name} from {self.engine.model_path}"
            )

    def _audio_callback(self, indata, frames, time_info, status):
        """Audio streaming callback executed by sounddevice in audio thread."""
        if status:
            sys.stderr.write(f"[Audio Stream Warning] {status}\n")
        try:
            self.audio_queue.put_nowait(indata[:, 0].copy())
        except queue.Full:
            pass  # Drop frame if processing queue is full to avoid latency drift

    def _render_pitch_bar(self, note: str, cents: float, confidence: float) -> str:
        """Create a 30-char horizontal intonation meter: [-------|-------]."""
        bar_width = 25
        center = bar_width // 2
        clamped_cents = max(-50.0, min(50.0, cents))
        offset = int(round((clamped_cents / 50.0) * center))
        pos = center + offset

        bar = list("·" * bar_width)
        bar[center] = "│"
        if 0 <= pos < bar_width:
            bar[pos] = "◆" if abs(cents) < 10 else "▲"
        bar_str = "".join(bar)

        color = "\033[92m" if abs(cents) < 15 else ("\033[93m" if abs(cents) < 30 else "\033[91m")
        reset = "\033[0m"

        return f"[{color}{bar_str}{reset}]"

    def run(self, max_seconds: Optional[float] = None):
        """
        Start streaming microphone audio and running real-time pitch detection.
        """
        try:
            import sounddevice as sd
        except ImportError:
            print("[Error] 'sounddevice' library is required for real-time microphone test.", flush=True)
            print("Please run: pip install sounddevice", flush=True)
            return

        if self.simulate_mic:
            dev_name = "Simulated Live Vocal Stream (C4 → D4 → E4 → G4)"
            self.device_index = -1
        else:
            # Query and verify audio input device
            try:
                devices = sd.query_devices()
                if self.device_index is not None:
                    dev_info = sd.query_devices(self.device_index, "input")
                else:
                    default_dev = sd.default.device[0]
                    if default_dev == -1 or default_dev is None:
                        # Search for first available input device
                        input_devs = [i for i, d in enumerate(devices) if d.get("max_input_channels", 0) > 0]
                        if not input_devs:
                            raise RuntimeError("No audio input devices (microphones) found on this machine.")
                        self.device_index = input_devs[0]
                    else:
                        self.device_index = default_dev
                    dev_info = sd.query_devices(self.device_index, "input")
                dev_name = f"{dev_info['name']} (Device ID: {self.device_index})"
            except Exception as e:
                print(f"\n[ERROR] Audio Input Device Discovery Failed:\n{e}\n", flush=True)
                print("Note: On headless machines or Macs without a built-in microphone (e.g. Mac mini),", flush=True)
                print("connect a USB/Bluetooth microphone or headset, or run with --simulate-mic to verify", flush=True)
                print("the real-time streaming pipeline and ANSI visualizer.\n", flush=True)
                return

        print("=" * 70, flush=True)
        print("MUSIC TUTOR AI: REAL-TIME MAC MICROPHONE PITCH DETECTOR", flush=True)
        print("=" * 70, flush=True)
        print(f"Input Device:      {dev_name}", flush=True)
        print(f"Sample Rate:       {self.SAMPLE_RATE} Hz Mono", flush=True)
        print(f"Chunk Size:        {self.chunk_size} samples ({(self.chunk_size / self.SAMPLE_RATE) * 1000.0:.1f} ms)", flush=True)
        print(f"Context Buffer:    {self.buffer_size} samples", flush=True)
        print(f"Neural F0 Model:   {self.engine.name} (Strict pretrained checkpoint)", flush=True)
        print(f"Confidence Thresh: {self.confidence_threshold:.2f}", flush=True)
        print("-" * 70, flush=True)
        if self.simulate_mic:
            print("Streaming simulated vocal tones into real-time pipeline... (Ctrl+C to stop)", flush=True)
        else:
            print("Sing or hum into your Mac microphone! (Press Ctrl+C to stop)", flush=True)
        print("-" * 70, flush=True)

        self.running = True
        start_time = time.time()
        fps_t0 = time.time()
        fps_frames = 0
        current_fps = 0.0

        if self.simulate_mic:
            import threading
            def feeder():
                notes = [261.63, 293.66, 329.63, 392.00]  # C4, D4, E4, G4
                phase = 0.0
                dt = self.chunk_size / self.SAMPLE_RATE
                note_idx = 0
                elapsed_note = 0.0
                while self.running:
                    f = notes[note_idx]
                    t = np.linspace(0, dt, self.chunk_size, endpoint=False)
                    chunk = (0.7 * np.sin(2 * np.pi * f * t + phase)).astype(np.float32)
                    phase = (phase + 2 * np.pi * f * dt) % (2 * np.pi)
                    try:
                        self.audio_queue.put(chunk, timeout=0.1)
                    except queue.Full:
                        pass
                    elapsed_note += dt
                    if elapsed_note >= 1.2:
                        elapsed_note = 0.0
                        note_idx = (note_idx + 1) % len(notes)
                    time.sleep(dt * 0.85)

            feed_thread = threading.Thread(target=feeder, daemon=True)
            feed_thread.start()

        def stream_loop():
            nonlocal fps_frames, current_fps, fps_t0
            while self.running:
                if max_seconds and (time.time() - start_time) >= max_seconds:
                    break

                try:
                    chunk = self.audio_queue.get(timeout=0.2)
                except queue.Empty:
                    continue

                # Update ring buffer
                self.ring_buffer = np.roll(self.ring_buffer, -len(chunk))
                self.ring_buffer[-len(chunk):] = chunk

                # Execute neural chunk inference
                t0 = time.time()
                res: F0Result = self.engine.extract_chunk(
                    self.ring_buffer,
                    sample_rate=self.SAMPLE_RATE,
                    confidence_threshold=self.confidence_threshold
                )
                latency_ms = (time.time() - t0) * 1000.0
                self.latencies.append(latency_ms)
                self.frames_processed += 1

                # FPS tracking
                fps_frames += 1
                elapsed_fps = time.time() - fps_t0
                if elapsed_fps >= 0.5:
                    current_fps = fps_frames / elapsed_fps
                    fps_frames = 0
                    fps_t0 = time.time()

                # Extract latest frame status
                if res.num_frames > 0:
                    last_f0 = float(res.f0_hz[-1])
                    last_conf = float(res.confidence[-1])
                    is_voiced = bool(res.voiced[-1])
                else:
                    last_f0 = 0.0
                    last_conf = 0.0
                    is_voiced = False

                if is_voiced and last_f0 > 0:
                    self.voiced_count += 1
                    note_info = PitchAnalyzer.hz_to_note_info(last_f0)
                    note_name = note_info["note_name"] if note_info else "---"
                    cents = note_info["cents_deviation"] if note_info else 0.0
                    voiced_str = "YES"
                    pitch_meter = self._render_pitch_bar(note_name, cents, last_conf)
                else:
                    note_name = "---"
                    cents = 0.0
                    voiced_str = " NO"
                    pitch_meter = "[           ·           ]"

                # Format real-time line
                output_line = (
                    f"\rF0: {last_f0:>6.1f} Hz | "
                    f"Note: {note_name:>3} | "
                    f"Cents: {cents:>+5.1f} | "
                    f"Conf: {last_conf:.2f} | "
                    f"Voiced: {voiced_str} | "
                    f"Latency: {latency_ms:>5.1f}ms | "
                    f"FPS: {current_fps:>4.1f} "
                    f"{pitch_meter if self.enable_visualizer else ''}"
                )
                sys.stdout.write(output_line)
                sys.stdout.flush()

        try:
            if self.simulate_mic:
                stream_loop()
            else:
                with sd.InputStream(
                    samplerate=self.SAMPLE_RATE,
                    channels=1,
                    dtype="float32",
                    blocksize=self.chunk_size,
                    device=self.device_index,
                    callback=self._audio_callback
                ):
                    stream_loop()

        except sd.PortAudioError as pa_err:
            print(f"\n\n[ERROR] macOS CoreAudio / Microphone Access Blocked:\n{pa_err}\n", flush=True)
            print("System Permission Check Required:", flush=True)
            print("1. Open macOS System Settings → Privacy & Security → Microphone.", flush=True)
            print("2. Ensure Terminal / Python / Antigravity IDE is allowed Microphone access.", flush=True)
            print("3. Re-run this command after granting permission.\n", flush=True)
            return
        except KeyboardInterrupt:
            pass
        finally:
            self.running = False
            total_time = time.time() - start_time
            print("\n" + "=" * 70, flush=True)
            print("SESSION SUMMARY", flush=True)
            print("=" * 70, flush=True)
            print(f"Total Duration:    {total_time:.2f} seconds", flush=True)
            print(f"Frames Processed:  {self.frames_processed}", flush=True)
            voiced_pct = (self.voiced_count / max(1, self.frames_processed)) * 100.0
            print(f"Voiced Frames:     {self.voiced_count} ({voiced_pct:.1f}%)", flush=True)
            if self.latencies:
                print(f"Mean Latency:      {np.mean(self.latencies):.1f} ms", flush=True)
                print(f"Min / Max Latency: {np.min(self.latencies):.1f} ms / {np.max(self.latencies):.1f} ms", flush=True)
            avg_fps = self.frames_processed / max(0.1, total_time)
            print(f"Average Updates:   {avg_fps:.1f} frames/sec", flush=True)
            print("=" * 70 + "\n", flush=True)


def main():
    parser = argparse.ArgumentParser(
        description="Music Tutor AI Real-Time Mac Microphone Pitch Detector & Visualizer"
    )
    parser.add_argument(
        "--engine",
        type=str,
        default="rmvpe",
        choices=["rmvpe", "crepe"],
        help="Neural F0 extraction engine (default: rmvpe)"
    )
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=1024,
        help="Samples per microphone audio chunk (default: 1024 = 64ms)"
    )
    parser.add_argument(
        "--buffer-size",
        type=int,
        default=2048,
        help="Context ring buffer size in samples (default: 2048)"
    )
    parser.add_argument(
        "--confidence-th",
        type=float,
        default=0.35,
        help="Voicing confidence threshold [0.0 - 1.0] (default: 0.35)"
    )
    parser.add_argument(
        "--device",
        type=int,
        default=None,
        help="Audio input device ID (default: system default microphone)"
    )
    parser.add_argument(
        "--max-seconds",
        type=float,
        default=None,
        help="Maximum run duration in seconds (for non-interactive testing)"
    )
    parser.add_argument(
        "--no-viz",
        action="store_true",
        help="Disable ANSI rolling pitch visualizer"
    )
    parser.add_argument(
        "--simulate-mic",
        action="store_true",
        help="Simulate live microphone vocal stream (for testing pipeline when no hardware mic is connected)"
    )
    args = parser.parse_args()

    detector = RealTimePitchDetector(
        engine_name=args.engine,
        chunk_size=args.chunk_size,
        buffer_size=args.buffer_size,
        confidence_threshold=args.confidence_th,
        device_index=args.device,
        enable_visualizer=not args.no_viz,
        simulate_mic=args.simulate_mic
    )

    def sig_handler(sig, frame):
        detector.running = False

    signal.signal(signal.SIGINT, sig_handler)
    detector.run(max_seconds=args.max_seconds)


if __name__ == "__main__":
    main()
