# 美麗日記 iOS 重建專案

此專案以 `apk版本功能頁面參考` 截圖作為唯一產品基準，重建一版 `SwiftUI` 原生、高擬真、可互動、可本地保存資料的 iOS 原型。

## 專案定位

- 目標是復刻截圖中的美容生活管理產品。
- 不嘗試把 `20260612_f1bf059b29152f66cc915596c4359f81_offset_58130432.apk` 直接轉成 iOS 可執行程式碼。
- APK 僅保留為錯誤分析對照樣本。

## 目前完成

- 五大分頁：`首頁 / 變美 / 體態 / 成長 / 我的`
- `護膚管理`：護膚步驟、保養品、膚質追蹤、教程連結、打卡歷史、AI 建議
- `體態`：運動管理、塑型計畫、體重體脂、飲食記錄、養生健康、體態相簿入口
- `成長`：閱讀追蹤與成長類入口
- `我的`：個人設定、客製化、資源庫、成就徽章、數據匯出
- 本地 JSON 持久化
- Mock AI 建議與資源推薦

## 重要文件

- `ANALYSIS_VALIDATION_REPORT.md`：APK 與截圖衝突驗證
- `SCREENSHOT_FUNCTION_MAP.md`：截圖對頁面功能映射
- `BUILD_VERIFICATION_REPORT.md`：本次重建版驗證重點
- `project.yml`：XcodeGen 專案描述
- `XCODEGEN_AND_CI_GUIDE.md`：GitHub Actions / Codemagic 使用方式

## Windows 開發補充

- Windows 端無法直接使用 Xcode 編譯 iOS App。
- 目前已加入兩條 macOS 雲端編譯路線：
  - GitHub Actions：`.github/workflows/ios-xcodegen-build.yml`
  - Codemagic：`/codemagic.yaml`
- 兩者都會先用 `XcodeGen` 生成 `.xcodeproj`，再編譯模擬器版 `.app`。

## 注意事項

- 舊版文件中若曾聲稱「APK 已驗證」美容功能，均以本次重建文件為準。
- 本輪未接真實後端、第三方登入、真實社群抓取、正式 PDF 分享流程。
