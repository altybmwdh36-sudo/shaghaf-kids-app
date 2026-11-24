# Shaghaf admin backend setup

This branch now contains the first Supabase-backed administration console and SQL schema.

## Required owner setup
1. Create a Supabase project owned by the Shaghaf operator.
2. Run `supabase/schema.sql` in the Supabase SQL editor.
3. Create the first administrator through Supabase Auth (email/password), then insert that user's UUID into `public.profiles` with role `admin` as shown at the end of the SQL file.
4. In GitHub open **Settings → Secrets and variables → Actions**, then create repository secrets named `SUPABASE_URL` and `SUPABASE_ANON_KEY` using the project's URL and public anon/publishable key. The workflow passes these values to the APK build automatically.
5. For a local build use: `flutter build apk --release --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`

Only the public anon key belongs in the app. Never add the Supabase service_role key or admin password to the APK or repository.

## Current implementation boundary
- Admin sign-in checks the authenticated user's database role; the role check is enforced again by PostgreSQL RLS.
- Admin dashboard reads subscriber/video/comment totals.
- Admin can upload a video file to Storage or register a trusted video URL, and set draft/pending/published status.
- Admin can approve or reject comments.
- Existing subscriber sign-up in the app is still device-local. Central subscriber registration, unique phone handling, daily/weekly/monthly metrics, user comments/likes/views, and the member video feed require the next integration step and a protected server-side signup endpoint. Do not treat local signups as central totals.
- The public app video list is still the current static list until the feed is switched to read published rows from `videos`.

The database schema uses row-level security. Review policies and applicable child privacy/consent obligations before production launch.
