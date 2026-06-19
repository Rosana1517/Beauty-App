# Supabase Edge Functions

目前已補入 4 個 function 骨架：

- `resource-import`
- `resource-reparse`
- `resource-recommendation`
- `resource-media-cleanup`

## 目的

- `resource-import`
  - 後端優先解析匯入連結，回傳標準 `ResourceImportDraft`
- `resource-reparse`
  - 建立重新解析 queue job
- `resource-recommendation`
  - 依 resource item 產生 analysis / recommendation，並回寫資料表
- `resource-media-cleanup`
  - 建立 cleanup job 並清掉非 `explicitKeep` 的暫存媒體路徑

## 需要的環境變數

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

## 建議部署順序

1. `supabase login`
2. `supabase link --project-ref iajbkfbpoaswitawdlpm`
3. `supabase functions deploy resource-import`
4. `supabase functions deploy resource-reparse`
5. `supabase functions deploy resource-recommendation`
6. `supabase functions deploy resource-media-cleanup`

## 目前限制

- `resource-import`
  - 以公開 HTML / metadata 為主，尚未接小紅書或 Instagram 正式授權 token 流程
- `resource-recommendation`
  - 目前仍是 edge rule engine，不是正式 AI provider
- `resource-media-cleanup`
  - 目前更新資料表欄位與 lease 狀態，不含 object storage 實體檔清除
- 全部 functions
  - 尚待真實 Supabase 專案部署與 smoke test 驗證
