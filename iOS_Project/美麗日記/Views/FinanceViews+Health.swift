import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct FinancialHealthView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    private var fixedExpenseRatio: Int {
        guard store.monthlyExpense > 0 else { return 0 }
        let fixed = store.state.transactions
            .filter { $0.type == .expense && $0.category == "固定支出" }
            .reduce(0) { $0 + $1.amount }
        return Int(fixed / store.monthlyExpense * 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "財務健康評估") {}

                CardView {
                    VStack(spacing: 6) {
                        Text("儲蓄率")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                        Text(String(format: "%.1f%%", store.savingsRate * 100))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(store.savingsRate < 0.2 ? .red : .green)
                        Text(store.savingsRate < 0.2 ? "需改善" : "狀態良好")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 12) {
                    healthStat(title: "月收入", value: store.monthlyIncome, color: .green)
                    healthStat(title: "月支出", value: store.monthlyExpense, color: .red)
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("月度報告")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        reportRow(title: "固定支出佔比", value: "\(fixedExpenseRatio)%")
                        reportRow(title: "可自由支配", value: "\(Int(store.monthlyIncome - store.monthlyExpense)) 元")
                        reportRow(title: "建議儲蓄", value: "\(Int(store.monthlyIncome * 0.2)) 元")
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("改善建議")
                            .font(.headline)
                            .foregroundStyle(AppTheme.primary)
                        ForEach(healthAdvice, id: \.self) { advice in
                            Text("· \(advice)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private var healthAdvice: [String] {
        var advice: [String] = []
        if store.savingsRate < 0.2 {
            advice.append("建議將儲蓄率提升至20%以上")
        }
        if store.monthlyExpense > store.monthlyIncome {
            advice.append("支出過高，建議削減非必要消費")
        }
        advice.append("每月固定存入變美基金，積少成多")
        advice.append("區分「想要」和「需要」，理性消費")
        return advice
    }

    private func healthStat(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
            Text("\(Int(value))")
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func reportRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtext)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
        }
    }
}

struct GoalManagementView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "目標管理", subtitle: "設定目標、追蹤里程碑")

                Text("快速開始")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    NavigationLink {
                        WhiteningPlanView()
                    } label: {
                        goalTemplateCard(icon: "✨", title: "美白計畫", subtitle: "3個月美白目標")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ShapingPlanView()
                    } label: {
                        goalTemplateCard(icon: "💪", title: "健身塑型", subtitle: "12週健身計畫")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ReadingTrackerView()
                    } label: {
                        goalTemplateCard(icon: "📚", title: "讀書目標", subtitle: "每月4本書")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SavingsGoalView()
                    } label: {
                        goalTemplateCard(icon: "💰", title: "儲蓄計畫", subtitle: "每月存2000")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private func goalTemplateCard(icon: String, title: String, subtitle: String) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text(icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

