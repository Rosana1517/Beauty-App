# Beauty Diary Functional Acceptance Checklist

## How To Use This Checklist

- `Pass`
  - Feature works as expected in the current build.
- `Partial`
  - Main flow works, but result is incomplete, mocked, or not production-safe.
- `Fail`
  - Flow cannot be completed or required behavior is missing.

Record each item with:

- Result: `Pass / Partial / Fail`
- Test date
- Device / build
- Notes

## 1. Build And Launch

### 1.1 CI build
- Expected status: `Pass`
- Validation steps:
  1. Open the latest GitHub Actions run for the current branch.
  2. Confirm `xcodegen` succeeds.
  3. Confirm `xcodebuild` succeeds.
  4. Confirm the simulator `.app` artifact is uploaded.
- Expected result:
  - Workflow is green end-to-end.

### 1.2 App launch
- Expected status: `Pass`
- Validation steps:
  1. Install or launch the simulator build.
  2. Open the app from the iPhone simulator home screen.
  3. Wait for the first screen to render.
- Expected result:
  - App opens without crash and shows the main prototype shell.

## 2. Navigation

### 2.1 Five main tabs
- Expected status: `Pass`
- Validation steps:
  1. Tap `首頁`.
  2. Tap `變美`.
  3. Tap `體態`.
  4. Tap `成長`.
  5. Tap `我的`.
- Expected result:
  - Each tab opens the correct page and bottom tab state updates correctly.

### 2.2 Deep page entry and return
- Expected status: `Pass`
- Validation steps:
  1. Enter one child page under each main tab.
  2. Use back navigation to return.
  3. Repeat on at least two different tabs.
- Expected result:
  - Navigation stack behaves correctly and return path is clear.

## 3. Home

### 3.1 Checklist display and progress
- Expected status: `Pass`
- Validation steps:
  1. Open `首頁`.
  2. Note current checklist count and progress.
  3. Toggle one unchecked checklist item.
- Expected result:
  - Progress text and progress ratio update immediately.

### 3.2 Checklist persistence
- Expected status: `Pass`
- Validation steps:
  1. Toggle one or more checklist items.
  2. Fully close the app.
  3. Relaunch the app.
- Expected result:
  - Toggled checklist state remains saved.

## 4. Beauty

### 4.1 Add skincare routine step
- Expected status: `Pass`
- Validation steps:
  1. Open `變美 > 護膚管理`.
  2. Add one morning step.
  3. Add one evening step.
  4. Toggle one step complete.
- Expected result:
  - New steps appear in the correct section and checked state updates.

### 4.2 Add product
- Expected status: `Pass`
- Validation steps:
  1. Open product management.
  2. Add a product with name, brand, category, and notes.
  3. Return to the list.
- Expected result:
  - Product appears in the local list after save.

### 4.3 Add skin record
- Expected status: `Pass`
- Validation steps:
  1. Open skin tracking.
  2. Add one skin type record with at least one concern.
  3. Save and return.
- Expected result:
  - Record appears in history in newest-first order.

### 4.4 AI skincare advice
- Expected status: `Partial`
- Validation steps:
  1. Open the AI advice section.
  2. Compare advice before and after adding product/skin/routine data.
- Expected result:
  - Advice cards change based on local state.
  - Notes should mention this is rule-based, not real backend AI.

### 4.5 Beauty appointment
- Expected status: `Pass`
- Validation steps:
  1. Open appointment section.
  2. Add one appointment with title, store, date, and note.
  3. Return to the list.
- Expected result:
  - Appointment appears and persists after reopening the app.

## 5. Body

### 5.1 Add body metric
- Expected status: `Pass`
- Validation steps:
  1. Open body metrics.
  2. Add one record with weight and body fat.
  3. Save and reopen the section.
- Expected result:
  - Record appears and remains saved.

