import Foundation

enum TransactionType: String, Codable {
    case income = "收入"
    case expense = "支出"
}

struct Transaction: Identifiable, Codable {
    var id: UUID
    var date: Date
    var type: TransactionType
    var amount: Double
    var category: String
    var account: String
    var note: String
}

struct BudgetCategory: Identifiable, Codable {
    var id: UUID
    var category: String
    var amount: Double
}

enum BeautyFundTransactionType: String, Codable {
    case deposit = "存入"
    case withdrawal = "支出"
}

struct BeautyFundTransaction: Identifiable, Codable {
    var id: UUID
    var date: Date
    var type: BeautyFundTransactionType
    var amount: Double
}

struct Wish: Identifiable, Codable {
    var id: UUID
    var name: String
    var targetAmount: Double
}

struct ShoppingItem: Identifiable, Codable {
    var id: UUID
    var name: String
    var estimatedPrice: Double
    var isPurchased: Bool
}
