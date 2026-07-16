import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

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

