import Combine
import Foundation

extension BeautyDiaryStore {
    func addTransaction(type: TransactionType, amount: Double, category: String, account: String, note: String) {
        guard amount > 0 else { return }

        state.transactions.insert(
            Transaction(id: UUID(), date: Date(), type: type, amount: amount, category: category, account: account, note: note),
            at: 0
        )
        save()
    }

    func deleteTransaction(_ transaction: Transaction) {
        state.transactions.removeAll { $0.id == transaction.id }
        save()
    }

    var currentMonthTransactions: [Transaction] {
        state.transactions.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    var monthlyIncome: Double {
        currentMonthTransactions.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var monthlyExpense: Double {
        currentMonthTransactions.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    func accountBalance(_ account: String) -> Double {
        state.transactions.filter { $0.account == account }.reduce(0) { total, transaction in
            total + (transaction.type == .income ? transaction.amount : -transaction.amount)
        }
    }

    var expenseByCategory: [(category: String, total: Double)] {
        let expenses = currentMonthTransactions.filter { $0.type == .expense }
        let grouped = Dictionary(grouping: expenses, by: \.category)
        return grouped.map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    func setBudget(category: String, amount: Double) {
        if let index = state.budgetCategories.firstIndex(where: { $0.category == category }) {
            state.budgetCategories[index].amount = amount
        } else {
            state.budgetCategories.append(BudgetCategory(id: UUID(), category: category, amount: amount))
        }
        save()
    }

    var totalBudget: Double {
        state.budgetCategories.reduce(0) { $0 + $1.amount }
    }

    var savingsRate: Double {
        guard monthlyIncome > 0 else { return 0 }
        return (monthlyIncome - monthlyExpense) / monthlyIncome
    }

    var beautyFundBalance: Double {
        state.beautyFundTransactions.reduce(0) { total, transaction in
            total + (transaction.type == .deposit ? transaction.amount : -transaction.amount)
        }
    }

    func addBeautyFundTransaction(type: BeautyFundTransactionType, amount: Double) {
        guard amount > 0 else { return }

        state.beautyFundTransactions.append(BeautyFundTransaction(id: UUID(), date: Date(), type: type, amount: amount))
        save()
    }

    func addWish(name: String, targetAmount: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.wishes.append(Wish(id: UUID(), name: trimmed, targetAmount: targetAmount))
        save()
    }

    func deleteWish(_ wish: Wish) {
        state.wishes.removeAll { $0.id == wish.id }
        save()
    }

    func addShoppingItem(name: String, estimatedPrice: Double) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.shoppingItems.append(ShoppingItem(id: UUID(), name: trimmed, estimatedPrice: estimatedPrice, isPurchased: false))
        save()
    }

    func toggleShoppingItem(_ item: ShoppingItem) {
        guard let index = state.shoppingItems.firstIndex(where: { $0.id == item.id }) else { return }
        state.shoppingItems[index].isPurchased.toggle()
        save()
    }

    func deleteShoppingItem(_ item: ShoppingItem) {
        state.shoppingItems.removeAll { $0.id == item.id }
        save()
    }

}
