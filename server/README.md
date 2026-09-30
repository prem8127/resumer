# Resumer backend

The FastAPI service provides resume parsing, enrichment, tailoring, and interview
analysis. Groq credentials remain server-side. Job discovery is handled by
the Flutter `JobSearchService`, which delegates to JSearch only; this API does
not provide a job-feed endpoint.

Configure `GROQ_API_KEY`, the Supabase URL, and server-only
`SUPABASE_SERVICE_ROLE_KEY` before deployment. Supabase access tokens are
validated against Supabase Auth. Final-test grading and certificate issuance
use the service-role key; normal app operations use Postgres row-level security
and Storage policies from `supabase/migrations`.

Never put the service-role key or Groq key in Flutter, a Dart define, or
source control. See `SUPABASE_SETUP.md` for provider and deployment steps.
