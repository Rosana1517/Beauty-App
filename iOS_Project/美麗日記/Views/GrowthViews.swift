import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts


struct GrowthRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "成長", subtitle: "閱讀、輸入與每週整理放在同一個節奏裡")

                GoalAdviceCard(area: "成長", topic: .wellness)

                ForEach(GrowthRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: growthSubtitle(for: route), icon: growthIcon(for: route))
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: GrowthRoute.self) { route in
            switch route {
            case .reading:
                ReadingTrackerView()
            case .courses:
                CourseTrackerView()
            case .notes:
                KnowledgeNotesView()
            case .videos:
                VideoLearningView()
            case .dailyQuote:
                DailyQuoteView()
            case .moodTracking:
                MoodTrackingView()
            case .finance:
                FinanceRootView()
            case .goals:
                GoalManagementView()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func growthIcon(for route: GrowthRoute) -> String {
        switch route {
        case .reading:
            return "book.pages"
        case .courses:
            return "graduationcap"
        case .notes:
            return "doc.text"
        case .videos:
            return "play.rectangle"
        case .dailyQuote:
            return "text.bubble"
        case .moodTracking:
            return "heart"
        case .finance:
            return "wallet.pass"
        case .goals:
            return "scope"
        }
    }

    private func growthSubtitle(for route: GrowthRoute) -> String {
        switch route {
        case .reading:
            return "書單、進度、筆記、時長統計"
        case .courses:
            return "課程庫、進度看板、技能樹、證書存檔"
        case .notes:
            return "文章收藏、標籤、搜尋、知識圖譜"
        case .videos:
            return "追蹤、時間戳筆記、頻道訂閱"
        case .dailyQuote:
            return "語錄庫、自我肯定、願景板、感恩日記"
        case .moodTracking:
            return "情緒日記、週期分析、心情曲線"
        case .finance:
            return "記帳、預算、消費分析、變美基金、購物清單"
        case .goals:
            return "主題模板、里程碑、產品推薦、資源整合"
        }
    }
}

