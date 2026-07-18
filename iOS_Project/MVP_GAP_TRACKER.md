# Beauty Diary MVP Gap Tracker

## Summary

This document turns the current prototype gaps into an execution list. Priority is ordered by what most directly blocks a real MVP launch.

> **Re-audit 2026-07-18**: 對照當前代碼庫逐條重新核對 P0。原本的狀態描述多半停留在早期原型階段,與現況嚴重不符——P0.1/P0.2/P0.4 實際上已達 MVP 標準,P0.3 的缺口本質是「外部授權/存取」而非「尚未寫代碼」。以下狀態均附代碼佐證。

## P0: Must Have Before MVP

### 1. Supabase Auth + cloud sync
- Status: **✅ done(MVP 標準已達成)**
- Why it matters:
  - The app currently works mainly as a local prototype.
  - Real MVP usage needs account identity, per-user isolation, and cross-device continuity.
- 已完成(代碼佐證):
  - session 本地持久化 + 啟動還原並在過期時自動 refresh:`SupabaseAuthService+EmailAuthCore.swift` `restoreSession()`
  - email/密碼登入、註冊、Magic Link、登出:同檔 `signIn/signUp/requestMagicLink/completeMagicLinkSignIn/signOut`
  - 同步中 access token 過期(REST 回 401)自動 refresh + 重試一次:`BeautyDiaryStore+ResourceWorker.swift` `syncResource(allowSessionRetry:)` → `BeautyDiaryStore+ResourceProfileSync.swift` `recoverSessionIfNeeded(after:)`
  - 短暫網路錯誤單次重試:同檔 `isTransientNetworkError`
  - 資源衝突處理(超越早期 seed-only):`BeautyDiaryStore+ResourceWorker.swift` `merge` + `canOverwriteWithRemote`(僅覆寫伺服器已確認 `.succeeded` 的項目,保護未同步的本地編輯)
  - RLS 已在真實 Supabase 專案部署並驗證(見 ARCH.md 第 3 節)
- 殘留(非 MVP 阻塞,已降級為 P1):
  - 跨裝置**個人資料(profile)**衝突仍是 seed-profile 採納(`shouldAdoptRemoteProfile`),尚未做欄位級合併;資源(resource)層已有正式合併

### 2. Backend import / recommendation functions
- Status: **✅ done(deployed and smoke-tested)**
- Why it matters:
  - Resource import needs backend execution for protected APIs, cookies, retries, and queue workers.
- 已部署函式(supabase/functions/):
  - `resource-import`、`resource-reparse`、`resource-recommendation`、`resource-media-cleanup`
  - 另有 `ai-advice`、`diet-analyze`、`product-lookup`、`video-transcribe`、`exercise-match`(2026-07 新增)
- Files / modules:
  - `iOS_Project/BACKEND_RESOURCE_PIPELINE.md`、`iOS_Project/supabase_resource_schema.sql`
  - `iOS_Project/美麗日記/Services/ResourcePipelineServices.swift`

### 3. Real platform import capability
- Status: **⛔ 外部阻塞(非代碼缺口)**
- Why it matters:
  - YouTube has partial official metadata support.
  - Xiaohongshu and Instagram still rely mainly on fallback parsing or auth-entry scaffolding.
- 現況(代碼佐證):
  - 一般網頁 / Instagram / 小紅書皆走 OpenGraph/JSON-LD fallback 解析(`ResourceImportService+Instagram.swift` / `+XHS.swift` 用 `SharedHTMLParser`);YouTube 有部分官方 metadata
- **為什麼不是寫代碼就能解決(需使用者外部行動)**:
  - **Instagram**:官方 Graph API 需要 Meta 開發者 App + 商家驗證 + App Review 通過特定權限,是數週、由使用者驅動的外部流程;拿到憑證前無法完成正式匯入
  - **小紅書**:無公開 API,且內容在台灣被封鎖(見 auto-memory「xhs-taiwan-blocked」),無法以代碼繞過
- 可在無外部憑證下先做的(若使用者要推進):強化 fallback 解析穩健度、metadata 不全時的 reparse/retry 流程

### 4. Real AI analysis and recommendations
- Status: **✅ done(外部 AI 已連接)**
- Why it matters:
  - Current recommendation quality is good for prototype demos, not for production usefulness.
- 已完成(代碼佐證):
  - `supabase/functions/_shared/aiProvider.ts`:完整 OpenAI / Anthropic 串接,支援使用者自帶金鑰(`user_ai_provider_settings`,RLS 隔離)並 fallback 到環境變數;含 Tavily 即時網頁搜尋、Vision、逐字稿整理
  - 消費此模組的函式:`ai-advice`、`resource-recommendation`(`applyBackendRecommendationsIfNeeded`)、`diet-analyze`、`product-lookup`、`exercise-match`
- 殘留(非阻塞):推薦個人化深度(P2 #9)——目前依需求關鍵字,尚未依使用者歷史深度個人化

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
- automatic retry / refresh on expired token during sync
- cross-device profile conflict resolution beyond seed-profile adoption
- production-grade Xiaohongshu / Instagram ingestion depth
- true external AI provider integration
