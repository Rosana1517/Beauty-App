# Beauty Diary MVP Gap Tracker

## Summary

This document turns the current prototype gaps into an execution list. Priority is ordered by what most directly blocks a real MVP launch.

## P0: Must Have Before MVP

### 1. Supabase Auth + cloud sync
- Status: in progress
- Why it matters:
  - The app currently works mainly as a local prototype.
  - Real MVP usage needs account identity, per-user isolation, and cross-device continuity.
- Scope:
  - Persist Supabase session locally.
  - Support email/password sign-in and email magic link request.
  - Use authenticated session user ID as the default sync identity.
  - Sync local pending resources to Supabase and pull remote resources back down.
- Files / modules:
  - `iOS_Project/美麗日記/Services/SupabaseAuthService.swift`
  - `iOS_Project/美麗日記/Services/BeautyDiaryStore.swift`
  - `iOS_Project/美麗日記/Services/ResourcePipelineServices.swift`
  - `iOS_Project/美麗日記/Constants/AppConstants.swift`
  - `iOS_Project/美麗日記/Views/AppPrototypeViews.swift`
- Remaining work after this round:
  - OAuth callback completion flow
  - refresh token retry policy
  - row-level security verification
  - conflict resolution and remote profile sync

### 2. Backend import / recommendation functions
- Status: scaffolded on client, not production-ready
- Why it matters:
  - Resource import needs backend execution for protected APIs, cookies, retries, and queue workers.
- Scope:
  - `resource-import`
  - `resource-reparse`
  - `resource-recommendation`
  - `resource-media-cleanup`
- Files / modules:
  - `iOS_Project/BACKEND_RESOURCE_PIPELINE.md`
  - `iOS_Project/supabase_resource_schema.sql`
  - `iOS_Project/美麗日記/Services/ResourcePipelineServices.swift`

### 3. Real platform import capability
- Status: partial
- Why it matters:
  - YouTube has partial official metadata support.
  - Xiaohongshu and Instagram still rely mainly on fallback parsing or auth-entry scaffolding.
- Scope:
  - Xiaohongshu official auth import
  - Instagram Graph API import
  - retry / reparse when metadata is incomplete
- Files / modules:
  - `iOS_Project/美麗日記/Services/ResourceImportService.swift`
  - `iOS_Project/REAL_DATA_SETUP.md`
  - `iOS_Project/美麗日記/Services/ResourcePipelineServices.swift`

### 4. Real AI analysis and recommendations
- Status: local rule engine only
- Why it matters:
  - Current recommendation quality is good for prototype demos, not for production usefulness.
- Scope:
  - server-side analysis job
  - persisted analysis results
  - recommendation regeneration
- Files / modules:
  - `iOS_Project/美麗日記/Services/ResourcePipelineServices.swift`
  - `iOS_Project/美麗日記/Models/DiaryModels.swift`
  - `iOS_Project/supabase_resource_schema.sql`

## P1: Strongly Recommended For MVP

### 5. Notification and habit scheduling
- Current state:
  - UI and stored notification time exist, but no actual notification scheduling.
- Files / modules:
  - `iOS_Project/美麗日記/Models/DiaryModels.swift`
  - `iOS_Project/美麗日記/Views/AppPrototypeViews.swift`

### 6. Data management UX
- Current state:
  - Add flows exist for many modules, but edit/delete/recover/search/sort are incomplete.
- Files / modules:
  - `iOS_Project/美麗日記/Services/BeautyDiaryStore.swift`
  - `iOS_Project/美麗日記/Views/AppPrototypeViews.swift`

### 7. Export and reporting
- Current state:
  - JSON/PDF export is a stub.
- Files / modules:
  - `iOS_Project/美麗日記/Services/BeautyDiaryStore.swift`
  - `iOS_Project/美麗日記/Views/AppPrototypeViews.swift`

## P2: Post-MVP

### 8. Advanced media retention policies
- Current state:
  - Models and queue contracts exist, but worker-side cleanup/storage behavior is still planned.
- Files / modules:
  - `iOS_Project/美麗日記/Services/ResourceImportService.swift`
  - `iOS_Project/美麗日記/Services/ResourcePipelineServices.swift`
  - `iOS_Project/supabase_resource_schema.sql`

### 9. Recommendation personalization
- Current state:
  - The app stores user focus areas but does not deeply personalize recommendations yet.
- Files / modules:
  - `iOS_Project/美麗日記/Models/DiaryModels.swift`
  - `iOS_Project/美麗日記/Services/BeautyDiaryStore.swift`

## This Round

Implemented now:
- session persistence for Supabase auth
- email/password sign-in
- email magic link request
- sign-out flow
- store-level auth status management
- authenticated sync identity fallback using signed-in user ID
- settings UI entry for auth and manual sync

Still not finished in this round:
- auth callback handling after magic link open
- remote user profile table sync
- RLS policy verification
- automatic retry / refresh on expired token during sync
