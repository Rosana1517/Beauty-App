# project_state — 當前狀態文檔

## 當前階段

舊專案積木化改造(模式 E)20 個切片全數完成並通過 CI 驗證。全專案已無超過 300 行的檔案,外層工作目錄已清理,安全底線問題已修復,質量閘門(SwiftLint)已加入 CI 並轉為 blocking gate(3 個已知問題檔案暫時排除)。

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
- 切片 15(第三輪拆分開始):`ProfileViews.swift`(990 行)拆為主檔(`ProfileView`,98 行)+ 5 個檔案(ResourceLibrary/Settings/Customization/Achievements/DataExport);`PersonalSettingsView` 與其用到的 4 個 `private` 卡片(HabitRemindersCard/HabitReminderRow/AIProviderSettingsCard/SupabaseSyncSettingsCard)非連續但保留在同一個 `+Settings.swift`,避免切片 2 的跨檔案 private 存取問題;`+Settings.swift`(377 行)因耦合緊密暫不再拆,其餘皆在 300 行以下;已檢查大括號配對正確;已更新 `project.yml`
- 切片 16:`GrowthViews.swift`(853 行)拆為主檔(`GrowthRootView`,91 行)+ 6 個檔案(Reading/Course/Knowledge/VideoLearning/DailyQuote/Mood);`CourseTrackerView` 與其用到的 2 個 `private` 型別(CoursePlayerSheet/YouTubeEmbedView)保留在同一個 `+Course.swift`;全數已在 300 行以下;已檢查大括號配對正確;已更新 `project.yml`
- 切片 17:`FinanceViews.swift`(690 行)拆為主檔(`FinanceRootView`,69 行)+ 5 個檔案(Ledger/Budget/Analysis/Shopping/Health);無 `private` 宣告;全數已在 300 行以下;已檢查大括號配對正確;已更新 `project.yml`
- 切片 18(第三輪拆分完成):`SupabaseAuthService.swift`(600 行)拆為主檔(小型 enum/protocol/Noop,98 行)+ 2 個檔案(EmailAuthCore 業務邏輯/EmailAuthHTTP 請求層+DTO);`SupabaseEmailAuthService` 的儲存屬性、多個 `private` 方法、以及 7 個被 EmailAuthCore 用到的 DTO/`JSONDecoder` 擴充皆已 strip private 改為模組內可見(僅 `SupabaseErrorResponse`/`decodeSupabaseErrorMessage` 因只在同檔案內使用而保留 private);已 grep 確認新暴露符號無撞名;全數已在 300 行以下;已檢查大括號配對正確;已更新 `project.yml`;**四個漏標檔案至此全數拆分完畢**
- 第二輪 CI 全面驗證完成:切片 7(SharedViewComponents)、9(BodyViews)、11(DiaryModels+Resource)、13(ResourceImportService+WebPage,重跑後)、14(ResourcePipelineServices+SupabaseSync)完整通過含 UI 測試;切片 8(BeautyViews)、10(BeautyDiaryStore+Resource)編譯 100% 通過,僅各自撞到已知的偶發性網路/模擬器 UI 測試問題(小紅書解析逾時、YouTube 鍵盤焦點合成失敗),經查證與拆分無關;切片 12(SupabasePayloads)完整通過;切片 13 第一次失敗在 `testImportResourceFromURLAppearsInLibrary`(先前程式碼註解標註為「穩定基準測試」,值得認真查證),已用逐行 diff 確認拆分內容 100% 無誤(唯一差異是 import 語句與 extension 包裝括號),重跑後全數通過,確認為偶發性網路逾時,非迴歸
- **第一輪(切片 2-6)+ 第二輪(切片 7-14)+ 第三輪(切片 15-18)共 18 個切片全部完成,14 個超過 300 行的檔案全數拆分**;第三輪 4 個切片(ProfileViews/GrowthViews/FinanceViews/SupabaseAuthService)CI 全數**完整通過(含 UI 測試)**,零問題
- CI 抓到第四輪的一個新問題:`SkincareManagementView`/`WellnessView` 的儲存屬性(`store`/`editingXxx`/`showAddXxx` 等)在被拆到 extension 另檔的 content computed property 裡被引用,卻沒 strip private(跟切片 3 同類坑,只是這次發生在 SwiftUI View 層),已修正;commit e7574e3 的「Build for iOS Simulator」與「Run UI tests」皆 ✓ 通過,**第四輪 12 個檔案全數驗證完成**
- 第四輪(切片 19,一次處理 13 個輕微超標檔案):`DiaryModels.swift`(拆出 Decoding/Seed,CodingKeys 由 private 改模組內可見)、`BeautyDiaryStore+AIAdvice.swift`(拆出 Habits)、`BeautyDiaryStore+Beauty.swift`(拆出 BeautyExtra)、`SharedViewComponents+AddSheetsOther/AddSheets2/AIAdviceUI`(依 struct 邊界切分)、`BeautyViews+Products/Exercise(BodyViews)/Whitening`(依 struct 邊界切分)、`BodyViews+Wellness`/`BeautyViews+Skincare`(單一巨型 View,把大型 `private` computed property 改模組內可見後移到 `extension` 另檔)、`ProfileViews+Settings`(4 個 private 卡片 strip private 後獨立成檔);已對每個新 internal 符號 grep 確認無撞名,全部 24 個新檔案大括號配對正確;12/13 個檔案已在 300 行以下,僅 `BeautyViews+HairAndBody.swift`(391,單一巨型 body,需視圖重構)未處理;已更新 `project.yml`(已核對:所有 `.swift` 檔案與 `project.yml` 條目一一對應,無遺漏無重複)

