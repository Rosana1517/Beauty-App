import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct ProfileView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "我的", subtitle: store.state.profile.signature)

                CardView {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 52, height: 52)
                            .overlay(Image(systemName: "person").foregroundStyle(.white))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.state.profile.nickname)
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Text("連續打卡 \(store.state.profile.streakDays) 天")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                        }

                        Spacer()

                        NavigationLink("編輯", value: ProfileRoute.settings)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                }

                ForEach(ProfileRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: profileSubtitle(for: route), icon: profileIcon(for: route))
                    }
                    .accessibilityIdentifier("profileLink_\(route.rawValue)")
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .settings:
                PersonalSettingsView()
            case .customization:
                CustomizationView()
            case .resources:
                ResourceLibraryView()
            case .achievements:
                AchievementsView()
            case .export:
                DataExportView()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func profileIcon(for route: ProfileRoute) -> String {
        switch route {
        case .settings:
            return "person.crop.circle.badge.checkmark"
        case .customization:
            return "slider.horizontal.3"
        case .resources:
            return "folder"
        case .achievements:
            return "medal"
        case .export:
            return "square.and.arrow.up"
        }
    }

    private func profileSubtitle(for route: ProfileRoute) -> String {
        switch route {
        case .settings:
            return "暱稱、膚況、體質、臉型、經期設定"
        case .customization:
            return "模組開關、主題配色、通知時間"
        case .resources:
            return "小紅書、YouTube、Instagram 匯入、AI 分析、智能分類"
        case .achievements:
            return "連續打卡、里程碑達成、特殊成就"
        case .export:
            return "PDF 報告 / JSON 匯出預覽"
        }
    }
}
