# ARCH — 架構決策文檔

> 本文件由 AI 從既有代碼結構、`project.yml`、`AppConstants.swift`、`supabase_resource_schema.sql`、`BACKEND_RESOURCE_PIPELINE.md` 反推整理。

## 1. 積木清單(本專案已使用)

### 入口層
- [x] 展示積木:iOS 原生 App(SwiftUI)
- [ ] 排程積木:本地通知排程(`NotificationScheduler.swift`)已接,但驗證與 UX 尚未完成

### 守門+調度層
- [x] 身份積木:Supabase Auth(Email/密碼、Magic Link)
- [x] 邏輯積木:客戶端 `BeautyDiaryStore` + 伺服器端 Edge Function 規則引擎並存

### 工具箱層
- [x] 連線積木:呼叫 Supabase REST/Edge Function、YouTube/Instagram/小紅書 metadata 端點
- [x] 爬蟲積木:一般網頁 Open Graph/JSON-LD 解析;小紅書/YouTube/Instagram 來源偵測與解析
- [x] AI 積木:伺服器端規則引擎生成保養建議/推薦(尚未接外部 AI 供應商)
- [x] 通知積木:本地推播通知排程
- [x] 記憶積木:本地 JSON 持久化 + Supabase Postgres(10 張表,詳見 `supabase_resource_schema.sql`)
- [x] 檔案積木:資源媒體資產(`resource_media_assets`)、暫存租約(`temporary_media_leases`)

### 地基層
- [x] 版本控制積木:Git,遠端 `github.com/Rosana1517/Beauty-App`
- [x] 部署積木:GitHub Actions(`ios-xcodegen-build.yml`、`build-ios-release.yml`)+ Codemagic 雲端編譯(Windows 開發環境無法本機跑 Xcode)

## 2. 形態與邊界

- **形態**:iOS App(SwiftUI)+ Supabase 後端(Postgres + Edge Functions)
- **運行位置**:客戶端本機執行,後端資料/邏輯在 Supabase 雲端
- **定位**:MVP 階段(依 `MVP_GAP_TRACKER.md`,多數 P0 項目為 partial/in progress)

## 3. 邊界問題答案

- **用戶範圍**:目前為使用者自用階段,未來考慮正式上線;架構與安全底線需按「未來要上線」的標準來做(不能因為現在自用就放寬鑒權、RLS、金鑰管理等規範)
- **數據歸屬**:個人保養/體態/資源資料,存於使用者自己的 Supabase 專案,依 `app_users` 做 per-user 隔離(RLS 已部署驗證)
- **認證權限**:Supabase Auth,登入後以 session user id 作為同步身分;未登入時僅本地使用
- **支付**:目前無(舊版 `database_design.md` 曾規劃 `purchase_records`,但真實 schema 未採用)
- **隱私合規**:[待確認 —— 尚未見 GDPR/隱私政策相關文件]
- **性能上限**:[待確認]
- **成本上限**:[待確認 —— Supabase 專案費用、AI API 費用上限]
- **安全底線**:第三方平台(Instagram/小紅書)API secret 一律不放 iOS 端,經 Edge Function 代理(`BACKEND_RESOURCE_PIPELINE.md` 已明確此邊界)
- **可用性**:[待確認]
- **第三方依賴**:Supabase(Auth/DB/Storage/Edge Functions)、YouTube Data API、Instagram Graph API(規劃中)、小紅書(公開 metadata 解析為主)
- **上線平台**:iOS(`deploymentTarget: 16.0`),bundle id `com.rosana1517.beautifuldiary`
- **維護方式**:[待確認]

## 4. 技術棧(鎖定)

| 層 | 選型 | 理由 |
|---|---|---|
| 前端 | SwiftUI, iOS 16+ | 原生 App,`project.yml` 已鎖定 |
| 後端 | Supabase Edge Functions (TypeScript/Deno) | 現有 6 個 function 已部署 |
| 資料庫 | Supabase Postgres + RLS | 已部署並驗證於真實專案 |
| 部署 | GitHub Actions + Codemagic(macOS 雲端編譯) | Windows 開發環境限制 |

## 5. 目錄結構和分層邏輯

