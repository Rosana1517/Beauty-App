# Beauty Diary Functional Status Matrix

## Status Legend

- `usable`
  - Works in the current build and can be demonstrated end-to-end.
- `partial`
  - Main flow exists, but important behavior is mocked, fallback-only, or missing production hardening.
- `not ready`
  - UI stub, backend contract only, or missing real implementation.

## App-Level Status

| Area | Status | Notes |
| --- | --- | --- |
| XcodeGen + Xcodebuild CI | `usable` | GitHub Actions macOS build succeeds. |
| iPhone portrait prototype navigation | `usable` | Main tabs and in-app navigation can be entered. |
| Local JSON persistence | `usable` | Local records and UI state persist between launches. |
| Supabase schema + RLS deployment | `usable` | Real project schema applied and RLS verified on target Supabase project. |
| Supabase auth session restore | `usable` | Email/password, magic link request, callback completion, sign-out are wired. |
| Supabase cloud sync hardening | `partial` | Unauthorized session restore retry is now wired, but conflict resolution is still incomplete. |

## Feature Status By Module

### Home

| Feature | Status | Notes |
| --- | --- | --- |
| Checklist display | `usable` | Home checklist renders and progress is calculated. |
| Checklist toggle | `usable` | Toggle state saves locally. |
| Progress summary | `usable` | Completion ratio updates in UI. |
| Cross-device checklist sync | `partial` | Sync depends on overall resource/profile sync maturity. |

### Beauty

| Feature | Status | Notes |
| --- | --- | --- |
| Skincare routine steps | `usable` | Add/toggle routine steps locally. |
| Product library | `usable` | Add products locally. |
| Skin record tracking | `usable` | Add skin records locally. |
| Punch history | `usable` | Local punch record flow works. |
| AI skincare advice | `partial` | Uses local rule engine, not real AI service. |
| Whitening plan | `partial` | UI/prototype level, not backed by a dedicated rules engine. |
| Beauty appointments | `usable` | Local appointment creation works. |

### Body

| Feature | Status | Notes |
| --- | --- | --- |
| Body metrics | `usable` | Weight/body fat records can be added locally. |
| Meal logging | `usable` | Meal records can be created locally. |
| Workout/shaping sections | `partial` | Information architecture exists, but production behavior is light. |
| Wellness/body album | `partial` | Prototype structure exists, feature depth is limited. |

### Growth

| Feature | Status | Notes |
| --- | --- | --- |
| Book records | `usable` | Add reading records locally. |
| Content notes / reading tracking | `partial` | Core structure exists, but not all screenshot-driven flows are fully deepened. |

### Profile / Settings

| Feature | Status | Notes |
| --- | --- | --- |
| Profile editing | `usable` | Local profile updates save correctly. |
| Profile sync to `app_users` | `usable` | Signed-in flow upserts profile to Supabase. |
| Remote profile adopt-on-restore | `partial` | Only seed-profile adoption is implemented. |
| Export history | `partial` | History entries exist, but export output is still stubbed. |
| Theme / notification preference storage | `usable` | Preferences save locally and profile sync fields exist. |
| Actual notification scheduling | `partial` | Local notification scheduling is wired, but still needs on-device verification and UX polish. |

## Resource Library / Import Pipeline

| Feature | Status | Notes |
| --- | --- | --- |
| Link input import wizard | `usable` | URL entry and draft generation work. |
| Source detection | `usable` | Xiaohongshu / Instagram / YouTube / web detection is implemented. |
| Import preview | `usable` | Parsed draft can be previewed before save. |
| Manual completion fallback | `usable` | Incomplete parse can be manually completed. |
| Save imported resource locally | `usable` | Draft converts into local `ResourceItem`. |
| Queue creation for sync | `usable` | Resource import creates sync queue entries. |
| General webpage metadata parsing | `usable` | Public HTML/Open Graph/JSON-LD path exists. |
| YouTube metadata import | `usable` | Backend-first import path is deployed and verified, though metadata quality still varies by source page. |
| Xiaohongshu parsing | `partial` | Backend-first import path is deployed, but current implementation still relies mainly on public metadata parsing rather than full official-source ingestion. |
| Instagram parsing | `partial` | Backend-first import path is deployed, but production Graph API ingestion is still incomplete. |
| Partial-media selection | `partial` | Data model supports it; real backend media lifecycle is not complete. |
| Backend reparse | `usable` | Reparse function is deployed and verified to enqueue backend jobs. |

## Cloud / Backend / Data

| Feature | Status | Notes |
| --- | --- | --- |
| `app_users` CRUD path | `usable` | Authenticated insert/update path works from client. |
| `resource_items` sync | `usable` | Client push/fetch path exists and targets real Supabase tables. |
| `resource_import_events` write | `usable` | Event rows are created during sync. |
| `resource_analysis_results` storage model | `usable` | Recommendation function was verified to write analysis rows to the real Supabase project. |
| `resource_recommendations` storage model | `usable` | Recommendation function was verified to write recommendation rows to the real Supabase project. |
| `resource_sync_queue` table | `usable` | Table and local queue coordination exist. |
| Edge Functions deployment | `usable` | All four functions are deployed to the real Supabase project and were smoke-tested with authenticated requests. |
| Expired token retry | `partial` | Unauthorized sync paths now attempt session restore and retry once. |
| Cross-device merge conflict resolution | `not ready` | Only simple seed-profile adoption is implemented. |
| `app_users` dependency for resource sync | `usable` | Verified that `resource_items` integration requires a matching `app_users` row; profile sync remains a necessary prerequisite. |

## AI / Recommendation

| Feature | Status | Notes |
| --- | --- | --- |
| Local recommendation cards | `usable` | Demo-ready local recommendations work. |
| Rule-based AI analysis | `usable` | Local rule engine generates analysis summaries/actions. |
| Real server-side AI analysis | `partial` | Edge recommendation function now writes server-side analysis rows, but it still uses a rule engine rather than a true external AI provider. |
| Personalized recommendation engine | `partial` | User focus fields exist, but personalization depth is limited. |

## Media Retention / Cleanup

| Feature | Status | Notes |
| --- | --- | --- |
| Metadata-only retention model | `usable` | Data model and persistence path exist. |
| Temporary cache lease model | `partial` | Contract exists locally and in schema. |
| Automatic backend media cleanup | `partial` | Cleanup function is deployed and verified to update queue / cleanup state, but full object-storage file deletion is still not implemented. |
| Explicit keep policy | `partial` | Mode exists in model, but full storage lifecycle is not complete. |

## What Is Truly Ready Today

- Native iOS prototype build and navigation
- Local diary usage across the major sections
- Resource import demo flow with preview/fallback/local save
- Supabase auth basics
- Supabase schema, RLS, and base profile/resource sync path

## What Is Not Yet Truly Ready

- Production-grade Xiaohongshu / Instagram ingestion
- Production-grade Xiaohongshu / Instagram ingestion depth
- Notification scheduling verification and UX hardening
- Real export output
- Full sync retry/conflict handling
- Full worker-driven media cleanup lifecycle

## Recommended Next Priority

1. Wire real runtime config for the new Supabase project into the iOS app.
2. Run one in-app end-to-end smoke test:
   - sign in
   - create/update profile
   - import one resource
   - verify `app_users`, `resource_items`, `resource_import_events`, `resource_analysis_results`, and `resource_recommendations`
3. Add refresh-token retry and clearer sync error recovery.
4. Finish one real import path first.
   - Recommended: Xiaohongshu backend parse path
