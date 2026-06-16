# 真實資料接入說明

## 目前支援

- `YouTube`
  - 有設定 `YOUTUBE_API_KEY` 時，iOS 端會優先使用 YouTube Data API v3 抓正式 metadata。
  - 若未設定 API key，則回退為公開頁面 HTML metadata 解析。
- `小紅書`
  - 目前以公開頁面 HTML、Open Graph、JSON-LD、script 片段解析為主。
  - 這不是官方穩定內容 API，欄位完整度會受頁面結構與反爬限制影響。
- `Supabase`
  - 已提供正式 schema：`supabase_resource_schema.sql`
  - 尚未接入實際網路寫入，這一輪先把 schema 與環境變數對齊。

## iOS 執行期環境變數

- `YOUTUBE_API_KEY`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

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

## 目前邊界

- 小紅書沒有在本專案中接入官方授權內容 API。
- Instagram 仍以公開頁面解析為主。
- Supabase schema 已定義，但尚未做真正的 CRUD / sync client。
