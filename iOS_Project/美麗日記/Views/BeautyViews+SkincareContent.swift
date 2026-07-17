import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

extension SkincareManagementView {
    var productsContent: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("我的保養品")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                if store.state.products.isEmpty {
                    EmptyStateView(title: "尚無保養品", subtitle: "新增後即可在護膚步驟中綁定。")
                } else {
                    ForEach(store.state.products) { product in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text("\(product.brand) · \(product.category)")
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
                        .recordActions(onEdit: { editingProduct = product }) {
                            store.deleteProduct(product)
                        }
                    }
                }
            }
        }
    }

    var trackingContent: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("膚質追蹤")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                if !store.state.skinRecords.isEmpty {
                    ForEach(store.state.skinRecords.prefix(3)) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            InfoRow(title: "最近紀錄", value: record.skinType)
                            InfoRow(title: "主要困擾", value: record.concerns.joined(separator: "、"))
                            if !record.note.isEmpty {
                                Text(record.note)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtext)
                        }
                        .padding(14)
                        .background(AppTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .recordActions(onEdit: { editingSkinRecord = record }) {
                            store.deleteSkinRecord(record)
                        }
                    }
                } else {
                    Text("目前尚無膚況紀錄，點右上角「記錄」開始建立。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtext)
                }

                WrapChips(items: concerns)
            }
        }
    }

    var tutorialsContent: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("教程連結")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                ForEach(store.state.tutorialLinks) { link in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(link.title)
                            .foregroundStyle(AppTheme.text)
                        Text(link.url)
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .recordActions(onEdit: { editingTutorialLink = link }) {
                        store.removeRecord(link, from: \.tutorialLinks)
                    }
                }
            }
        }
    }

    var historyContent: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("打卡歷史")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                if store.state.punchRecords.isEmpty {
                    EmptyStateView(title: "暫無打卡", subtitle: "完成護膚後可補充今天的心得。")
                } else {
                    ForEach(store.state.punchRecords) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                            Text(record.summary)
                                .foregroundStyle(AppTheme.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(AppTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .contextMenu {
                            Button {
                                editingPunch = record
                            } label: {
                                Label("編輯", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                store.removeRecord(record, from: \.punchRecords)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    var adviceContent: some View {
        VStack(spacing: 18) {
            AIAdviceSection(
                topic: .skincare,
                title: "AI 護膚建議",
                subtitle: "輸入臉部皮膚問題，AI 推薦適用產品及保養方式",
                commonConcerns: ["痘痘", "粉刺", "黑頭", "乾燥脫皮", "泛油", "泛紅", "暗沉", "毛孔粗大", "細紋", "色斑"],
                buttonTitle: "獲取 AI 護膚建議",
                onAddRoutineStep: { step in
                    store.addRoutineStep(period: .morning, name: step)
                },
                onAddProduct: { product in
                    store.addProduct(name: product, brand: "AI 推薦", category: "AI建議", notes: product)
                }
            )

            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("本地快速建議")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    ForEach(store.skincareAdvice, id: \.self) { advice in
                        Text(advice)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }
}
