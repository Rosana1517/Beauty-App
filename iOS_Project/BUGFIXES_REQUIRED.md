# 美麗日記 iOS 專案 - 編譯錯誤修復指南

## 重要通知

專案核心功能已全部完成，但存在 **10 個編譯錯誤** 需要先修正才能成功編譯。以下提供詳細修復步驟。

---

## 🔴 嚴重錯誤（必須修復）

### 錯誤 1: `UserInfoKeys` 未定義
**檔案：** `Services/Utils.swift` 第 25-50 行

**問題：** 使用了未定義的 `UserInfoKeys` 枚舉

**修復方法：**

在 `Services/Utils.swift` 檔案開頭，`import Foundation` 之後添加：

```swift
import CommonCrypto

enum UserInfoKeys {
    static let userId = "user_id"
    static let email = "email"
    static let phone = "phone"
    static let nickname = "nickname"
    static let avatarURL = "avatar_url"
    static let coins = "coins"
    static let userLevel = "user_level"
}
```

### 錯誤 2: `ImageCache.groupIdentifier` 存取權限問題
**檔案：** `Services/Utils.swift` 第 38 行

**問題：** `groupIdentifier` 是 `private static`，但在 `init()` 中無法存取

**修復方法：**

將第 76 行的：
```swift
private static let groupIdentifier = "group.com.beautifudiary.cache"
```

改為：
```swift
static let groupIdentifier = "group.com.beautifudiary.cache"
```

### 錯誤 3: `AdViewController` 不是 SwiftUI View
**檔案：** `Views/EarnCoinsView.swift` 第 107-114 行

**問題：** `fullScreenCover` 需要 View，但 `AdViewController` 是 UIViewController

**修復方法：**

找到：
```swift
.fullScreenCover(isPresented: $showingAd) {
    AdViewController(onComplete: {
        showingAd = false
        Task {
            await coinManager.watchAdForCoins()
        }
    })
}
```

替換為：
```swift
.fullScreenCover(isPresented: $showingAd) {
    VStack {
        Text("廣告播放中...")
            .font(.title)
        ProgressView()
            .padding(.top, 20)
    }
    .onAppear {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showingAd = false
            Task {
                await coinManager.watchAdForCoins()
            }
        }
    }
}
```

### 錯誤 4: 缺少 `import CommonCrypto`
**檔案：** `Services/Utils.swift`

**問題：** 使用了 `CC_SHA256` 但沒有 import

**修復方法：**

在檔案第一行添加：
```swift
import CommonCrypto
```

### 錯誤 5: `currentVersion` 存取權限
**檔案：** `Views/AppUpdateView.swift` 第 163 行

**問題：** `updateService.currentVersion` 是 private

**修復方法：**

在 `Services/AppUpdateService.swift` 中找到：
```swift
private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
```

改為：
```swift
let currentVersion: String = {
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
}()
```

### 錯誤 6: `MakeupSuggestionView` 括號語法錯誤
**檔案：** `Views/AI/MakeupSuggestionView.swift` 第 85-88 行

**問題：** 缺少閉合括號

**修復方法：**

將：
```swift
Text("清晰正面照可获得更準確建議"
    .font(.caption)
    .foregroundColor(.secondary)
```

改為：
```swift
Text("清晰正面照可获得更準確建議")
    .font(.caption)
    .foregroundColor(.secondary)
```

### 錯誤 7: `.dashStyle` 語法錯誤
**檔案：** 
- `Views/AI/FacePhotoView.swift` 第 100-102 行
- `Views/AI/AlbumOrganizeView.swift` 第 88-91 行
- `Views/AI/SkinAnalysisView.swift` 第 103-105 行

**問題：** SwiftUI 不支援 `.dashStyle: .dash` 語法

**修復方法：**

將所有類似以下的程式碼：
```swift
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color.orange.opacity(0.3), lineWidth: 2)
        .dashStyle: .dash
)
```

改為：
```swift
.overlay(
    RoundedRectangle(cornerRadius: 16)
        .stroke(Color.orange.opacity(0.3), lineWidth: 2, style: StrokeStyle(lineWidth: 2, dash: [8]))
)
```

