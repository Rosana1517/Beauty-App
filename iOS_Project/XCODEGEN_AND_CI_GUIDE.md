# XcodeGen 與雲端編譯指南

## 目標

讓專案在沒有 Windows 本機 Xcode 的情況下，仍可透過 macOS CI 完成 iOS 編譯。

## 目前已加入

- `project.yml`
  - 使用 `XcodeGen` 生成 `BeautifulDiary.xcodeproj`
- `.github/workflows/ios-xcodegen-build.yml`
  - 在 GitHub Actions 的 `macos-latest` runner 上生成並編譯模擬器版 `.app`
- `codemagic.yaml`
  - 在 Codemagic 上生成並編譯模擬器版 `.app`

## 專案生成方式

在 macOS 環境中進入 `iOS_Project/` 後執行：

```bash
brew install xcodegen
xcodegen generate --spec project.yml
```

會生成：

```text
BeautifulDiary.xcodeproj
```

## GitHub Actions

觸發方式：

- push / pull request 到含 `iOS_Project/**` 變更的分支
- 手動 `workflow_dispatch`

輸出：

- `BeautifulDiary-simulator-app.zip`
- simulator `.app`
- `dSYM`

## Codemagic

工作流程名稱：

- `ios-xcodegen-simulator`

輸出：

- `BeautifulDiary-simulator-app.zip`
- simulator `.app`
- `dSYM`

## 目前編譯型態

- `iphonesimulator`
- `CODE_SIGNING_ALLOWED=NO`

這代表目前是：

- 可以驗證 SwiftUI 專案是否能被 Xcode 編譯
- 不需要 Apple 簽章
- 不會產生可上架的正式 IPA

## 未來若要產出 IPA

還需要補：

- Apple Developer 帳號
- Bundle Identifier
- Signing certificate / provisioning profile
- App Store Connect 或 TestFlight 設定
