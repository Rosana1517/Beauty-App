import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

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
