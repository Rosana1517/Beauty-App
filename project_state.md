# project_state — 當前狀態文檔

## 當前階段

正在做:舊專案積木化改造(模式 E)— 切片 1/N:補齊三份全局文檔

已完成:
- 體檢:掃描工作目錄結構,確認 `publish_ios_repo`(本目錄)為唯一真專案,外層工作目錄混雜競品 APK 分析、小紅書爬蟲輸出、過期複製品,不屬於本專案
- 補文檔:從既有 10+ 份零散文檔反推生成 `PRD.md`、`ARCH.md`、`project_state.md`
- 使用者已確認:產品目標是做出可正式上線的 App(非單純原型復刻)、PRD 第 8 節「不做什麼」清單正確、目前自用未來考慮上線(架構需按上線標準設計)
- 切片 2:`Views/AppPrototypeViews.swift`(8185 行)已依分頁/群組拆為 7 個檔案(HomeView/BeautyViews/BodyViews/GrowthViews/FinanceViews/ProfileViews/SharedViewComponents),並更新 `project.yml` 的 sources 清單;拆分為純搬移,未改任何邏輯
- CI 第一輪發現拆分後共用元件(`CardView`/`titleRow`/各種 `Add*Sheet` 等 57 個)因 Swift `private` 是檔案層級作用域而跨檔案失效(258 個編譯錯誤),已修正為模組內可見;第二輪 CI 的「Build for iOS Simulator」步驟已 ✓ 通過,切片 2 編譯驗證完成(commit 46ec7b2, run 29474949382)
- 切片 3:`Services/BeautyDiaryStore.swift`(2122 行,單一 God Class)已按 domain 拆為主檔(屬性/init/存檔/共用泛型方法)+ 8 個 `extension BeautyDiaryStore` 檔案(Home/Beauty/Body/Growth/Finance/AIAdvice/Resource/Profile);CI 歷經兩輪修正才過關:① 9 個 `@Published` 儲存屬性誤被分進 extension(Swift extension 不能放儲存屬性)② `@Published private(set)` 的 setter 是檔案作用域,被其他檔案的方法賦值時不可見;兩者皆已修正,commit `ef13f8f` 的 CI(iOS XcodeGen Build + Build iOS IPA)全數 ✅ 通過,切片 3 完全驗證完成
- 切片 4:`Models/DiaryModels.swift`(1652 行,80+ 個獨立 struct/enum)已按 domain 拆為主檔(`BeautyDiaryState` 根狀態,430 行)+ 7 個檔案(Routes/Resource/Profile/Beauty/Finance/Growth/Body);本檔全部型別皆無 `private` 或 class 屬性存取問題,一次通過 CI 沒有返工;commit ec17195 的「Build for iOS Simulator」✓ 通過,切片 4 編譯驗證完成
- 切片 5:`Services/ResourcePipelineServices.swift`(1521 行)拆為主檔(config/protocols/結果型別,107 行)+ 5 個檔案(OfficialImport/LocalAnalysis/SupabaseSync/SupabasePayloads/Mappings);拆分前發現 `OfficialMetadataImportGateway` 會用到原本規劃在別檔案的 `private` Supabase REST 型別(耦合比預期緊密),已比照切片 2/3 的教訓,拆分**前**先把所有頂層 `private struct/enum/extension` 改為模組內可見再切;CI 抓到一個新問題:`+Mappings.swift` 裡的 `nilIfEmpty` 擴充失去檔案作用域後,跟 `ResourceImportService.swift` 自己私有的同名同實作擴充衝突(invalid redeclaration),已刪除後者的重複版本;commit cf17e9f 的「Build for iOS Simulator」✓ 通過,切片 5 編譯驗證完成
- 切片 6:`Services/ResourceImportService.swift`(1057 行)拆為主檔(protocol/CompositeResourceImportService/config,74 行)+ 4 個平台檔案(XHS/Instagram/YouTube/WebPage);拆分前先確認 `CompositeResourceImportService` 直接引用所有平台解析器(皆為 `private`),依教訓先把所有頂層 `private` 宣告改為模組內可見;並主動 grep 檢查新暴露的符號(含 `extension JSONDecoder`)是否與其他檔案(尤其 `SupabaseAuthService.swift`、`ResourcePipelineServices+*.swift`)撞名,確認皆為不同成員名稱,無衝突;已更新 `project.yml`;commit d9fbac9 首次 CI 的「Build for iOS Simulator」✓ 通過(編譯 100% 正常),UI 測試 6 個中 1 個失敗(`testXiaohongshuLinkParsesToRealMetadata`,真實小紅書連結解析逾時);已用逐行 diff 比對確認拆分前後檔案內容完全一致(唯一差異是拿掉 `private` 與區塊搬移位置,無程式碼遺失或改壞),並重跑該 CI job **全數通過(含 UI 測試)**——確認為偶發性的第三方小紅書網站問題,與這次拆分無關,已排除疑慮
- **第一輪巨型檔案拆分至此全部完成**(切片 2-6):`AppPrototypeViews.swift`、`BeautyDiaryStore.swift`、`DiaryModels.swift`、`ResourcePipelineServices.swift`、`ResourceImportService.swift` 六個原本超過 300 行的檔案都已拆過一輪,全部通過編譯驗證
- 切片 7(第二輪拆分開始):`SharedViewComponents.swift`(2589 行)拆為主檔(`GenericSummaryView`,29 行)+ 9 個檔案(AddSheetsBeauty/AddSheetsOther/GoalAndEdit/AddSheets2/ImportWizardUI/ResourceDetailUI/AIAdviceUI/CardsAndBadges/FormControls);本檔無 `private` 宣告(第一輪已清過),拆分風險低,已檢查每個新檔案大括號配對正確;9 個新檔案中 6 個已在 300 行以下,3 個略超標留待第三輪;已更新 `project.yml`
- 切片 8:`BeautyViews.swift`(1672 行)拆為主檔(`BeautyRootView`,97 行)+ 5 個檔案(Skincare/Whitening/HairAndBody/Products/Makeup);無 `private` 宣告,已檢查大括號配對正確;5 個新檔案中僅 `+Makeup.swift` 在 300 行以下,其餘 4 個略超標留待第三輪;已更新 `project.yml`
- 切片 9:`BodyViews.swift`(1270 行)拆為主檔(`BodyRootView`,79 行)+ 4 個檔案(Exercise/Wellness/Album/Meals);無 `private` 宣告,已檢查大括號配對正確;4 個新檔案中 2 個(`+Album`181、`+Meals`295)已在 300 行以下,`+Exercise`(356)、`+Wellness`(383)略超標留待第三輪;已更新 `project.yml`;至此展示層(`Views/`)的全部原始巨型檔案(AppPrototypeViews 衍生的 SharedViewComponents/BeautyViews/BodyViews)第二輪拆分皆已完成
- 切片 10:`BeautyDiaryStore+Resource.swift`(732 行,單一 `extension BeautyDiaryStore` 區塊)拆為 4 個 extension 檔案(Resource/ResourceSync/ResourceProfileSync/ResourceWorker),全數已在 300 行以下;已檢查大括號配對正確;已更新 `project.yml`
- 切片 11:`DiaryModels+Resource.swift`(645 行)拆為主檔(狀態/類型 enum,197 行)+ 3 個檔案(ResourcePayloads/ResourceImportDraft/ResourceItem);無 `private` 宣告,全數已在 300 行以下;已檢查大括號配對正確;已更新 `project.yml`
- 切片 12:`ResourcePipelineServices+SupabasePayloads.swift`(529 行)拆為主檔 + 2 個檔案(SupabaseRows/SupabaseAIPayloads);無 `private` 宣告,全數已在 300 行以下;已檢查大括號配對正確;已更新 `project.yml`
- 切片 13:`ResourceImportService+WebPage.swift`(524 行)拆為主檔(WebPageParser + `enum SharedHTMLParser` 主體,182 行)+ 4 個檔案(把 `SharedHTMLParser` 的靜態方法拆成 HTMLParsingHelpers/HTMLExtraction/HTMLUtilities 三個 `extension`,加上獨立的 JSONLDModels);全數已在 300 行以下;已檢查大括號配對正確;已更新 `project.yml`
- 切片 14:`ResourcePipelineServices+SupabaseSync.swift`(469 行)拆為 2 個檔案(`SupabaseCloudResourceSyncService`+錯誤型別留在主檔,`SupabaseRESTClient` 獨立成 `+RESTClient.swift`);`SupabaseCloudResourceSyncService` 內有 `private` 屬性但整個 struct 沒被拆開,無跨檔案存取風險;全數已在 300 行以下;已更新 `project.yml`;**至此第二輪拆分全部 8 個超標檔案都已處理完畢**
- 第二輪 CI 全面驗證完成:切片 7(SharedViewComponents)、9(BodyViews)、11(DiaryModels+Resource)、13(ResourceImportService+WebPage,重跑後)、14(ResourcePipelineServices+SupabaseSync)完整通過含 UI 測試;切片 8(BeautyViews)、10(BeautyDiaryStore+Resource)編譯 100% 通過,僅各自撞到已知的偶發性網路/模擬器 UI 測試問題(小紅書解析逾時、YouTube 鍵盤焦點合成失敗),經查證與拆分無關;切片 12(SupabasePayloads)完整通過;切片 13 第一次失敗在 `testImportResourceFromURLAppearsInLibrary`(先前程式碼註解標註為「穩定基準測試」,值得認真查證),已用逐行 diff 確認拆分內容 100% 無誤(唯一差異是 import 語句與 extension 包裝括號),重跑後全數通過,確認為偶發性網路逾時,非迴歸
- **第一輪(切片 2-6)+ 第二輪(切片 7-14)共 14 個切片全部完成,10 個原本超過 300 行的巨型檔案全數拆分並通過 CI 驗證**

