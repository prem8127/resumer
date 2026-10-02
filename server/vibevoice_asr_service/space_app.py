from __future__ import annotations

import os
from pathlib import Path
import secrets
import subprocess

import gradio as gr
import spaces
from huggingface_hub import snapshot_download


ROOT = Path("/tmp/resumer-vibevoice")
SOURCE_DIR = ROOT / "VibeASR.cpp"
BUILD_DIR = SOURCE_DIR / "build"
MODEL_DIR = ROOT / "models"
ASR_BINARY = BUILD_DIR / "bin" / "asr_infer"
API_KEY = os.getenv("VIBEVOICE_ASR_API_KEY", "").strip()


def _run(command: list[str], *, timeout: int = 3600) -> None:
    subprocess.run(command, check=True, timeout=timeout)


def _prepare_runtime() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)
    if not SOURCE_DIR.is_dir():
        _run([
            "git", "clone", "--depth", "1", "--recurse-submodules",
            "https://github.com/microsoft/VibeASR.cpp.git", str(SOURCE_DIR),
        ])
    if not ASR_BINARY.is_file():
        _run([
            "cmake", "-S", str(SOURCE_DIR), "-B", str(BUILD_DIR),
            "-DCMAKE_BUILD_TYPE=Release",
        ])
        _run(["cmake", "--build", str(BUILD_DIR), "--target", "asr_infer", "-j2"])
    if not (MODEL_DIR / "vibeasr-vae-encoder-i8_s.gguf").is_file() or not (
        MODEL_DIR / "vibeasr-lm-i2_s-embed-q6_k.gguf"
    ).is_file():
        snapshot_download(
            repo_id="microsoft/VibeVoice-ASR-BitNet",
            local_dir=str(MODEL_DIR),
            allow_patterns=["*.gguf"],
        )


@spaces.GPU
def _zerogpu_runtime_marker() -> None:
    """Satisfy the ZeroGPU runtime check without scheduling transcription."""
    return None


def transcribe(audio_path: str | None, supplied_key: str) -> str:
    if not API_KEY:
        raise gr.Error("The transcription service key is not configured yet.")
    if not isinstance(supplied_key, str) or not secrets.compare_digest(supplied_key, API_KEY):
        raise gr.Error("Invalid transcription service key.")
    if not audio_path:
        raise gr.Error("Upload a WAV recording first.")

    audio = Path(audio_path)
    if not audio.is_file() or audio.stat().st_size > 20 * 1024 * 1024:
        raise gr.Error("Recording is missing or exceeds the 20 MB limit.")
    with audio.open("rb") as recording:
        header = recording.read(12)
    if len(header) < 12 or header[:4] != b"RIFF" or header[8:12] != b"WAVE":
        raise gr.Error("Expected a WAV recording.")

    result = subprocess.run(
        [
            str(ASR_BINARY),
            "--vae-model", str(MODEL_DIR / "vibeasr-vae-encoder-i8_s.gguf"),
            "--lm-model", str(MODEL_DIR / "vibeasr-lm-i2_s-embed-q6_k.gguf"),
            "--audio", str(audio),
            "-t", "2",
            "--greedy",
            "--max-tokens", "512",
        ],
        capture_output=True,
        text=True,
        check=False,
        timeout=180,
    )
    if result.returncode != 0:
        raise gr.Error("VibeVoice could not transcribe this recording.")
    transcript = result.stdout.strip()
    if not transcript:
        raise gr.Error("No speech was recognized. Try recording again.")
    return transcript[:8000]


_prepare_runtime()

demo = gr.Interface(
    fn=transcribe,
    inputs=[
        gr.Audio(type="filepath", label="WAV recording"),
        gr.Textbox(type="password", label="Service key"),
    ],
    outputs=gr.Textbox(label="Transcript"),
    title="Resumer interview transcription",
    description="CPU transcription using Microsoft's VibeVoice ASR. The Resumer API supplies the private service key.",
    api_name="transcribe",
)

# Hugging Face runs the Gradio app file as a normal Python entry point. Without
# an explicit launch call, setup completes and the container exits successfully,
# which appears as a runtime error in the Space.
demo.launch(
    server_name="0.0.0.0",
    server_port=int(os.getenv("PORT", "7860")),
)