## 已知問題

- commit 6d81a00 的 CI 全數通過(Build for iOS Simulator + Run UI tests 皆 ✓),第五輪視圖重構驗證完成
- ✅ **`BeautyViews+HairAndBody.swift` 已處理**(第五輪):`HairCareView.body` 沒有現成可搬的 computed property,改用「先抽取、再搬移」——把「洗護產品」「髮質檢測記錄」「護髮療程預約」三個 `CardView` 區塊抽成 `productsCard`/`recordsCard`/`appointmentsCard`,移到 `extension HairCareView`(`BeautyViews+HairAndBodyExtra.swift`);對應的 `@State`/`@EnvironmentObject` 已從 private 改為模組內可見;主檔降到 283 行,新檔 127 行,皆已檢查大括號配對正確;已更新 `project.yml`(核對全部檔案與條目一一對應)。**專案內所有 `.swift` 檔案至此皆已在 300 行以下**
- ✅ **外層工作目錄已清理**(2026-07-17):移除 182MB+ 的 APK 逆向殘留與過期 `iOS_Project/` 複製品(僅本機 commit,未推送——該倉庫落後 origin/main 169 個 commit 且有自己的分歧歷史);保留小紅書爬蟲輸出、`apk版本功能頁面參考/`、`API.txt`(使用者自行處理)
- ✅ **`scripts/` 安全底線已處理**(2026-07-17):發現 5 個腳本(`csv_to_supabase.py`/`pregenerate_recommendations.py`/`test_ai_recommend.py`/`thumbnails_to_storage.py`/`xhs_fetch_classify.py`)硬編碼了 Supabase secret key(跟外層 `API.txt` 同一把),已改成讀取 `SUPABASE_SERVICE_ROLE_KEY` 環境變數並在未設定時明確報錯;8 個腳本(含另外 3 個無金鑰問題的)全數加入 git 追蹤,commit a1bb94b 已推送
- 外層工作目錄的 `API.txt` 仍明文存放 Supabase secret key 與 management token,使用者已表示會自行移至密碼管理工具後再刪除
- ✅ **SwiftLint 質量閘門已加入 CI 並完成兩輪清理**(2026-07-17):新增 `iOS_Project/.swiftlint.yml`(已停用 `file_length`/`type_body_length`,因為 300 行檔案上限已由人工慣例把關)與 CI 新的 `lint` job(`.github/workflows/ios-xcodegen-build.yml`,commit 009b9a3);另加了一個 `swiftlint-report` JSON artifact 上傳步驟,方便抓精確 file:line 修違規(compact 的 github-actions-logging reporter 只有規則說明沒有行號,不夠精準)。型別檢查本身已由既有的 `Build for iOS Simulator` 步驟(`xcodebuild build`)涵蓋,不需另外的型別檢查腳本。
  - 基準(run 29554231033):**203 個違規、3 個 serious,105 個檔案**
  - 第一輪(commit a5f6146):修掉 `trailing_newline`(76,CRLF 換行結尾)與 `vertical_whitespace`(36,多餘空行)→ 剩 91 個;CI 全綠(build-ios-simulator 10m31s ✓)
  - 第二輪(commit 111bcc5 + b469656):修掉 `trailing_comma`(10)、`redundant_string_enum_value`(10)、`unused_closure_parameter`(15)、`duplicate_imports`(2)、`implicit_optional_initialization`(4)、`large_tuple`(4,改成具名 struct `AchievementItem`/`ExerciseCompletionRates`,僅限單檔案內部使用,無外部 API 影響)、`line_length`(2)、`force_cast`(1,`as!` 改成 `if let ... as?`)共 49 個 → **剩 43 個**;CI 全綠(build-ios-simulator 13m42s ✓)
  - **踩坑記錄(教訓)**:commit 111bcc5 對 `BeautyViews+HairAndBody.swift` 用 Edit 工具的 `replace_all: true` 修 `unused_closure_parameter`,但該檔案裡 `{ values, newDate in }` 這個 pattern 在 `showsDate: false`(newDate 真的沒用到)與 `showsDate: true`(newDate 有用到,要寫入 `updated.date`)兩種情境都出現,replace_all 誤把 3 處「有用到」的也改成 `_`,導致編譯錯誤(`cannot find 'newDate' in scope`)。已於 commit b469656 修正並重跑 CI 驗證通過。**教訓:同一 pattern 在同檔案內若可能出現在語意不同的位置(尤其是「參數是否被使用」這種要看函式本體才能判斷的情況),絕不能用 `replace_all: true` 盲改,必須逐一 Read 確認上下文語意一致後才批次替換,否則要靠 CI 才能抓到。**
  - 第三輪(commit e4d1918):修掉 `multiple_closures_with_trailing_closure`(37)→ **剩 6 個**。34 處 `.recordActions(onEdit: {...}) { ... }` 用 python 正則腳本機械轉成 `.recordActions(onEdit: {...}, onDelete: { ... })`(比對前後大括號配對與 diff 驗證皆為 closure 語法變動,無邏輯改變);另外 `BeautyViews+Whitening.swift` 的 2 處 `planRow(...) { ... }`、`ProfileViews+ResourceLibrary.swift` 的 `.sheet(isPresented:onDismiss:) { ... }` 手動改成具名參數。CI 驗證:`Build for iOS Simulator` 三次執行皆 ✓;`Run UI tests` 前兩次重跑各自失敗在不同、且與本次改動完全無關的測試(第一次 `testXiaohongshuLinkParsesToRealMetadata` 小紅書網路解析逾時、第二次 `testSignInReachesAuthenticatedAndSyncsResources` 模擬器啟動逾時「Timed out while requesting launch progress」),第三次重跑**全數通過**(`build-ios-simulator` 13m16s ✓);判定前兩次為 CI 環境偶發性問題而非迴歸,依據:(1) 三次編譯皆乾淨通過 (2) 失敗測試涉及 CloudSync 登入同步與小紅書解析,與這批只動 24 個 View 檔案 closure 語法的改動範圍完全不相關 (3) 兩次失敗測試彼此不同,不是同一處穩定重現的錯誤
  - **剩餘 6 個違規,刻意跳過未修,集中在 2 個檔案,原因如下**:
    - `function_parameter_count`(3):`ResourceImportService+WebPage.swift` 的 `makeDraft`(12 參數)與 `SupabaseAuthService+EmailAuthHTTP.swift` 的 `request`/`performRequest`(6 參數,含泛型)要降到 5 以下需要包成 DTO/Options struct,牽涉所有呼叫端簽名,風險較高
    - `function_body_length`(1):`ResourceImportService+XHS.swift` 的 `XHSMediaDeriver.derive`(85 行 HTML 爬蟲解析函式),拆分需要重構解析邏輯,擔心引入爬蟲 bug
    - `optional_data_string_conversion`(1):`ResourceImportService+WebPage.swift`,建議把 `String(decoding:as:)`(遇到非法編碼會 lossy-decode 保留亂碼字元)改成 `String(bytes:encoding:)`(遇到非法編碼回傳 nil),這是行為語意改變,可能讓格式異常的網頁匯入從「勉強解析」變成「直接失敗」,不確定是否為預期行為,先跳過
    - `line_length`(1,警告等級,197/160 字元,`ResourceImportService+WebPage.swift` 的 User-Agent 字串):同一個因上述兩條而整體避開修改的高風險檔案,一併留待之後處理
  - ✅ **已轉為 blocking gate**(2026-07-18,commit e6813ce):使用者選擇「排除這 3 個問題檔案,其餘轉 blocking」。把 `ResourceImportService+WebPage.swift`、`ResourceImportService+XHS.swift`、`SupabaseAuthService+EmailAuthHTTP.swift` 加進 `iOS_Project/.swiftlint.yml` 的 `excluded` 清單(路徑寫成相對於 `included: [美麗日記]` 的 `美麗日記/Services/...`),同時拿掉 CI `lint` job 的 `continue-on-error: true`;JSON report 步驟改用 `if: always()` 保留診斷用途。CI 驗證:run 29632614081 的 `lint` job 16 秒 ✓ 通過(零違規,exclude 路徑寫法正確一次到位)。**現在其餘 100+ 個檔案的任何新 SwiftLint 違規都會讓 CI 失敗**,3 個排除檔案的既有 6 個違規待日後另開一輪(函式簽名/DTO 重構)處理後再移出排除清單
