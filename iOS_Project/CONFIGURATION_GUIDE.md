# 配置指南

## 專案性質

- 這是一個依截圖重建的 `SwiftUI` 原型。
- 目前使用本地 JSON 保存，不依賴後端。

## 建議環境

- Xcode 15+
- iOS 17 模擬器或以上

## 啟動重點

- 入口：`美麗日記App.swift`
- 根視圖：`Views/ContentView.swift`
- 主分頁：`Views/MainTabView.swift`
- 主要頁面：`Views/AppPrototypeViews.swift`
- 資料層：`Services/BeautyDiaryStore.swift`

## 目前不需要

- Pod 安裝
- Firebase
- AdMob
- Replicate
- Supabase

## 補充

- 若要升級成可上線版本，再另外加入 API、登入、抓取與分享能力。
