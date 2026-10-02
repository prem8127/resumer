# Hosted interview transcription

Interview questions use the existing Resumer interview service. Candidates can
listen to each question, record an answer, review its transcript, and continue
with the existing answer, scoring, and career evidence flow.

The Flutter app sends WAV audio to `POST /v1/interview/transcribe` on the
Resumer API. The API forwards it to the public Hugging Face Gradio Space using
the server-side `gradio_client` library and returns `{"text":"recognized words"}`.
The Space requires a private service key as its second API input.

Configure the Resumer API service with:

- `VIBEVOICE_ASR_URL`: the Hugging Face Space ID, for example
  `ps783286/resmuer`.
- `VIBEVOICE_ASR_API_KEY`: private key shared by the Space and Resumer API.
- `VIBEVOICE_ASR_TIMEOUT_SECONDS`: request timeout (defaults to 240 seconds).

The included `vibevoice_asr_service` folder supports Docker hosting; its
`space_app.py` wrapper supports Hugging Face's free ZeroGPU Gradio runtime. The
Space compiles Microsoft's CPU runtime and downloads the 1.58 GB quantized model
at startup. A no-op marker meets the ZeroGPU runtime's startup check, while the
transcription function runs on CPU without requesting a GPU. It does not consume
the account's GPU quota. The free Space can still sleep while idle, and its
temporary disk is cleared on restart, so cold starts remain possible.

The transcription route accepts WAV files up to 20 MB and does not store them.
The ASR model is not included in the app bundle or in the supplied source ZIP;
the ZIP contains the VibeVoice source and demo code. The separate CPU service
uses Microsoft's VibeVoice-ASR-BitNet runtime, whose official source and model
are documented at
<https://github.com/microsoft/VibeASR.cpp>.

Without `VIBEVOICE_ASR_URL` or the private key, text answers and the existing
interview features continue to work, while voice transcription returns a clear
service-unavailable message. Vercel serves the Flutter web client and does not
run the ASR model.