```
publish_ios_repo/                      ← 專案根目錄(此為唯一真專案)
├── PRD.md / ARCH.md / project_state.md
├── codemagic.yaml
├── .github/workflows/                 ← CI
├── scripts/                           ← 匯入/匯出輔助 Python 腳本(部分未追蹤,待整理)
├── supabase/
│   ├── config.toml
│   └── functions/                     ← 6 個 Edge Function + _shared
└── iOS_Project/
    ├── project.yml                    ← XcodeGen 專案描述
    ├── supabase_resource_schema.sql   ← 真實資料庫 schema
    ├── *.md                           ← 現況/驗收/建置文檔(共 10+ 份,待逐步收斂進本三份文檔)
    ├── 美麗日記/
    │   ├── Constants/                 ← AppTheme、AppRuntimeConfiguration(env 讀取)
    │   ├── Models/
    │   │   ├── DiaryModels.swift             ← 核心(BeautyDiaryState 根狀態),430 行
    │   │   ├── DiaryModels+Routes.swift       ← 127 行(分頁/路由 enum)
    │   │   ├── DiaryModels+Resource.swift     ← ⚠️ 645 行,待再拆(資源匯入/XHS 模型)
    │   │   ├── DiaryModels+Profile.swift      ← 102 行
    │   │   ├── DiaryModels+Beauty.swift       ← 89 行
    │   │   ├── DiaryModels+Finance.swift      ← 49 行
    │   │   ├── DiaryModels+Growth.swift       ← 66 行
    │   │   └── DiaryModels+Body.swift         ← 170 行
    │   ├── Services/
    │   │   ├── BeautyDiaryStore.swift              ← 核心(屬性/init/存檔),220 行
    │   │   ├── BeautyDiaryStore+Home.swift          ← extension,29 行
    │   │   ├── BeautyDiaryStore+Beauty.swift        ← extension,308 行
    │   │   ├── BeautyDiaryStore+Body.swift          ← extension,221 行
    │   │   ├── BeautyDiaryStore+Growth.swift        ← extension,136 行
    │   │   ├── BeautyDiaryStore+Finance.swift       ← extension,109 行
    │   │   ├── BeautyDiaryStore+AIAdvice.swift      ← extension,328 行
    │   │   ├── BeautyDiaryStore+Resource.swift      ← ⚠️ extension,732 行,待再拆(資源匯入/同步/雲端鑑權)
    │   │   ├── BeautyDiaryStore+Profile.swift       ← extension,99 行
    │   │   ├── ResourcePipelineServices.swift              ← 核心(config/protocols/結果型別),107 行
    │   │   ├── ResourcePipelineServices+OfficialImport.swift  ← 119 行
    │   │   ├── ResourcePipelineServices+LocalAnalysis.swift   ← 156 行
    │   │   ├── ResourcePipelineServices+SupabaseSync.swift    ← ⚠️ 469 行,待再拆
    │   │   ├── ResourcePipelineServices+SupabasePayloads.swift← ⚠️ 529 行,待再拆
    │   │   ├── ResourcePipelineServices+Mappings.swift        ← 153 行
    │   │   ├── ResourceImportService.swift              ← 核心(protocol/Composite/config),74 行
    │   │   ├── ResourceImportService+XHS.swift            ← 288 行
    │   │   ├── ResourceImportService+Instagram.swift      ← 36 行
    │   │   ├── ResourceImportService+YouTube.swift        ← 154 行
    │   │   ├── ResourceImportService+WebPage.swift        ← ⚠️ 524 行,待再拆
    │   │   ├── SupabaseAuthService.swift       ← 600 行
    │   │   ├── FaceShapeDetector.swift
    │   │   ├── NotificationScheduler.swift
    │   │   └── Ads/, AI/, API/
    │   ├── Views/
    │   │   ├── ContentView.swift
    │   │   ├── MainTabView.swift
    │   │   ├── HomeView.swift               ← 首頁(157 行)
    │   │   ├── BeautyViews.swift             ← ⚠️ 1672 行,待再拆(變美分頁)
    │   │   ├── BodyViews.swift               ← ⚠️ 1270 行,待再拆(體態分頁)
    │   │   ├── GrowthViews.swift             ← 853 行(成長分頁)
    │   │   ├── FinanceViews.swift            ← 690 行(財務子導覽)
    │   │   ├── ProfileViews.swift            ← 990 行(我的分頁)
    │   │   ├── SharedViewComponents.swift              ← 核心(GenericSummaryView),29 行
    │   │   ├── SharedViewComponents+AddSheetsBeauty.swift  ← 282 行
    │   │   ├── SharedViewComponents+AddSheetsOther.swift   ← ⚠️ 388 行,待再拆
    │   │   ├── SharedViewComponents+GoalAndEdit.swift      ← 248 行
    │   │   ├── SharedViewComponents+AddSheets2.swift       ← ⚠️ 333 行,待再拆
    │   │   ├── SharedViewComponents+ImportWizardUI.swift   ← 271 行
    │   │   ├── SharedViewComponents+ResourceDetailUI.swift ← 276 行
    │   │   ├── SharedViewComponents+AIAdviceUI.swift       ← ⚠️ 308 行,待再拆
    │   │   ├── SharedViewComponents+CardsAndBadges.swift   ← 297 行
    │   │   └── SharedViewComponents+FormControls.swift     ← 211 行
    │   └── Utilities/
    └── 美麗日記UITests/                ← 5 個 UI 測試檔
```