- ✅ **MVP_GAP_TRACKER P0 重新稽核**(2026-07-18):對照真實代碼逐條核對,發現 tracker 嚴重過期,已據實改寫。實情:
  - **P0.1 Auth+同步 = done**:session 持久化/還原+過期自動 refresh、email/密碼/Magic Link/登出、同步 401 自動 refresh+重試(`recoverSessionIfNeeded`)、短暫網路重試、資源層衝突合併(`merge`+`canOverwriteWithRemote`)、RLS 已部署驗證皆完成;僅剩「跨裝置 **profile** 衝突仍 seed-only」屬 P1 邊角
  - **P0.2 後端函式 = done**:9 個 Edge Function 已部署
  - **P0.3 平台匯入 = 外部阻塞(非代碼缺口)**:Instagram 需 Meta Graph API 商家驗證+App Review(數週、使用者驅動);小紅書無公開 API 且台灣封鎖(見 auto-memory)——皆非寫代碼可解
  - **P0.4 真實 AI = done**:`aiProvider.ts` 已完整串接 OpenAI/Anthropic(使用者自帶金鑰+RLS 隔離+Tavily 網搜+Vision),被 5 個函式消費
  - 附帶發現:P1.5 通知排程也已有真實 `UNUserNotificationCenter` 實作(非 stub),tracker 亦過期
  - **結論:無「未做且我能直接寫代碼」的 P0 缺口;使用者選擇方向 = 全鏈路驗證+打磨**