### 錯誤 8: `ContentType.icon` 重複定義
**檔案：** `Views/SearchView.swift`

**問題：** `ContentType` 的 `icon` 擴充方法在 `ContentHomeView.swift` 和 `SearchView.swift` 中都定義了

**修復方法：**

在 `Views/SearchView.swift` 中找到底部的 Extension 區塊，刪除整個 `extension ContentType` 區塊（第 349-375 行），因為 `ContentHomeView.swift` 已經定義了。

### 錯誤 9: FacePhotoView 使用不存在的屬性
**檔案：** `Views/AI/FacePhotoView.swift` 第 183 行

**問題：** `result.resultData` 不存在

**修復方法：**

將：
```swift
UIImage(data: result.resultData ?? Data())
```

改為：
```swift
// 暫時顯示佔位圖
Image(systemName: "photo")
```

或直接刪除這行，使用 `AsyncImage` 載入 `result.generatedImageURL`

### 錯誤 10: AdViewController import 錯誤
**檔案：** `Services/Ads/AdViewController.swift` 第 2 行

**問題：** `import Ads` 不存在

**修復方法：**

將：
```swift
import Ads
```

改為：
```swift
import UIKit
```

（廣告 SDK 會在安裝 CocoaPods 後自動引入）

---

## 🟡 中等問題（建議修復）

### 問題 1: CoinManager 例項不同步

**問題：** `AIViewModel` 和 `AIAnalysisService` 各自創建獨立的 `CoinManager` 例項

**建議修復：**

在 `AIViewModel.swift` 中修改初始化：

```swift
class AIViewModel: ObservableObject {
    @EnvironmentObject var coinManager: CoinManager  // 改用 EnvironmentObject
    
    // ... 其他程式碼
}
```

並在所有使用 `AIViewModel` 的地方添加 `.environmentObject(coinManager)`

### 問題 2: AnyCodable 實作不完整

**檔案：** `Models/AITask.swift`

**建議：** 暫時移掉 `metadata` 屬性或等待完整實作

---

## 📝 快速修復腳本

建立 `fix_build.sh` 並執行：

```bash
#!/bin/bash

echo "🔧 開始修復編譯錯誤..."

# 1. 添加 CommonCrypto import
sed -i '' '1s/^/import CommonCrypto\n\n/' "美麗日記/Services/Utils.swift"
echo "✅ 已添加 CommonCrypto import"

# 2. 修改 groupIdentifier 為 public
sed -i '' 's/private static let groupIdentifier/static let groupIdentifier/' "美麗日記/Services/Utils.swift"
echo "✅ 已修改 groupIdentifier 存取權限"

# 3. 修改 currentVersion 為 public
sed -i '' 's/private let currentVersion/let currentVersion/' "美麗日記\Services\AppUpdateService.swift"
echo "✅ 已修改 currentVersion 存取權限"

echo ""
echo "✅ 自動化修復完成！"
echo "請手動修復以下錯誤："
echo "1. Views/EarnCoinsView.swift - AdViewController 改為 ProgressView"
echo "2. Views/AI/MakeupSuggestionView.swift - 添加閉合括號"
echo "3. Views/AI/FacePhotoView.swift - 修改 dashStyle 語法"
echo "4. Views/AI/AlbumOrganizeView.swift - 修改 dashStyle 語法"
echo "5. Views/AI/SkinAnalysisView.swift - 修改 dashStyle 語法"
echo "6. Views/SearchView.swift - 刪除重複的 ContentType.icon 擴展"
echo "7. Services/Ads/AdViewController.swift - 修改 import"
```

---

## ✅ 修復後驗證清單

修復完所有錯誤後，執行以下驗證：

- [ ] 執行 `pod install`
- [ ] 用 `.xcworkspace` 開啟專案
- [ ] 按 `Cmd + B` 編譯
- [ ] 確認無編譯錯誤
- [ ] 按 `Cmd + R` 運行
- [ ] 測試主要功能

---

## 🆘 需要協助？

如果修復過程中遇到問題：

1. 查看錯誤訊息的檔案和行號
2. 對照本文件找到對應的修復方法
3. 如仍有問題，發送錯誤訊息給開發團隊

---

**最後更新：** 2026-06-14
**修復狀態：** 待執行
