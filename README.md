# Resumer

Resumer is a Flutter career companion that discovers jobs and internships with
direct HTTPS requests to RapidAPI JSearch, with in-app resume intelligence,
profile vault, and tailored application tracking. No job-search backend is
required.

## Architecture

```
User searches in App
       ↓
JobSearchService (Flutter)
       ↓
JSearchService + SecureApiStorage
       ↓
RapidAPI JSearch (HTTPS)
       ↓
Normalize + Filter + Deduplicate
       ↓
Existing Job Cards / Details
       ↓
Non-sensitive Job Cache (SharedPreferences) + App Feed
```

## Local Setup

### Supabase and Groq

The app uses Supabase Auth, Database, and Storage. The project URL and
publishable key are public client configuration; Groq and the Supabase
service-role key belong only in `server/.env`. Follow
[SUPABASE_SETUP.md](SUPABASE_SETUP.md) to enable Google OAuth, configure
redirect URLs, and deploy the SQL migration. The API uses those server-side
secrets for AI learning and trusted final-test grading.

### Run Flutter

From the repository root:

```sh
flutter pub get
flutter run --dart-define=RAPIDAPI_KEY=<your-regenerated-key>
```

The key is copied to platform secure storage only when `rapidapi_key` is
missing. The host defaults to `jsearch.p.rapidapi.com`; it can be overridden for
testing without changing source:

```sh
flutter run \
  --dart-define=RAPIDAPI_KEY=<your-regenerated-key> \
  --dart-define=RAPIDAPI_HOST=jsearch.p.rapidapi.com
```

Do not commit the real key. A direct-to-RapidAPI mobile integration protects
the stored value at rest, but a determined user can still extract a credential
bundled in a client app; configure conservative RapidAPI quotas and rotate the
key if the app is distributed.

## Tests

```sh
cd server && pytest
cd .. && flutter test
```