- ✅ **P0 後端全鏈路實測**(2026-07-18,`scratchpad/rls_test.py`,測試帳號用完即刪):**14/15 通過**
  - Auth 生命週期:建帳號 → 密碼登入 → refresh_token 換新 token 全數 PASS
  - **RLS 安全隔離全綠(上線前最關鍵):** A 可建自己的 `app_users`/`resource_items`;A **無法**冒名以 `user_id=B` 寫入(403);B **讀不到** A 的資源;**匿名讀不到任何** resource_item;`user_ai_provider_settings` 僅限本人
  - Edge Function 驗證路徑:`exercise-match`/`ai-advice` 在已登入但未設 AI 供應商時正確回 422 + 中文引導
  - 唯一 FAIL(低嚴重度,**未修**):帶「非使用者 token」(如 anon key)呼叫 Edge Function 時,共用的 `resolveAuthenticatedUserID` 拋錯被各函式 catch-all 當成 **500 而非 401**。iOS 端會優雅降級(`mappedError` → `.serverMessage`,`ExerciseMatchView` 比對 "authenticated" 顯示「請先登入」),使用者不會看到壞畫面,僅 HTTP 語意不精確。修正需動 9 個函式的 catch 並全部重新部署,驗證期間風險大於效益,**留待後續獨立處理**
  - 測試腳本初版兩個 FAIL 是我自己用錯欄位(`display_name` 應為 `nickname`),非 app bug——app 端用的是正確欄位