### 5.2 Add meal log
- Expected status: `Pass`
- Validation steps:
  1. Open meal tracking.
  2. Add one meal record with type, summary, and note.
  3. Save and reopen the section.
- Expected result:
  - Meal record appears and remains saved.

### 5.3 Body module depth
- Expected status: `Partial`
- Validation steps:
  1. Visit exercise, shaping, wellness, and album-related pages.
  2. Check whether each page has working input and state change flows.
- Expected result:
  - IA and prototype structure exist.
  - Some pages may still be lighter than full production behavior.

## 6. Growth

### 6.1 Add reading record
- Expected status: `Pass`
- Validation steps:
  1. Open reading tracking.
  2. Add one book with title, author, link, and note.
  3. Save and reopen.
- Expected result:
  - Book record appears and persists.

### 6.2 Growth content depth
- Expected status: `Partial`
- Validation steps:
  1. Visit the other growth pages beyond books.
  2. Check whether each screenshot-driven section has full create/view/update depth.
- Expected result:
  - Core structure exists.
  - Some content pages remain prototype-depth only.

## 7. Profile / Settings

### 7.1 Edit profile locally
- Expected status: `Pass`
- Validation steps:
  1. Open `我的`.
  2. Change nickname, signature, body focus, skincare focus, and notification time.
  3. Save and reopen the page.
- Expected result:
  - Updated profile values remain saved locally.

### 7.2 Export stub
- Expected status: `Partial`
- Validation steps:
  1. Trigger JSON export.
  2. Trigger PDF export.
  3. Check export history.
- Expected result:
  - Export history entries are created.
  - Output is still a stub, not final production export.

### 7.3 Notification setting storage
- Expected status: `Pass`
- Validation steps:
  1. Change notification time.
  2. Close and reopen the app.
- Expected result:
  - Preference remains saved.

### 7.4 Real notification scheduling
- Expected status: `Partial`
- Validation steps:
  1. Check whether the app requests notification permission.
  2. Check whether a local notification is actually scheduled.
- Expected result:
  - Current build should request permission and schedule a daily local reminder.
  - Final pass still depends on device/simulator verification of delivered notification behavior.

## 8. Resource Import Pipeline

### 8.1 Source detection by URL
- Expected status: `Pass`
- Validation steps:
  1. Paste one Xiaohongshu URL.
  2. Paste one Instagram URL.
  3. Paste one YouTube URL.
  4. Paste one normal web article URL.
- Expected result:
  - Each URL is classified into the correct `ImportSourceType`.

### 8.2 Draft generation and preview
- Expected status: `Pass`
- Validation steps:
  1. Start import from a supported URL.
  2. Wait for parsing to complete.
  3. Open preview screen.
- Expected result:
  - A `ResourceImportDraft` is created and preview fields render.

### 8.3 Manual completion fallback
- Expected status: `Pass`
- Validation steps:
  1. Use a URL with incomplete metadata.
  2. Confirm the app moves into manual completion.
  3. Fill required fields and continue.
- Expected result:
  - Import flow does not dead-end when metadata is incomplete.

### 8.4 Save imported resource locally
- Expected status: `Pass`
- Validation steps:
  1. Complete one import.
  2. Return to resource library.
  3. Reopen the app.
- Expected result:
  - Imported item appears in the list and persists locally.

### 8.5 Xiaohongshu import quality
- Expected status: `Partial`
- Validation steps:
  1. Test one public Xiaohongshu post URL.
  2. Compare parsed fields: title, author, thumbnail, tags, content type.
  3. Check whether fallback/manual completion is still needed.
- Expected result:
  - Fallback path works.
  - Full official import quality is not yet guaranteed.

### 8.6 Instagram import quality
- Expected status: `Partial`
- Validation steps:
  1. Test one public Instagram Reel or post URL.
  2. Check detected source, preview fields, and fallback behavior.
- Expected result:
  - URL can enter the pipeline.
  - Full official Graph API ingest is not yet complete.

