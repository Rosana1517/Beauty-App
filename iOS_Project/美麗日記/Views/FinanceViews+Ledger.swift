import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

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