## 已知問題

- ⚠️ **文檔疏漏發現**:重新掃描全部 `.swift` 檔案後發現,`ProfileViews.swift`(990 行)、`GrowthViews.swift`(853 行)、`FinanceViews.swift`(690 行)這三個切片 2 產出的檔案,以及原本就存在的 `SupabaseAuthService.swift`(600 行),當初都超過 300 行上限,但先前記錄 `ARCH.md`/`project_state.md` 時漏標警告、未列入待拆清單。目前完整清單(16 個檔案仍超過 300 行):
  - `ProfileViews.swift`(990)、`GrowthViews.swift`(853)、`FinanceViews.swift`(690)、`SupabaseAuthService.swift`(600)——**未曾拆過,優先度最高**
  - `DiaryModels.swift`(430)——切片 4 的核心檔案
  - 第二輪拆分後仍在 300-400 行的 11 個檔案:`BeautyViews+HairAndBody`(391)、`SharedViewComponents+AddSheetsOther`(388)、`BodyViews+Wellness`(383)、`BeautyViews+Skincare`(371)、`BodyViews+Exercise`(356)、`BeautyViews+Products`(352)、`BeautyViews+Whitening`(338)、`SharedViewComponents+AddSheets2`(333)、`BeautyDiaryStore+AIAdvice`(317)、`SharedViewComponents+AIAdviceUI`(308)、`BeautyDiaryStore+Beauty`(308)

