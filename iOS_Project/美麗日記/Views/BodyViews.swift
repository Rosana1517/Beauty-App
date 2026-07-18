import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct BodyRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "體態", subtitle: "管理你的健康計畫、追蹤歷史記錄")

                GoalAdviceCard(area: "體態", topic: .exercise)

                ForEach(BodyRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: bodySubtitle(for: route), icon: bodyIcon(for: route))
                    }
                    .accessibilityIdentifier("bodyLink_\(route.rawValue)")
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: BodyRoute.self) { route in
            switch route {
            case .exercise:
                ExercisePunchView()
            case .shaping:
                ShapingPlanView()
            case .metrics:
                BodyMetricsView()
            case .meals:
                MealRecordsView()
            case .wellness:
                WellnessView()
            case .album:
                BodyAlbumView()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func bodyIcon(for route: BodyRoute) -> String {
        switch route {
        case .exercise:
            return "dumbbell"
        case .shaping:
            return "target"
        case .metrics:
            return "chart.line.uptrend.xyaxis"
        case .meals:
            return "fork.knife"
        case .wellness:
            return "heart.text.square"
        case .album:
            return "camera"
        }
    }

    private func bodySubtitle(for route: BodyRoute) -> String {
        switch route {
        case .exercise:
            return "運動類型設定、燃脂規劃、歷史打卡、消耗熱量統計"
        case .shaping:
            return "體型目標設定、全身或局部訓練規劃、執行率"
        case .metrics:
            return "數據記錄、曲線圖表、圍度變化"
        case .meals:
            return "熱量與營養素記錄、食譜收藏、AI 飲食建議"
        case .wellness:
            return "症狀追蹤、AI 養生建議、經期記錄、體質調養"
        case .album:
            return "進度照片與時間軸、對比功能"
        }
    }
}
