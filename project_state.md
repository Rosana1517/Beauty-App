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
- 切片 4:`Models/DiaryModels.swift`(1652 行,80+ 個獨立 struct/enum)已按 domain 拆為主檔(`BeautyDiaryState` 根狀態,430 行)+ 7 個檔案(Routes/Resource/Profile/Beauty/Finance/Growth/Body);本檔全部型別皆無 `private` 或 class 屬性存取問題,拆分風險低於切片 2/3,已檢查每個新檔案大括號配對正確;已更新 `project.yml`

## 已知問題

- `SharedViewComponents.swift`(2589 行)、`BeautyViews.swift`(1672 行)、`BodyViews.swift`(1270 行)仍超過 300 行上限,待下一輪再拆
- `BeautyDiaryStore+Resource.swift`(732 行,資源匯入/同步/雲端鑑權)仍超過 300 行上限,待下一輪再拆
- `DiaryModels+Resource.swift`(645 行,資源匯入/XHS 模型)仍超過 300 行上限,待下一輪再拆
- `Services/ResourcePipelineServices.swift` 1521 行、`Services/ResourceImportService.swift` 1063 行,均嚴重超過 300 行上限,待拆分
- `scripts/` 下 8 個 Python 腳本(`xhs_*.py`、`csv_to_supabase.py` 等)未加入 git 追蹤,也未列入 `.gitignore`,去留未定
- 外層工作目錄(`美麗日記app/`)的 `API.txt` 明文存放 Supabase secret key 與 management token,雖未進 git,仍建議清除或移至密碼管理工具
- 尚無 lint / 型別檢查自動化腳本,質量閘門僅有編譯 CI,無測試覆蓋率把關
- `MVP_GAP_TRACKER.md` 所列 P0 項目(小紅書/Instagram 正式匯入、真實 AI 供應商、同步衝突處理)仍為 partial/in progress

## 下一步

- 請在 Xcode(或觸發 CI)跑一次 build,確認切片 4 的拆分沒有破壞編譯
- 開始切片 5:拆分 `ResourcePipelineServices.swift`(1521 行)
- 其餘 [待確認] 項目(隱私合規、性能/成本上限、可用性、維護方式)可待上線前再補,不阻塞當前拆檔工作
- 之後依序處理外層工作目錄清理、`scripts/` 去留、`API.txt` 明文金鑰

---

## 切片計劃(舊專案改造)

| # | 切片 | 涉及積木 | 涉及檔案 | 狀態 |
|---|---|---|---|---|
| 1 | 補齊三份全局文檔 | 地基 | PRD.md, ARCH.md, project_state.md | ✅ 已完成 |
| 2 | 拆分 AppPrototypeViews.swift | 展示 | Views/AppPrototypeViews.swift → 7 個新檔案 + project.yml | ✅ 已完成(待你 Xcode 編譯驗證) |
| 3 | 拆分 BeautyDiaryStore.swift | 記憶/邏輯 | Services/BeautyDiaryStore.swift → 主檔 + 8 個 extension + project.yml | ✅ 已完成並通過 CI |
| 4 | 拆分 DiaryModels.swift | 記憶 | Models/DiaryModels.swift → 主檔 + 7 個檔案 + project.yml | ✅ 已完成(待你 Xcode/CI 編譯驗證) |
| 5 | 拆分 ResourcePipelineServices.swift / ResourceImportService.swift | 連線/爬蟲 | Services/Resource*.swift | ⬜ |
| 6 | 清理外層工作目錄(APK 分析、爬蟲輸出、過期 iOS_Project) | 地基 | 美麗日記app/(外層) | ⬜ |
| 7 | 補質量閘門(lint / 型別檢查腳本) | 地基 | CI 設定 | ⬜ |

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
