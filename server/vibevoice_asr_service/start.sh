#!/bin/sh
set -eu

if [ ! -s /models/vibeasr/vibeasr-vae-encoder-i8_s.gguf ] || \
   [ ! -s /models/vibeasr/vibeasr-lm-i2_s-embed-q6_k.gguf ]; then
  python -c 'from huggingface_hub import snapshot_download; snapshot_download(repo_id="microsoft/VibeVoice-ASR-BitNet", local_dir="/models/vibeasr", allow_patterns=["*.gguf"])'
fi
exec uvicorn app:app --host 0.0.0.0 --port "${PORT:-7860}"
