# Groq AI setup

Resumer uses Groq's OpenAI-compatible API with `openai/gpt-oss-20b` for resume
tailoring, interview coaching, learning questions, and parser fallback. Requests
run through the Python service; the Groq key stays server-side.

## Local development

Create or edit the ignored `server/.env` file locally. Create a key in the
[Groq Console](https://console.groq.com/keys):

```sh
cd server
notepad .env
```

Set the server-only key:

```dotenv
GROQ_API_KEY=YOUR_GROQ_API_KEY
GROQ_MODEL=openai/gpt-oss-20b
```

Then start the optional API:

```sh
uvicorn resumer_api.main:app --reload --host 0.0.0.0 --port 8000
```

Flutter calls `http://127.0.0.1:8000/v1/tailor` by default. Override the shared
API base URL or only the tailoring URL when necessary:

```sh
flutter run --dart-define=RESUMER_API_BASE_URL=https://your-api.example.com
```

Never pass `GROQ_API_KEY` through `--dart-define`: Dart defines are compiled
into the application and are not a secret store. For deployment, put the key
in the server platform's secret manager and use HTTPS plus Supabase
authentication. Groq's free plan is rate-limited; check the current limits in
the Groq Console.
