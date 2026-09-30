# Backend Migration Audit

## Existing-Code Classification

| Area | Before this change | Action |
| --- | --- | --- |
| Google sign-in | PARTIAL | Replaced Firebase Auth with Supabase Google OAuth, persisted sessions, and logout. |
| Cloud data and uploads | PARTIAL | Replaced the Flutter Firestore/Storage repository with Supabase and added SQL schema/RLS/storage policies. |
| Roles | PARTIAL | Added database roles and server-guarded role changes; first super-admin still needs manual bootstrap. |
| Admin and creator tools | PARTIAL | Rewired existing UI to Supabase queries and mutations; retains the existing screens. |
| Influencers/content | PARTIAL | Firestore-backed paths now use Supabase rows and review status; existing bundled starter catalogs remain available for import. |
| Courses/tests/progress | PARTIAL | Added relational course/test/progress schema and server-side grading; nested course lesson data remains compatible in the course JSON. |
| Gemini learning | EXISTING | Kept the Python Gemini proxy and switched its session verification to Supabase. |
| Resume/interview/job workflows | EXISTING | Left existing application workflows and JSearch service in place. |

## Implemented

- Supabase Flutter initialization using the supplied project URL and public
  publishable key. No database password, service-role secret, OAuth client
  secret, or Gemini key is embedded in the app.
- Google OAuth session persistence, auth-state synchronization, logout, and
  Android deep-link callback configuration.
- Supabase-backed profiles, user state, resumes, applications, career items,
  influencer/content/course records, enrollment progress, uploads, and admin
  operations.
- PostgreSQL migration for roles, course modules/lessons/tests, private answer
  keys, attempts, certificates, RLS, and public/private Storage buckets.
- Supabase token verification in FastAPI; Gemini remains server-side; final
  test grading and certificate issuance use a server-only service-role key.
- Supabase provider/setup instructions and safe environment placeholders.

## Not Yet Verified or Complete

- The database migration has not been deployed because no local Supabase CLI
  login or database password was provided. RLS/Storage policies therefore have
  not been tested against the live project.
- Live Google OAuth has not been tested. Configure Google credentials and
  redirect URLs in Supabase first.
- `SUPABASE_SERVICE_ROLE_KEY` and `GEMINI_API_KEY` must be set in the ignored
  `server/.env` or production secret manager before final-test grading and AI
  questions work.
- Existing Firebase cloud records have not been imported; this change points
  the app at Supabase but does not run a one-time Firebase export/import.
- The relational modules/lessons tables are present, while existing course
  models still store lesson lists in course JSON for backward-compatible UI.
- Flutter analysis has no compile errors; remaining diagnostics are style/info
  lints. See `SUPABASE_SETUP.md` for required manual setup.
