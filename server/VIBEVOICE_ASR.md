# Hosted interview transcription

Interview questions use the existing Resumer interview service. Candidates can
listen to each question, record an answer, review its transcript, and continue
with the existing answer, scoring, and career evidence flow.

The Flutter app sends WAV audio to `POST /v1/interview/transcribe` on the
Resumer API. That API forwards the file to a separately hosted VibeVoice
transcription service and returns `{"text":"recognized words"}`. The upstream
service must accept multipart form data in a field named `file`; the API
forwards an optional bearer token.

Configure the Resumer API service with:

- `VIBEVOICE_ASR_URL`: the upstream service's transcription URL.
- `VIBEVOICE_ASR_API_KEY`: optional bearer token required by that service.
- `VIBEVOICE_ASR_TIMEOUT_SECONDS`: request timeout (defaults to 90 seconds).

The included `vibevoice_asr_service` folder builds the hosted CPU service as a
Docker image. Deploy it on a container host with at least 4 GB RAM and 3 GB of
available disk, set `VIBEVOICE_ASR_API_KEY` on that service, and expose its
`/transcribe` path. Set `VIBEVOICE_ASR_URL` to that full path on the Resumer API
and set the same key as `VIBEVOICE_ASR_API_KEY` there. The first container
startup downloads the 1.58 GB quantized model; keep its model directory on a
persistent volume so restarts do not download it again. The container listens
on the host-provided `PORT` (or 7860 locally) and reports readiness at
`/healthz`.

The transcription route accepts WAV files up to 20 MB and does not store them.
The ASR model is not included in the app bundle or in the supplied source ZIP;
the ZIP contains the VibeVoice source and demo code. The separate CPU service
uses Microsoft's VibeVoice-ASR-BitNet runtime, whose official source and model
are documented at
<https://github.com/microsoft/VibeASR.cpp>.

Without `VIBEVOICE_ASR_URL`, text answers and the existing interview features
continue to work, while voice transcription returns a clear service-unavailable
message. Vercel serves the Flutter web client and does not run the ASR model.
