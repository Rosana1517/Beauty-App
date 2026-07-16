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

