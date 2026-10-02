---
title: Resumer VibeVoice ASR
emoji: 🎙️
colorFrom: blue
colorTo: indigo
sdk: gradio
sdk_version: 6.29.0
python_version: 3.12
app_file: app.py
startup_duration_timeout: 1h
models:
  - microsoft/VibeVoice-ASR-BitNet
---

# Resumer VibeVoice transcription service

This Space provides Microsoft's VibeVoice ASR through a Gradio endpoint for
Resumer interview transcription. The app compiles the CPU inference binary and
downloads the model at startup. A no-op marker satisfies ZeroGPU's startup check;
the transcription function itself runs on CPU without requesting a GPU, so voice
transcription does not consume the account's free GPU quota. The Space may sleep
when idle, and its temporary disk is cleared on restart.

## Space settings

- Keep the Space on **ZeroGPU** hardware. Do not decorate the transcription
  function with `@spaces.GPU`; only the unused startup marker is decorated.
- Add a Space secret named `VIBEVOICE_ASR_API_KEY`. Use a newly generated secret;
  never commit it to this repository.

## Connect the Resumer API

Set these secrets on the existing Resumer API service:

- `VIBEVOICE_ASR_URL=https://ps783286-resmuer.hf.space`
- `VIBEVOICE_ASR_API_KEY=<the same newly generated secret>`

Restart the API service after setting the secrets. Keep both secrets out of
Git and client-side Flutter configuration.
