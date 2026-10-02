from __future__ import annotations

import asyncio
import os
from pathlib import Path
import secrets
import subprocess
import tempfile

from fastapi import FastAPI, File, HTTPException, Request, UploadFile
from fastapi.responses import JSONResponse


MAX_AUDIO_BYTES = 20 * 1024 * 1024
MODEL_DIR = Path(os.getenv("VIBEVOICE_MODEL_DIR", "/models/vibeasr"))
ASR_BINARY = os.getenv("VIBEVOICE_ASR_BINARY", "/opt/vibeasr/build/bin/asr_infer")
THREADS = max(1, int(os.getenv("VIBEVOICE_ASR_THREADS", "4")))
API_KEY = os.getenv("VIBEVOICE_ASR_API_KEY", "").strip()
_inference_lock = asyncio.Semaphore(1)
app = FastAPI(title="Resumer VibeVoice Transcription", docs_url=None, redoc_url=None)


@app.get("/healthz")
async def healthz() -> JSONResponse:
    ready = Path(ASR_BINARY).is_file() and all(
        (MODEL_DIR / filename).is_file()
        for filename in (
            "vibeasr-vae-encoder-i8_s.gguf",
            "vibeasr-lm-i2_s-embed-q6_k.gguf",
        )
    )
    return JSONResponse(
        {"status": "ready" if ready else "loading"},
        status_code=200 if ready else 503,
    )


@app.post("/transcribe")
async def transcribe(request: Request, file: UploadFile = File(...)) -> dict[str, str]:
    if not API_KEY:
        raise HTTPException(
            status_code=503,
            detail="Transcription service authentication is not configured",
        )
    supplied = request.headers.get("authorization", "")
    if not secrets.compare_digest(supplied, f"Bearer {API_KEY}"):
        raise HTTPException(status_code=401, detail="Invalid transcription service key")

    audio = await file.read(MAX_AUDIO_BYTES + 1)
    if not audio:
        raise HTTPException(status_code=400, detail="Audio recording is empty")
    if len(audio) > MAX_AUDIO_BYTES:
        raise HTTPException(status_code=413, detail="Audio recording is too large")
    if not audio.startswith(b"RIFF") or audio[8:12] != b"WAVE":
        raise HTTPException(status_code=415, detail="Expected a WAV recording")
    binary = Path(ASR_BINARY)
    vae_model = MODEL_DIR / "vibeasr-vae-encoder-i8_s.gguf"
    lm_model = MODEL_DIR / "vibeasr-lm-i2_s-embed-q6_k.gguf"
    if not binary.is_file() or not vae_model.is_file() or not lm_model.is_file():
        raise HTTPException(status_code=503, detail="VibeVoice model is still loading")

    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as recording:
        recording.write(audio)
        audio_path = Path(recording.name)
    try:
        async with _inference_lock:
            result = await asyncio.to_thread(
                subprocess.run,
                [
                    str(binary),
                    "--vae-model",
                    str(vae_model),
                    "--lm-model",
                    str(lm_model),
                    "--audio",
                    str(audio_path),
                    "-t",
                    str(THREADS),
                    "--greedy",
                    "--max-tokens",
                    "512",
                ],
                capture_output=True,
                text=True,
                check=False,
                timeout=180,
            )
        if result.returncode != 0:
            raise HTTPException(status_code=502, detail="VibeVoice could not transcribe this recording")
        transcript = result.stdout.strip()
        if not transcript:
            raise HTTPException(status_code=422, detail="No speech was recognized")
        return {"text": transcript[:8000]}
    except subprocess.TimeoutExpired as error:
        raise HTTPException(status_code=504, detail="VibeVoice transcription timed out") from error
    finally:
        audio_path.unlink(missing_ok=True)
