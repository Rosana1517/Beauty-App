# 資源匯入後端管線

## 目標流程

`ResourceImportDraft -> AI analysis -> recommendation -> Supabase sync -> backend reparse`

## iOS 端已完成

- 本地匯入後會先產生 `ResourceImportDraft`
- 本地規則引擎會補 `AIAnalysisResult` 與 `ResourceRecommendationCard`
- 保存後會建立 `resourceSyncQueue`
- 若已配置 `SUPABASE_URL` 與 `SUPABASE_ANON_KEY`，會自動嘗試：
  - upsert `resource_items`
  - insert `resource_import_events`
  - invoke `resource_recommendation`
  - invoke `resource_reparse`

## Supabase 表

- `resource_items`
- `resource_import_events`
- `resource_analysis_results`
- `resource_recommendations`
- `resource_sync_queue`

schema 檔案：`supabase_resource_schema.sql`

## 建議 Edge Function

- `resource-import`
  - 用途：官方授權型平台內容抓取
  - 輸入：`source`, `url`
  - 輸出：`ResourceImportDraft`
- `resource-reparse`
  - 用途：後端重新解析、小紅書/Instagram 受限欄位補抓
  - 輸入：`resourceID`, `reason`
  - 輸出：queue job 狀態
- `resource-media-cleanup`
  - 用途：清理 `metadataOnly` 與過期 `temporaryCache` 媒體檔
  - 輸入：`resourceID`, `retentionPolicy`
  - 輸出：queue job 狀態
- `resource-recommendation`
  - 用途：根據已入庫內容產生正式 AI 推薦
  - 輸入：`resourceID`
  - 輸出：`[ResourceRecommendationCard]`

## 官方 API 邊界

- `Instagram`
  - iOS 端只保留 OAuth authorize URL 與後端觸發點
  - app secret、token exchange、Graph API 呼叫應放在後端
- `小紅書`
  - iOS 端只保留官方授權流程入口與 function 觸發
  - 真正內容抓取、重新解析、token 保存應放在後端

## 建議後端下一步

1. 部署 `supabase_resource_schema.sql`
2. 建立三個 Edge Functions
3. 將 OAuth callback 導回後端，不在 iOS client 存 secret
4. 先打通 `resource-import` 回傳 `ResourceImportDraft`
5. 再補 `resource-analysis-results` 與 `resource-recommendations` 的正式回寫
