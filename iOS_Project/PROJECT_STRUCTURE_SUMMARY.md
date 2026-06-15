# 美麗日記 iOS 重建結構摘要

## 核心檔案

- `美麗日記/Models/DiaryModels.swift`
  - 定義 `AppRoute`、`TabRoute`、資料模型、匯入來源、匯出格式
- `美麗日記/Services/BeautyDiaryStore.swift`
  - Repository 協議
  - 本地 JSON 持久化
  - `BeautyDiaryStore`
  - `MockRecommendationService`
- `美麗日記/Views/AppPrototypeViews.swift`
  - 五大分頁
  - 護膚、體態、成長、資源庫、匯出等主要頁面

## 設計方向

- 暖米白背景
- 粉棕主色
- 圓角白卡
- 低陰影
- iPhone 直式優先
