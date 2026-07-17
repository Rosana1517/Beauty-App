import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct BudgetDashboardView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showSetBudget = false
    @State private var editingBudget: BudgetCategory?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "預算儀表板", action: "設定") {
                    showSetBudget = true
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("總預算")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtext)
                            Spacer()
                            Text("\(Int(store.totalBudget))")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                        }
                        let percent = store.totalBudget > 0 ? min(1, store.monthlyExpense / store.totalBudget) : 0
                        ProgressView(value: percent)
                            .tint(AppTheme.primary)
                        Text("已花 \(Int(store.monthlyExpense)) (\(Int(percent * 100))%)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }

                if !store.state.budgetCategories.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(store.state.budgetCategories) { budget in
                                HStack {
                                    Text(budget.category)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                    Spacer()
                                    Text("\(Int(budget.amount))")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .recordActions(onEdit: { editingBudget = budget }, onDelete: {
                                    store.removeRecord(budget, from: \.budgetCategories)
                                })
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showSetBudget) { SetBudgetSheet() }
        .sheet(item: $editingBudget) { budget in
            FieldsEditSheet(
                title: "編輯預算",
                fieldLabels: ["分類", "金額"],
                values: [budget.category, String(Int(budget.amount))],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = budget
                updated.category = values[0]
                updated.amount = Double(values[1]) ?? updated.amount
                store.replaceRecord(updated, in: \.budgetCategories)
            }
        }
    }
}

struct FinanceAIAdviceView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "AI預算建議") {}

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("你的消費概況")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("本月支出：\(Int(store.monthlyExpense)) 元")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                        Text("最大開銷：\(store.expenseByCategory.first?.category ?? "暫無數據")")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                    }
                }

                PrimaryButton(title: store.isLoadingAdvice(for: .finance) ? "正在分析…" : "獲取AI建議") {
                    let summary = store.expenseByCategory.map { "\($0.category): \(Int($0.total))元" }
                    Task { await store.requestAIAdvice(topic: .finance, concerns: summary) }
                }
                .disabled(store.isLoadingAdvice(for: .finance))

                if let errorMessage = store.errorMessage(for: .finance) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !store.suggestions(for: .finance).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.suggestions(for: .finance), id: \.self) { suggestion in
                            Text("• \(suggestion)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}