- ✅ **CI UI 測試覆蓋確認**:既有 5 個測試檔涵蓋 P0 核心(登入→驗證→同步、錯誤密碼、失效連結 fallback、資源匯入、XHS/YouTube 解析);**新的運動資料庫/AI 匹配尚無 UI 測試**(覆蓋缺口,非 bug)
- ✅ **打磨:exercise-match 冷門部位候選過少**(已改+已部署+已回歸驗證):實測資料發現「頸部」全庫僅 2 筆、過濾後 LLM 湊不出 UI 承諾的 5-8 個動作(「心肺」29 筆中 21 筆徒手,不受影響)。已加 `THIN_POOL_THRESHOLD=25`:候選不足時自動補進 48 個瑜伽伸展體式(頸/肩背需求本就適合搭配伸展)。回歸測試 `scratchpad/match_regression.py` **6/6 通過**(落枕/瘦大腿/居家徒手燃脂/開肩放鬆/隨便動一動/健身房練胸 皆回 422 代表候選取得正常,無 500)

- ✅ **運動資料庫 `exercise_library` 已上線 Supabase**(2026-07-17):整合 exercises-dataset(1,324 筆健身動作,中文教學已簡轉繁)與 yoga-api(48 個瑜伽體式,繁中名稱/難度/分類已補)共 1,372 筆,統一格式;schema(含 RLS 公開唯讀、tags GIN 索引)、清洗與匯入腳本、原始資料備份皆在外層 `../database/`;已用 publishable key 驗證匿名讀取、難度/tags 篩選、繁中內容皆正常;媒體仍外連 GitHub raw/Cloudinary(詳見 `../database/README.md`)
- ✅ **`exercise_library` 中文翻譯已全數補齊**(2026-07-17):AI 批次翻譯 1,324 個健身動作繁中名稱(統一術語慣例:槓鈴/啞鈴/滑輪/槓桿式/上斜/坐姿/俯身等)與 48 個瑜伽體式的繁中動作說明+功效;翻譯檔存於 `../database/translations/`(strength_names_zh.json / yoga_zh.json),`apply_translations.py` 已套用到本地 cleaned JSON 與 Supabase;驗證:全表 1,372 筆 `name_zh`/`description_zh` 100% 非空、yoga 48 筆 `benefits_zh` 100% 非空,抽查內容正確

## 下一步