### 8.7 YouTube import quality
- Expected status: `Partial`
- Validation steps:
  1. Provide a YouTube watch URL.
  2. Test once with API config present and once without.
- Expected result:
  - Metadata quality improves when API config exists.
  - Fallback remains available otherwise.

## 9. Supabase Auth

### 9.1 Email/password sign-in
- Expected status: `Pass`
- Validation steps:
  1. Open sync settings in `我的`.
  2. Enter a valid Supabase email/password.
  3. Submit sign-in.
- Expected result:
  - Auth status becomes authenticated.
  - Cloud sync becomes available.

### 9.2 Magic link request
- Expected status: `Pass`
- Validation steps:
  1. Enter a valid email.
  2. Tap magic link request.
- Expected result:
  - App shows that magic link email was sent.

### 9.3 Magic link callback completion
- Expected status: `Pass`
- Validation steps:
  1. Open the magic link on a device or simulator that can route back to the app.
  2. Let the app open via `beautydiary://auth/callback`.
- Expected result:
  - Session is saved locally and auth state becomes authenticated.

### 9.4 Session restore
- Expected status: `Pass`
- Validation steps:
  1. Sign in successfully.
  2. Fully relaunch the app.
- Expected result:
  - Session restores automatically without forcing a new login.

### 9.5 Sign out
- Expected status: `Pass`
- Validation steps:
  1. Tap sign out.
  2. Return to sync settings.
- Expected result:
  - Auth state becomes signed out and cloud-only actions are disabled.

## 10. Supabase Sync

### 10.1 `app_users` upsert
- Expected status: `Pass`
- Validation steps:
  1. Sign in.
  2. Change profile fields.
  3. Trigger sync or wait for automatic profile sync.
  4. Inspect `public.app_users` in Supabase Table Editor.
- Expected result:
  - One row exists for the signed-in user.
  - Profile fields are updated.

### 10.2 Resource sync to `resource_items`
- Expected status: `Pass`
- Validation steps:
  1. Import one resource locally.
  2. Trigger cloud sync.
  3. Inspect `public.resource_items`.
- Expected result:
  - Imported item is written to Supabase with the current user ID.

### 10.3 `resource_import_events` creation
- Expected status: `Pass`
- Validation steps:
  1. Import and sync one resource.
  2. Inspect `public.resource_import_events`.
- Expected result:
  - At least one import event row is created for the resource.

### 10.4 Pull remote resources back down
- Expected status: `Pass`
- Validation steps:
  1. Ensure a synced resource exists in Supabase.
  2. Relaunch the app while signed in.
  3. Trigger manual cloud sync.
- Expected result:
  - Remote resources can be fetched back into local state.

### 10.5 Expired token retry
- Expected status: `Fail`
- Validation steps:
  1. Force a stale or expired session.
  2. Trigger cloud sync.
- Expected result:
  - Current build does not yet have full retry/refresh hardening.

### 10.6 Cross-device merge handling
- Expected status: `Partial`
- Validation steps:
  1. Create different profile/resource changes on two separate app states.
  2. Sync both back to the same Supabase project.
- Expected result:
  - Simple flows may work.
  - Complex conflict resolution is not fully implemented.

## 11. Supabase Database / RLS

### 11.1 Schema deployment
- Expected status: `Pass`
- Validation steps:
  1. Open Supabase SQL Editor.
  2. Run `supabase_resource_schema.sql`.
- Expected result:
  - Schema executes successfully.

### 11.2 Table presence
- Expected status: `Pass`
- Validation steps:
  1. Query for target public tables.
- Expected result:
  - 9 target tables exist:
    - `app_users`
    - `resource_items`
    - `resource_import_events`
    - `resource_analysis_results`
    - `resource_recommendations`
    - `resource_media_assets`
    - `resource_source_payloads`
    - `temporary_media_leases`
    - `resource_sync_queue`

