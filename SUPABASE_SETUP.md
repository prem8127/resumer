# Supabase setup

## App authentication

1. In Supabase Authentication → Providers, enable Google and enter the OAuth
   client ID and secret from Google Cloud. Google should use the Supabase
   callback URL shown on that provider page.
2. In Authentication → URL Configuration, add the app's allowed return URLs:
   `http://localhost:*/**`, `http://127.0.0.1:*/**`, and the production app
   origin. For Android, add `io.supabase.resumer://login-callback/`.
3. Keep the project URL and publishable key in app configuration. The
   publishable key is public by design; database access is controlled by RLS.

## Database and storage

The migration at `supabase/migrations/20260930000100_initial_schema.sql`
creates user profiles, roles, resume/application state, creator content,
courses/modules/lessons/tests, enrollment progress, attempts, certificates,
private answer keys, buckets, and access policies. Deploy it using the Supabase
CLI after installing the CLI and signing in locally:

```powershell
supabase login
supabase init
supabase link --project-ref qlxijqnudiphqlbujbuj
supabase db push
```

The Supabase CLI project has been initialized in this workspace. Sign in from
PowerShell and link the project locally (enter the database password only in
the CLI prompt), then deploy:

```powershell
supabase login
supabase link --project-ref qlxijqnudiphqlbujbuj
supabase db push
```

The workspace does not include a database password or CLI session, so the
remote link/deploy still requires your local credentials. Never paste a
database password, service-role key, or CLI access token into chat or source
control.

After the first Google sign-in creates a profile, use the SQL editor as the
project owner to grant the first administrator role, replacing the email:

```sql
update public.profiles
set role = 'superAdmin'
where id = (select id from auth.users where email = 'YOUR_ADMIN_EMAIL');
```

Only a super administrator may grant `admin` or `superAdmin`; app users cannot
change their own role. Content starts as a draft and only an administrator can
approve/reject it or verify an influencer. Public course rows never contain
test answer keys.

## Python service secrets

Set these only in the ignored `server/.env` for local use, or in the hosting
provider's secret manager:

```dotenv
SUPABASE_URL=https://qlxijqnudiphqlbujbuj.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_PUBLISHABLE_KEY
SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVER_ONLY_SERVICE_ROLE_KEY
GROQ_API_KEY=YOUR_SERVER_ONLY_GROQ_KEY
GROQ_MODEL=openai/gpt-oss-20b
```

The service-role key bypasses RLS and must never be sent to Flutter. Run the
FastAPI service once on port 8000; if that port is already occupied, reuse the
running process rather than starting a second copy.

## Remaining setup

- Configure Google OAuth credentials and allowed redirect URLs in Supabase.
- Install/login the Supabase CLI locally and apply the migration.
- Add the service-role key and Groq key to the local/server secret store.
- Promote the first administrator after signing in.
- Configure production API URL and HTTPS hosting.
