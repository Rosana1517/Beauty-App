import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct ProductLibraryView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var categoryFilter = "全部"

    private var categories: [String] {
        let set = Set(store.state.products.map(\.category)).filter { !$0.isEmpty }
        return ["全部"] + set.sorted()
    }

    private var filteredProducts: [Product] {
        guard categoryFilter != "全部" else { return store.state.products }
        return store.state.products.filter { $0.category == categoryFilter }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "產品管理庫", action: "新增產品") {
                    showAdd = true
                }

                if categories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                Button {
                                    categoryFilter = category
                                } label: {
                                    Text(category)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(categoryFilter == category ? AppTheme.primary : AppTheme.card)
                                        .foregroundStyle(categoryFilter == category ? Color.white : AppTheme.text)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                CardView {
                    if filteredProducts.isEmpty {
                        EmptyStateView(title: "尚無產品", subtitle: "新增保養品、彩妝或其他產品到管理庫。")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredProducts) { product in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(product.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(AppTheme.text)
                                        Spacer()
                                        if !product.category.isEmpty {
                                            Text(product.category)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(AppTheme.primary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(AppTheme.primarySoft)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(product.brand.isEmpty ? "未填寫品牌" : product.brand)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    if !product.notes.isEmpty {
                                        Text(product.notes)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteProduct(product)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
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
        .sheet(isPresented: $showAdd) { AddProductSheet() }
    }
}

