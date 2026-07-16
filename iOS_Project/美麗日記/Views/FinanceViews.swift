import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts


struct FinanceRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "財務總覽", subtitle: "記帳、預算、消費分析、變美基金、購物清單")

                GoalAdviceCard(area: "財務", topic: .finance)

                ForEach(FinanceRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: financeSubtitle(for: route), icon: financeIcon(for: route))
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: FinanceRoute.self) { route in
            switch route {
            case .ledger:
                LedgerView()
            case .budget:
                BudgetDashboardView()
            case .aiAdvice:
                FinanceAIAdviceView()
            case .spendingAnalysis:
                SpendingAnalysisView()
            case .beautyFund:
                SavingsGoalView()
            case .shoppingList:
                ShoppingListView()
            case .financialHealth:
                FinancialHealthView()
            }
        }
    }

    private func financeIcon(for route: FinanceRoute) -> String {
        switch route {
        case .ledger: return "creditcard"
        case .budget: return "gauge"
        case .aiAdvice: return "sparkles"
        case .spendingAnalysis: return "chart.pie"
        case .beautyFund: return "diamond"
        case .shoppingList: return "cart"
        case .financialHealth: return "checkmark.shield"
        }
    }

    private func financeSubtitle(for route: FinanceRoute) -> String {
        switch route {
        case .ledger: return "收支分類、多帳戶管理"
        case .budget: return "總預算、分類預算、進度展示"
        case .aiAdvice: return "智能記帳與預算建議"
        case .spendingAnalysis: return "圖表面、趨勢面展示"
        case .beautyFund: return "專屬帳戶、心願清單"
        case .shoppingList: return "需求記錄、冷靜期標記"
        case .financialHealth: return "儲蓄率、月度報告"
        }
    }
}

struct LedgerView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var editingTransaction: Transaction?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "記帳", action: "記帳") {
                    showAdd = true
                }

                HStack(spacing: 12) {
                    statCard(title: "本月收入", value: store.monthlyIncome, color: .green)
                    statCard(title: "本月支出", value: store.monthlyExpense, color: .red)
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("帳戶")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        HStack(spacing: 12) {
                            statCard(title: "現金", value: store.accountBalance("現金"), color: AppTheme.primary)
                            statCard(title: "銀行卡", value: store.accountBalance("銀行卡"), color: AppTheme.primary)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("最近記錄")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        if store.state.transactions.isEmpty {
                            EmptyStateView(title: "暫無記錄", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.transactions) { transaction in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(transaction.category)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(AppTheme.text)
                                            Text(transaction.account)
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.subtext)
                                        }
                                        Spacer()
                                        Text("\(transaction.type == .income ? "+" : "-")\(Int(transaction.amount))")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(transaction.type == .income ? .green : .red)
                                    }
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingTransaction = transaction }) {
                                        store.deleteTransaction(transaction)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingTransaction) { record in
            FieldsEditSheet(
                title: "編輯交易",
                fieldLabels: ["金額", "分類", "帳戶", "備註"],
                values: [String(record.amount), record.category, record.account, record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.amount = Double(values[0]) ?? updated.amount
                updated.category = values[1]
                updated.account = values[2]
                updated.note = values[3]
                updated.date = newDate
                store.replaceRecord(updated, in: \.transactions)
            }
        }
        .sheet(isPresented: $showAdd) { AddTransactionSheet() }
    }

    private func statCard(title: String, value: Double, color: Color) -> some View {
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
}

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
                                .recordActions(onEdit: { editingBudget = budget }) {
                                    store.removeRecord(budget, from: \.budgetCategories)
                                }
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

struct SpendingAnalysisView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "消費分析") {}

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("本月分類支出")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        if store.expenseByCategory.isEmpty {
                            EmptyStateView(title: "暫無支出記錄", subtitle: "")
                        } else {
                            let maxTotal = store.expenseByCategory.first?.total ?? 1
                            VStack(spacing: 10) {
                                ForEach(store.expenseByCategory, id: \.category) { entry in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(entry.category)
                                                .font(.subheadline)
                                                .foregroundStyle(AppTheme.text)
                                            Spacer()
                                            Text("\(Int(entry.total))")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.primary)
                                        }
                                        GeometryReader { geo in
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(AppTheme.primary)
                                                .frame(width: geo.size.width * (entry.total / maxTotal), height: 10)
                                        }
                                        .frame(height: 10)
                                    }
                                    .padding(10)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}

struct SavingsGoalView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAddWish = false
    @State private var editingWish: Wish?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "變美基金", action: "心願") {
                    showAddWish = true
                }

                CardView {
                    VStack(spacing: 14) {
                        Text("變美基金餘額")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("\(Int(store.beautyFundBalance))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                        HStack(spacing: 16) {
                            fundButton(title: "存入") { store.addBeautyFundTransaction(type: .deposit, amount: 100) }
                            fundButton(title: "支出") { store.addBeautyFundTransaction(type: .withdrawal, amount: 100) }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [AppTheme.primary, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("心願清單")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        if store.state.wishes.isEmpty {
                            EmptyStateView(title: "暫無心願", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.wishes) { wish in
                                    HStack {
                                        Text(wish.name)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.text)
                                        Spacer()
                                        Text("目標 \(Int(wish.targetAmount))")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingWish = wish }) {
                                        store.deleteWish(wish)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingWish) { record in
            FieldsEditSheet(
                title: "編輯願望",
                fieldLabels: ["名稱", "目標金額"],
                values: [record.name, String(record.targetAmount)],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.name = values[0]
                updated.targetAmount = Double(values[1]) ?? updated.targetAmount

                store.replaceRecord(updated, in: \.wishes)
            }
        }
        .sheet(isPresented: $showAddWish) { AddWishSheet() }
    }

    private func fundButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
    }
}

struct ShoppingListView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var editingShoppingItem: ShoppingItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "購物清單", action: "添加") {
                    showAdd = true
                }

                CardView {
                    if store.state.shoppingItems.isEmpty {
                        EmptyStateView(title: "暫無購物需求", subtitle: "")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.state.shoppingItems) { item in
                                Button {
                                    store.toggleShoppingItem(item)
                                } label: {
                                    HStack {
                                        Image(systemName: item.isPurchased ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(item.isPurchased ? AppTheme.primary : AppTheme.subtext)
                                        Text(item.name)
                                            .font(.subheadline)
                                            .strikethrough(item.isPurchased)
                                            .foregroundStyle(AppTheme.text)
                                        Spacer()
                                        Text("\(Int(item.estimatedPrice))")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .recordActions(onEdit: { editingShoppingItem = item }) {
                                    store.deleteShoppingItem(item)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingShoppingItem) { record in
            FieldsEditSheet(
                title: "編輯購物項目",
                fieldLabels: ["名稱", "預估價格"],
                values: [record.name, String(record.estimatedPrice)],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.name = values[0]
                updated.estimatedPrice = Double(values[1]) ?? updated.estimatedPrice

                store.replaceRecord(updated, in: \.shoppingItems)
            }
        }
        .sheet(isPresented: $showAdd) { AddShoppingItemSheet() }
    }
}

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

