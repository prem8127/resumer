---
title: Resumer VibeVoice ASR
emoji: 🎙️
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
startup_duration_timeout: 1h
models:
  - microsoft/VibeVoice-ASR-BitNet
---

# Resumer VibeVoice transcription service

This Space runs the Resumer interview transcription API. It accepts WAV audio
at `POST /transcribe` as multipart field `file`, authenticates with a bearer
secret, and returns `{"text":"..."}`. `/healthz` reports whether the model is
ready.

## Space settings

- Use **CPU Basic** (2 vCPU / 16 GB RAM) for the initial deployment. VibeASR is
  CPU-capable; GPU hardware is not required.
- Add a Space secret named `VIBEVOICE_ASR_API_KEY`. Use a newly generated secret;
  never commit it to this repository.
- The model is downloaded on startup when its files are absent. Space disk is
  ephemeral, so attaching a read-only model volume at `/models/vibeasr` avoids
  downloading the model again after a restart.

## Connect the Resumer API

Set these secrets on the existing Resumer API service:

- `VIBEVOICE_ASR_URL=https://<space-subdomain>.hf.space/transcribe`
- `VIBEVOICE_ASR_API_KEY=<the same newly generated secret>`

Restart the API service after setting the secrets. Keep both secrets out of
Git and client-side Flutter configuration.
