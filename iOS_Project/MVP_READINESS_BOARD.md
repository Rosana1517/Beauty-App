# 美麗日記 MVP 可用度清單

## 目前已達可用

- `本機日記資料流`
  - 首頁 checklist、護膚步驟、產品、膚質紀錄、預約、體重體脂、飲食、閱讀記錄皆可新增並本機保存。
- `基本資料管理`
  - 產品、膚質紀錄、預約、體重體脂、飲食、書籍、資源卡片已有刪除入口。
- `Supabase 基礎登入 / 同步`
  - email/password、magic link request、callback completion、sign out、profile upsert、resource push/fetch 已串通。
- `資源匯入主流程`
  - 連結輸入、平台判斷、預覽、手動補齊、本地入庫、sync queue 建立可完整走通。
- `rule-based AI`
  - 本地規則分析、摘要、建議卡已可產出，適合 demo 與流程驗證。
- `CI 建置`
  - GitHub Actions macOS runner 可執行 `xcodegen + xcodebuild`。

## 還差最後一哩

- `YouTube / 小紅書 / Instagram 正式匯入`
  - 現在已改成後端 function 優先、client fallback，四個 Supabase Edge Functions 也已部署並 smoke test 完成。
  - 仍需補齊小紅書 / Instagram 的正式官方來源解析深度。
- `遠端 profile 採用`
  - 已有 restore 與 unauth retry。
  - 仍缺完整 conflict merge policy，不同裝置同時修改時尚未完全定義。
- `media retention contract`
  - schema、model、cleanup queue 都已在，cleanup function 也已部署驗證。
  - 仍需補齊 object storage 實體檔刪除與完整 worker lifecycle。
- `通知`
  - iOS 端已有排程器與設定入口。
  - 仍需在真實裝置 / simulator 驗證權限、排程、重複提醒行為。

## 完全未完成

- `正式 AI`
  - 尚未接外部 AI provider；目前僅 rule-based。
- `正式匯出`
  - 仍是匯出紀錄 / stub，尚未產出正式 JSON / PDF 檔案流程。
- `完整 retry / conflict handling`
  - 目前只有 401 restore-and-retry once，尚未完成 queue replay、版本衝突比較、field-level merge。

## 本輪執行順序

1. 完成四個 Supabase Edge Functions 的真實 in-app smoke test。
2. 補齊小紅書 / Instagram 正式解析深度。
3. 導入真正的 AI provider。
4. 完成正式匯出流程。
5. 再補完整 retry / conflict handling。