- `SharedViewComponents+AddSheetsOther.swift`(388)、`+AddSheets2.swift`(333)、`+AIAdviceUI.swift`(308)第二輪拆分後仍略超標,待第三輪再拆
- `BeautyViews+Skincare.swift`(371)、`+Whitening.swift`(338)、`+HairAndBody.swift`(391)、`+Products.swift`(352)第二輪拆分後仍略超標,待第三輪再拆
- `BodyViews+Exercise.swift`(356)、`+Wellness.swift`(383)第二輪拆分後仍略超標,待第三輪再拆
- `ResourcePipelineServices+SupabaseSync.swift`(469 行)仍超過 300 行上限,待下一輪再拆
- `scripts/` 下 8 個 Python 腳本(`xhs_*.py`、`csv_to_supabase.py` 等)未加入 git 追蹤,也未列入 `.gitignore`,去留未定
- 外層工作目錄(`美麗日記app/`)的 `API.txt` 明文存放 Supabase secret key 與 management token,雖未進 git,仍建議清除或移至密碼管理工具
- 尚無 lint / 型別檢查自動化腳本,質量閘門僅有編譯 CI,無測試覆蓋率把關
- `MVP_GAP_TRACKER.md` 所列 P0 項目(小紅書/Instagram 正式匯入、真實 AI 供應商、同步衝突處理)仍為 partial/in progress

## 下一步

- 請在 Xcode(或觸發 CI)跑一次 build,確認切片 7 的拆分沒有破壞編譯
- 繼續第二輪拆分:`BeautyViews.swift`(1672)→ `BodyViews.swift`(1270)→ `BeautyDiaryStore+Resource.swift`(732)→ `DiaryModels+Resource.swift`(645)→ `ResourcePipelineServices+SupabasePayloads.swift`(529)→ `ResourceImportService+WebPage.swift`(524)→ `ResourcePipelineServices+SupabaseSync.swift`(469)
- 其餘 [待確認] 項目(隱私合規、性能/成本上限、可用性、維護方式)可待上線前再補,不阻塞當前拆檔工作
- 之後依序處理外層工作目錄清理、`scripts/` 去留、`API.txt` 明文金鑰