## 6. 核心模組劃分

| 模組 | 職責 | 邊界 |
|---|---|---|
| Constants | 主題色、環境變數讀取 | 不含業務邏輯 |
| Models | 資料結構定義(本地 + Supabase 對應) | 不含網路/儲存邏輯 |
| Services/Store | 本地持久化、業務規則、雲端同步協調 | 不含 UI |
| Services/API | 呼叫 Supabase / 第三方 API | 不含業務規則 |
| Views | UI 呈現與互動 | 不寫業務邏輯,呼叫 Store/Service |
| supabase/functions | 伺服器端邏輯、金鑰使用處 | client 不可見 |

## 7. 數據模型設計

以 `supabase_resource_schema.sql` 的 10 張表為權威來源(見 PRD.md 第 6 節列表)。本地 JSON 模型(`DiaryModels.swift`)另待拆分整理,不在此文件重複列出全部字段。

## 8. 服務端 vs 客戶端邊界

- 第三方平台(Instagram/小紅書)的 app secret、OAuth token exchange、內容抓取一律在 Supabase Edge Function 執行,iOS 端只保留 authorize URL 與觸發呼叫
- AI 推薦/分析邏輯目前在 Edge Function 執行(規則引擎),為未來接真實外部 AI 預留同一邊界
- RLS 已在真實 Supabase 專案驗證,確保查詢按登入使用者過濾

## 9. 狀態管理方案

`BeautyDiaryStore`(2122 行)為單一本地狀態來源,同時協調 `resourceSyncQueue` 與 Supabase 同步;[待確認]:此檔案拆分後的狀態管理邊界,建議列入下一輪改造切片。

## 10. API 設計

| 端點(Edge Function) | 用途 | 請求 | 回應 |
|---|---|---|---|
| `resource-import` | 官方授權型平台內容抓取 | `source`, `url` | `ResourceImportDraft` |
| `resource-reparse` | 後端重新解析 | `resourceID`, `reason` | queue job 狀態 |
| `resource-recommendation` | 產生 AI 推薦 | `resourceID` | `[ResourceRecommendationCard]` |
| `resource-media-cleanup` | 清理媒體/暫存 | `resourceID`, `retentionPolicy` | queue job 狀態 |
| `ai-advice` | AI 保養/生活建議 | [待確認] | [待確認] |
| `diet-analyze` | 飲食照片分析 | [待確認] | [待確認] |

## 11. 檔案上限規則

- 單一檔案不超過 300 行
- `AppPrototypeViews.swift`(原 8185 行)已按分頁/群組拆為 7 個檔案(見第 5 節),其中 `BeautyViews.swift`(1672)、`BodyViews.swift`(1270)仍超標,待下一輪再拆
- `SharedViewComponents.swift`(原 2589 行)第二輪已拆為主檔 + 9 個檔案(見第 5 節),其中 3 個(`+AddSheetsOther`388、`+AddSheets2`333、`+AIAdviceUI`308)仍略超標,待第三輪再拆
- `BeautyDiaryStore.swift`(原 2122 行)已按 domain 拆為主檔 + 8 個 `extension` 檔案(見第 5 節),其中 `BeautyDiaryStore+Resource.swift`(732)仍超標,待下一輪再拆
- `DiaryModels.swift`(原 1652 行)已按 domain 拆為主檔(BeautyDiaryState 根狀態)+ 7 個檔案(見第 5 節),其中 `DiaryModels+Resource.swift`(645)仍超標,待下一輪再拆
- `ResourcePipelineServices.swift`(原 1521 行)已拆為主檔 + 5 個檔案(見第 5 節),其中 `+SupabaseSync.swift`(469)、`+SupabasePayloads.swift`(529)仍超標,待下一輪再拆
- `ResourceImportService.swift`(原 1057 行)已拆為主檔 + 4 個平台檔案(見第 5 節),其中 `+WebPage.swift`(524)仍超標,待下一輪再拆
- 目前所有原本超過 300 行的巨型檔案都已完成第一輪拆分,剩餘的都是「拆過一次但個別檔案仍超標」的第二輪目標
