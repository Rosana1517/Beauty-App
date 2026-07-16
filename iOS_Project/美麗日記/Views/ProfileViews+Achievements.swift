import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct AchievementsView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    private let streakMilestones = [(3, "🌱"), (7, "🌿"), (14, "🌳"), (30, "🏆"), (60, "💎"), (100, "👑")]

    private var milestoneAchievements: [(title: String, detail: String, unlocked: Bool)] {
        [
            ("初次打卡", "完成第一次打卡", !store.state.punchRecords.isEmpty || store.weeklyCompletionRate.completed > 0),
            ("目標啟程", "創建第一個目標", !store.state.wishes.isEmpty || !store.state.trainingSchedule.isEmpty),
            ("週度堅持", "連續打卡 7 天", store.state.profile.streakDays >= 7),
            ("月度達人", "連續打卡 30 天", store.state.profile.streakDays >= 30)
        ]
    }

    private var specialAchievements: [(title: String, detail: String, unlocked: Bool)] {
        [
            ("美麗啟航", "使用全部分頁", store.hasUsedBeautyModule && store.hasUsedBodyModule && store.hasUsedGrowthModule),
            ("知識積累", "記錄 10 次以上", store.knowledgeRecordCount >= 10),
            ("財務管家", "記帳超過 5 筆", store.state.transactions.count >= 5),
            ("完美主義", "一天全部打卡", store.hasPerfectChecklistDay)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "成就徽章") {}

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("連續打卡")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(streakMilestones, id: \.0) { milestone in
                                let unlocked = store.state.profile.streakDays >= milestone.0
                                VStack(spacing: 4) {
                                    Text(milestone.1)
                                        .font(.title2)
                                        .opacity(unlocked ? 1 : 0.35)
                                    Text("\(milestone.0)天")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(unlocked ? "已達成" : "還差\(milestone.0 - store.state.profile.streakDays)天")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }

                achievementGroup(title: "里程碑達成", items: milestoneAchievements)
                achievementGroup(title: "特殊成就", items: specialAchievements)

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("統計總覽")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 12) {
                            statBlock(title: "連續打卡", value: "\(store.state.profile.streakDays)天")
                            statBlock(title: "知識記錄", value: "\(store.knowledgeRecordCount)次")
                            statBlock(title: "財務記錄", value: "\(store.state.transactions.count)筆")
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private func achievementGroup(title: String, items: [(title: String, detail: String, unlocked: Bool)]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(items, id: \.title) { item in
                        VStack(spacing: 6) {
                            Image(systemName: item.unlocked ? "star.fill" : "lock.fill")
                                .foregroundStyle(item.unlocked ? Color.white : AppTheme.subtext)
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(item.unlocked ? Color.white : AppTheme.text)
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(item.unlocked ? Color.white.opacity(0.85) : AppTheme.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(item.unlocked ? AppTheme.primary : AppTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}