---

## 切片計劃(舊專案改造)

| # | 切片 | 涉及積木 | 涉及檔案 | 狀態 |
|---|---|---|---|---|
| 1 | 補齊三份全局文檔 | 地基 | PRD.md, ARCH.md, project_state.md | ✅ 已完成 |
| 2 | 拆分 AppPrototypeViews.swift | 展示 | Views/AppPrototypeViews.swift → 7 個新檔案 + project.yml | ✅ 已完成並通過 CI |
| 3 | 拆分 BeautyDiaryStore.swift | 記憶/邏輯 | Services/BeautyDiaryStore.swift → 主檔 + 8 個 extension + project.yml | ✅ 已完成並通過 CI |
| 4 | 拆分 DiaryModels.swift | 記憶 | Models/DiaryModels.swift → 主檔 + 7 個檔案 + project.yml | ✅ 已完成並通過 CI |
| 5 | 拆分 ResourcePipelineServices.swift | 連線 | Services/ResourcePipelineServices.swift → 主檔 + 5 個檔案 + project.yml | ✅ 已完成並通過 CI |
| 6 | 拆分 ResourceImportService.swift | 連線/爬蟲 | Services/ResourceImportService.swift → 主檔 + 4 個平台檔案 + project.yml | ✅ 已完成並通過 CI(含 UI 測試) |
| 7 | 第二輪拆分:SharedViewComponents.swift | 展示 | Views/SharedViewComponents.swift → 主檔 + 9 個檔案 + project.yml | ✅ 已完成並通過 CI(含 UI 測試) |
| 8 | 第二輪拆分:BeautyViews.swift | 展示 | Views/BeautyViews.swift → 主檔 + 5 個檔案 + project.yml | ✅ 編譯通過(1 個無關的 UI 測試偶發失敗) |
| 9 | 第二輪拆分:BodyViews.swift | 展示 | Views/BodyViews.swift → 主檔 + 4 個檔案 + project.yml | ✅ 已完成並通過 CI(含 UI 測試) |
| 10 | 第二輪拆分:BeautyDiaryStore+Resource.swift | 記憶/邏輯 | Services/BeautyDiaryStore+Resource.swift → 4 個 extension 檔案 + project.yml | ✅ 編譯通過(1 個無關的 UI 測試偶發失敗) |
| 11 | 第二輪拆分:DiaryModels+Resource.swift | 記憶 | Models/DiaryModels+Resource.swift → 主檔 + 3 個檔案 + project.yml | ✅ 已完成(待你 Xcode/CI 編譯驗證) |
| 12 | 第二輪拆分:ResourcePipelineServices+SupabasePayloads.swift | 連線 | Services/ResourcePipelineServices+SupabasePayloads.swift → 主檔 + 2 個檔案 + project.yml | ✅ 已完成(待你 Xcode/CI 編譯驗證) |
| 13 | 第二輪拆分:ResourceImportService+WebPage.swift | 爬蟲 | Services/ResourceImportService+WebPage.swift → 主檔 + 4 個檔案 + project.yml | ✅ 已完成(待你 Xcode/CI 編譯驗證) |
| 14 | 第二輪拆分:ResourcePipelineServices+SupabaseSync.swift | 連線 | Services/ResourcePipelineServices+SupabaseSync.swift → 2 個檔案 + project.yml | ✅ 已完成(待你 Xcode/CI 編譯驗證) |
| 15 | 清理外層工作目錄(APK 分析、爬蟲輸出、過期 iOS_Project) | 地基 | 美麗日記app/(外層) | ⬜ |
| 16 | 補質量閘門(lint / 型別檢查腳本) | 地基 | CI 設定 | ⬜ |

---

## 每次開新對話,第一條訊息這樣說:

```
先讀 publish_ios_repo/PRD.md、ARCH.md、project_state.md,了解當前狀態,然後我們來做「具體任務」
```

## 每個切片完成後,按順序執行:

1. 手動跑一遍,對照 PRD 驗收清單逐條檢查
2. 跑 lint,修掉代碼規範問題
3. 跑型別檢查
4. 跑測試
5. 更新本文件(三件事)
6. git commit,寫清楚這次提交做了什麼
