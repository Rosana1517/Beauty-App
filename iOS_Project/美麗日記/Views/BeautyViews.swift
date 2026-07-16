import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts


struct BeautyRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "變美", subtitle: "建立你的護膚與美容管理流程")

                GoalAdviceCard(area: "變美", topic: .skincare)

                ForEach(BeautyRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: beautySubtitle(for: route), icon: beautyIcon(for: route))
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: BeautyRoute.self) { route in
            switch route {
            case .skincare:
                SkincareManagementView()
            case .hairCare:
                HairCareView()
            case .whitening:
                WhiteningPlanView()
            case .faceLift:
                FaceLiftYogaView()
            case .hairstyleMatch:
                HairstyleMatchView()
            case .bodySkincare:
                BodySkincareView()
            case .productLibrary:
                ProductLibraryView()
            case .appointments:
                BeautyAppointmentsView()
            case .makeupInspiration:
                MakeupInspirationView()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func beautyIcon(for route: BeautyRoute) -> String {
        switch route {
        case .skincare:
            return "sparkles"
        case .hairCare:
            return "comb"
        case .whitening:
            return "sun.max"
        case .faceLift:
            return "face.smiling"
        case .hairstyleMatch:
            return "person.crop.circle"
        case .bodySkincare:
            return "figure.arms.open"
        case .productLibrary:
            return "shippingbox"
        case .appointments:
            return "calendar"
        case .makeupInspiration:
            return "paintpalette"
        }
    }

    private func beautySubtitle(for route: BeautyRoute) -> String {
        switch route {
        case .skincare:
            return "護膚步驟、保養品、膚質追蹤"
        case .hairCare:
            return "洗護週期設定、髮質檢測、護髮療程預約"
        case .whitening:
            return "產品使用記錄、色號追蹤、前後對比"
        case .faceLift:
            return "動作課表、每日打卡、緊緻度評分歷史"
        case .hairstyleMatch:
            return "臉型設定、髮型收藏、試髮型對比"
        case .bodySkincare:
            return "身體皮膚問題、AI產品推薦、保養記錄"
        case .productLibrary:
            return "產品庫存、成分記錄、空瓶提醒、使用週期"
        case .appointments:
            return "店家安排、日期提醒、服務備註"
        case .makeupInspiration:
            return "妝容收藏、產品試色、妝容打卡"
        }
    }
}

