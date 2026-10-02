#!/bin/sh
set -eu

python -c 'from huggingface_hub import snapshot_download; snapshot_download(repo_id="microsoft/VibeVoice-ASR-BitNet", local_dir="/models/vibeasr", allow_patterns=["*.gguf"])'
exec uvicorn app:app --host 0.0.0.0 --port "${PORT:-7860}"