### 11.3 RLS enabled
- Expected status: `Pass`
- Validation steps:
  1. Query `pg_tables` for `rowsecurity`.
- Expected result:
  - All 9 target tables show `rowsecurity = true`.

### 11.4 Policy presence
- Expected status: `Pass`
- Validation steps:
  1. Query `pg_policies` for the target tables.
- Expected result:
  - Owner-based policies exist for the relevant tables.

### 11.5 Real authenticated isolation
- Expected status: `Partial`
- Validation steps:
  1. Sign in as user A and create data.
  2. Sign in as user B and attempt to read user A data through the app.
- Expected result:
  - App-level behavior should isolate data.
  - A full multi-user RLS penetration test is still recommended.

## 12. AI / Recommendation

### 12.1 Local analysis result generation
- Expected status: `Pass`
- Validation steps:
  1. Import one resource.
  2. Inspect generated summary, insights, and actions.
- Expected result:
  - Local rule engine produces analysis output.

### 12.2 Recommendation cards
- Expected status: `Pass`
- Validation steps:
  1. Import multiple different categories of resources.
  2. Compare generated recommendation cards.
- Expected result:
  - Cards are generated and differ by category/source context.

### 12.3 Real backend AI recommendation
- Expected status: `Fail`
- Validation steps:
  1. Check whether server-generated recommendation jobs run from real backend functions.
- Expected result:
  - Not fully implemented yet.

## 13. Export / Reporting

### 13.1 Export entry creation
- Expected status: `Pass`
- Validation steps:
  1. Trigger export.
  2. Inspect export history.
- Expected result:
  - Export history row is added.

### 13.2 Final export deliverable quality
- Expected status: `Fail`
- Validation steps:
  1. Inspect produced JSON/PDF output for production-grade completeness.
- Expected result:
  - Current output is still stub-level.

## 14. Media Retention / Cleanup

### 14.1 Metadata-only retention
- Expected status: `Pass`
- Validation steps:
  1. Import a resource in metadata-only mode.
  2. Inspect stored local/remote item fields.
- Expected result:
  - Metadata persists without requiring full binary media storage.

### 14.2 Temporary cache lease model
- Expected status: `Partial`
- Validation steps:
  1. Inspect saved draft/resource state for temporary lease metadata.
  2. Inspect Supabase schema for `temporary_media_leases`.
- Expected result:
  - Data model exists.
  - Full worker cleanup loop is not active yet.

### 14.3 Automatic media cleanup worker
- Expected status: `Fail`
- Validation steps:
  1. Try to verify end-to-end cleanup by backend worker or function.
- Expected result:
  - Real worker-side cleanup is not yet complete.

## 15. Backend Functions

### 15.1 `resource-import`
- Expected status: `Fail`
- Validation steps:
  1. Trigger an import that depends on deployed Edge Function behavior.
- Expected result:
  - Contract exists, but production deployment/implementation is not complete.

### 15.2 `resource-reparse`
- Expected status: `Fail`
- Validation steps:
  1. Trigger backend reparse from the app.
  2. Confirm actual backend job execution.
- Expected result:
  - Client request path exists, backend function is not fully production-ready.

### 15.3 `resource-recommendation`
- Expected status: `Fail`
- Validation steps:
  1. Trigger server-side recommendation refresh.
  2. Confirm real function output is stored.
- Expected result:
  - Not fully implemented yet.

### 15.4 `resource-media-cleanup`
- Expected status: `Fail`
- Validation steps:
  1. Trigger cleanup flow for temporary media.
  2. Confirm backend cleanup actually removes expired media.
- Expected result:
  - Not fully implemented yet.

## Recommended Acceptance Order

1. Build and launch
2. Main navigation
3. Local create/save flows
4. Resource import local flow
5. Supabase auth
6. Supabase sync
7. Supabase table/RLS verification
8. Real backend functions
9. Platform-specific import quality
10. Export / notification / long-tail polish
