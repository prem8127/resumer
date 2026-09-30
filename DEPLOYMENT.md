# Resumer beta deployment

This deploys the Flutter web app to Vercel and the FastAPI service to Render.
Supabase remains the auth/database/storage provider. The Render API keeps Groq,
RapidAPI JSearch, and Supabase service-role credentials off the public client.

## 1. Deploy the API to Render

Push this project to a Git provider, then in Render choose **New → Blueprint**
and select the repository. Render reads the root `render.yaml` and creates the
`resumer-api` web service. Add these values in the service's Environment page;
never commit them or put them in the Flutter build:

- `SUPABASE_PUBLISHABLE_KEY`: the project's public Supabase key.
- `SUPABASE_SERVICE_ROLE_KEY`: the server-only service-role/secret key.
- `GROQ_API_KEY`: the server-side Groq key.
- `RAPIDAPI_KEY`: a newly generated RapidAPI key for JSearch. Revoke the old
  key because the previous app source bundled it in the client.

After the first deployment, open `https://YOUR-API.onrender.com/health`. It
should return `"status":"ok"`. Copy the exact Vercel production origin and set
`RESUMER_CORS_ORIGINS` on Render to that origin (for example,
`https://resumer-example.vercel.app`, without a trailing slash), then redeploy.

## 2. Build and deploy Flutter web to Vercel

Build from the repository root after the API is live:

```powershell
flutter build web --release `
  --dart-define=RESUMER_API_BASE_URL=https://YOUR-API.onrender.com `
  --dart-define=SUPABASE_URL=https://qlxijqnudiphqlbujbuj.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
```

Install the Vercel CLI and authenticate once, then deploy the built static
Flutter site:

```powershell
npm install --global vercel
vercel login
vercel deploy build/web --prod
```

Flutter embeds `--dart-define` values into browser assets. Only use public
configuration there: the Supabase URL and publishable key. Never put service
role, Groq, or RapidAPI secrets in a `--dart-define`.

## 3. Allow the production sign-in URL

In Supabase **Authentication → URL Configuration**, set **Site URL** to the
Vercel production origin and add that exact origin to **Redirect URLs**. For
Vercel preview deployments, add the matching Vercel wildcard redirect pattern
from the Supabase redirect URL guide. Google OAuth's authorized redirect URI
remains the Supabase callback URL shown in the Supabase Google provider page.

## 4. Share a beta link

Open the production Vercel URL on a phone using mobile data or another Wi-Fi
network. Test Google sign-in, profile/data loading, resume workflows, jobs,
influencer/course pages, and AI requests. Free backend plans may sleep between
requests, so the first API request can take longer while the service wakes.

For repeat deployments, build the web app again with the same API URL and run
the Vercel deploy command again. Render redeploys when the selected Git branch
changes.