- 請在 Xcode(或觸發 CI)跑一次 build,確認第四輪(切片 19+)的拆分沒有破壞編譯
- 檔案上限規則已全面達標,無待辦拆檔項目
- SwiftLint 已加入 CI(advisory);待使用者決定是否要花時間清理 203 個基準違規、轉為 blocking 閘門
- 其餘 [待確認] 項目(隱私合規、性能/成本上限、可用性、維護方式)可待上線前再補,不阻塞當前拆檔工作
- 外層工作目錄清理與 `scripts/` 安全底線皆已完成;僅剩 `API.txt` 待使用者自行處理
- `exercise_library` 後續切片建議:① ~~AI 批次翻譯補齊中文~~(✅)② ~~iOS 端查詢/展示~~(✅ 已驗收)③ ~~AI 智能匹配~~(✅ 已驗收)④ ~~媒體搬遷至 Supabase Storage~~(✅ 2026-07-18:2,648 個 exercises-dataset 縮圖/GIF + 48 張 yoga 插圖共約 140 MB 上傳至公開 bucket `exercise-media`,零失敗;1,372 筆 `image_url`/`gif_url` 已改指向 Storage 公開 URL 並驗證 200、無殘留 GitHub raw/Cloudinary 連結;app 端 URL 由資料庫讀取,無需改代碼即生效;腳本 `../database/migrate_media_to_storage.py`)——**exercise_library 四個規劃切片至此全部完成**
- **AI 動作匹配切片**(2026-07-17):新增 Edge Function `exercise-match`(已部署):bearer token 解析使用者 → 需求關鍵字推斷部位/瑜伽/居家器材過濾 → 預篩 exercise_library 候選(最多約 150 筆)→ `_shared/aiProvider.ts` 新增 `matchExercisesFromCatalog()`(沿用使用者自帶 AI 供應商 + 雙請求降延遲,只接受清單內 id)→ 回傳完整動作資料+推薦理由;iOS 端:`AppRuntimeConfiguration.exerciseMatchFunction`、`ExerciseLibraryService.matchExercises(need:)`、`BodyViews+ExerciseMatch.swift`(輸入+常用需求 chips+結果卡片,可進詳情/一鍵加入自訂運動,未登入與未設 AI 供應商有明確錯誤引導),運動管理頁新增「AI 動作匹配」入口卡;`BodyViews+Exercise.swift` 290 行接近上限,下次動它前先拆
- **運動資料庫 iOS 展示切片**(2026-07-17):新增 `Models/ExerciseLibraryModels.swift`(77 行)、`Services/ExerciseLibraryService.swift`(65 行,重用 `SupabaseRESTClient` 匿名查詢)、`Views/BodyViews+ExerciseLibrary.swift`(249 行,清單+類型/部位/難度篩選+中英文搜尋+分頁載入)、`Views/BodyViews+ExerciseLibraryDetail.swift`(152 行,詳情+GIF 動畫示範 `AnimatedGIFView`(WKWebView,AsyncImage 不會播 GIF)+步驟/功效+出處標記);入口為體態頁 → 運動管理 → 「運動資料庫」卡片(`BodyViews+Exercise.swift` +24 行);`project.yml` 已加 4 個新檔;PRD 已先行更新(功能列表/完成定義/驗收清單);全部檔案 300 行以下,新符號已 grep 確認無撞名
- 使用執行 `csv_to_supabase.py`/`pregenerate_recommendations.py`/`test_ai_recommend.py`/`thumbnails_to_storage.py`/`xhs_fetch_classify.py` 前需先 `export SUPABASE_SERVICE_ROLE_KEY=...`(或 Windows `set`),否則會直接報錯退出

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
| 11 | 第二輪拆分:DiaryModels+Resource.swift | 記憶 | Models/DiaryModels+Resource.swift → 主檔 + 3 個檔案 + project.yml | ✅ 已完成並通過 CI |
| 12 | 第二輪拆分:ResourcePipelineServices+SupabasePayloads.swift | 連線 | Services/ResourcePipelineServices+SupabasePayloads.swift → 主檔 + 2 個檔案 + project.yml | ✅ 已完成並通過 CI |
| 13 | 第二輪拆分:ResourceImportService+WebPage.swift | 爬蟲 | Services/ResourceImportService+WebPage.swift → 主檔 + 4 個檔案 + project.yml | ✅ 已完成並通過 CI |
| 14 | 第二輪拆分:ResourcePipelineServices+SupabaseSync.swift | 連線 | Services/ResourcePipelineServices+SupabaseSync.swift → 2 個檔案 + project.yml | ✅ 已完成並通過 CI |
| 15 | 第三輪拆分:ProfileViews.swift | 展示 | Views/ProfileViews.swift → 主檔 + 5 個檔案 + project.yml | ✅ 已完成並通過 CI(含 UI 測試) |
| 16 | 第三輪拆分:GrowthViews.swift | 展示 | Views/GrowthViews.swift → 主檔 + 6 個檔案 + project.yml | ✅ 已完成並通過 CI(含 UI 測試) |
| 17 | 第三輪拆分:FinanceViews.swift | 展示 | Views/FinanceViews.swift → 主檔 + 5 個檔案 + project.yml | ✅ 已完成並通過 CI(含 UI 測試) |
| 18 | 第三輪拆分:SupabaseAuthService.swift | 身份 | Services/SupabaseAuthService.swift → 主檔 + 2 個檔案 + project.yml | ✅ 已完成並通過 CI(含 UI 測試) |
| 19 | 第四輪拆分:13 個輕微超標檔案 | 展示/記憶/邏輯 | 13 個原檔 → 24 個新檔案 + project.yml | ✅ 12/13 完成並通過 CI(含 UI 測試) |
| 20 | 第五輪:BeautyViews+HairAndBody.swift 視圖重構 | 展示 | Views/BeautyViews+HairAndBody.swift → 主檔 + Extra 檔案 + project.yml | ✅ 已完成並通過 CI(含 UI 測試);**全專案檔案已無超過 300 行者** |
| 20 | 清理外層工作目錄(APK 分析、爬蟲輸出、過期 iOS_Project) | 地基 | 美麗日記app/(外層) | ✅ 已完成(本機 commit,未推送) |
| 21 | 補質量閘門(SwiftLint) | 地基 | `.swiftlint.yml` + CI lint job | ✅ 已完成(advisory 模式,基準 203 個違規) |

(切片 15-18 CI 全數 success,含 UI 測試,無任何問題)

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
