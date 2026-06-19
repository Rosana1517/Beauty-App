# 真實資料接入說明

## 目前支援

- `YouTube`
  - 有設定 `YOUTUBE_API_KEY` 時，iOS 端會優先使用 YouTube Data API v3 抓正式 metadata。
  - 若未設定 API key，則回退為公開頁面 HTML metadata 解析。
- `小紅書`
  - iOS 端仍保留公開頁面 HTML、Open Graph、JSON-LD、script 片段解析作為 fallback。
  - 已新增「官方授權型內容 API」入口骨架，但實際 token 交換、正式內容抓取、重新解析必須走後端 / Supabase Edge Function。
- `Supabase`
  - 已提供正式 schema：`supabase_resource_schema.sql`
  - iOS 端已補上 REST CRUD / function invoke / sync queue client 骨架，可推送 `resource_items`、寫入 `resource_import_events`、呼叫重解析與推薦 function。
  - schema 已補入 `app_users` 完整 profile 欄位、authenticated grants、RLS policy 與 owner-based sync 規則。
- `Instagram`
  - 已補上 OAuth 授權入口 URL 產生邏輯。
  - 實際 Graph API token 交換與 media 解析必須由後端代理，不在 iOS client 內保存 app secret。

## iOS 執行期環境變數

- `YOUTUBE_API_KEY`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `RESOURCE_SYNC_USER_ID`
- `SUPABASE_RESOURCE_IMPORT_FUNCTION`
- `SUPABASE_RESOURCE_REPARSE_FUNCTION`
- `SUPABASE_RESOURCE_RECOMMENDATION_FUNCTION`
- `SUPABASE_RESOURCE_MEDIA_CLEANUP_FUNCTION`
- `INSTAGRAM_APP_ID`
- `INSTAGRAM_REDIRECT_URI`
- `XIAOHONGSHU_CLIENT_ID`
- `XIAOHONGSHU_REDIRECT_URI`

## 建議測試方式

1. 在 Xcode Scheme 的 `Run > Arguments > Environment Variables` 加入上述變數。
2. 先驗證 YouTube 連結：
   - `https://www.youtube.com/watch?v=...`
   - `https://youtu.be/...`
   - `https://www.youtube.com/shorts/...`
3. 再驗證小紅書公開連結：
   - `https://www.xiaohongshu.com/explore/...`
   - `https://xhslink.com/...`
4. 觀察 `資源庫 > 真實資料狀態`：
   - `YouTube API` 顯示正式 metadata 代表已走官方 API
   - `Supabase` 顯示已配置代表 runtime 已讀到環境變數
5. 驗證同步與後端分析：
   - 匯入成功後應建立本地 `resourceSyncQueue`
   - 若 `SUPABASE_*FUNCTION` 已配置，client 會自動嘗試同步並請求後端推薦
   - 登入成功後 `app_users` 會先 upsert；若本地仍是 seed profile，會優先採用遠端 profile 回填

## 目前邊界

- 小紅書官方 API 的實際 endpoint / scope / token 流程未在本 repo 內硬編碼，避免把未驗證能力誤寫進 client。
- Instagram 官方文件需要開發者登入後查看完整細節；本專案目前只先保留 OAuth URL 與後端代理架構。
- Supabase client 採 REST / Edge Function 方式，若後續要改成 `supabase-swift` SDK，可在同一層 service 直接替換。
