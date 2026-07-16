import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct SkincareManagementView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var section: SkincareSection = .steps
    @State private var showAddProduct = false
    @State private var showAddStep = false
    @State private var showSkinRecord = false
    @State private var showPunch = false
    @State private var editingPunch: PunchRecord?
    @State private var editingSkinRecord: SkinRecord?
    @State private var editingTutorialLink: TutorialLink?
    @State private var editingProduct: Product?

    private let concerns = ["清潔", "乾燥", "泛紅", "毛孔", "粉刺", "暗沉", "敏感", "痘痘"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleRow(title: "護膚管理", action: sectionActionTitle) {
                    switch section {
                    case .steps:
                        showAddStep = true
                    case .products:
                        showAddProduct = true
                    case .tracking:
                        showSkinRecord = true
                    case .history:
                        showPunch = true
                    case .tutorials, .advice:
                        break
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SkincareSection.allCases) { item in
                            chip(item.rawValue, selected: item == section) {
                                section = item
                            }
                        }
                    }
                }

                Group {
                    switch section {
                    case .steps:
                        stepsContent
                    case .products:
                        productsContent
                    case .tracking:
                        trackingContent
                    case .tutorials:
                        tutorialsContent
                    case .history:
                        historyContent
                    case .advice:
                        adviceContent
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingProduct) { record in
            FieldsEditSheet(
                title: "編輯保養品",
                fieldLabels: ["名稱", "品牌", "分類", "備註"],
                values: [record.name, record.brand, record.category, record.notes],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.name = values[0]
                updated.brand = values[1]
                updated.category = values[2]
                updated.notes = values[3]

                store.replaceRecord(updated, in: \.products)
            }
        }
        .sheet(isPresented: $showAddProduct) { AddProductSheet() }
        .sheet(isPresented: $showAddStep) { AddStepSheet() }
        .sheet(isPresented: $showSkinRecord) { AddSkinRecordSheet(concerns: concerns) }
        .sheet(isPresented: $showPunch) { AddPunchSheet() }
        .sheet(item: $editingPunch) { record in
            EditPunchSheet(record: record)
        }
        .sheet(item: $editingSkinRecord) { record in
            TypeNoteEditSheet(
                title: "編輯膚況紀錄",
                typeLabel: "膚質類型",
                typeOptions: ["乾性", "油性", "混合", "敏感", "中性"],
                typeValue: record.skinType,
                note: record.note
            ) { newType, newNote in
                var updated = record
                updated.skinType = newType
                updated.note = newNote
                store.replaceRecord(updated, in: \.skinRecords)
            }
        }
        .sheet(item: $editingTutorialLink) { link in
            TitleURLEditSheet(title: "編輯教程連結", itemTitle: link.title, url: link.url) { newTitle, newURL in
                var updated = link
                updated.title = newTitle
                updated.url = newURL
                store.replaceRecord(updated, in: \.tutorialLinks)
            }
        }
    }

    private var sectionActionTitle: String? {
        switch section {
        case .steps, .products:
            return "添加"
        case .tracking, .history:
            return "記錄"
        case .tutorials, .advice:
            return nil
        }
    }

    private var morningSteps: [RoutineStep] {
        store.state.routine.steps.filter { $0.period == .morning }
    }

    private var eveningSteps: [RoutineStep] {
        store.state.routine.steps.filter { $0.period == .evening }
    }

    private var stepsContent: some View {
        VStack(spacing: 18) {
            routineCard(title: "早間護膚", icon: "sun.max", steps: morningSteps)
            routineCard(title: "晚間護膚", icon: "moon", steps: eveningSteps)
        }
    }

    private func routineCard(title: String, icon: String, steps: [RoutineStep]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                ForEach(steps) { step in
                    HStack(spacing: 12) {
                        Button {
                            store.toggleRoutineStep(step)
                        } label: {
                            Image(systemName: step.isChecked ? "checkmark.square.fill" : "square")
                                .foregroundStyle(step.isChecked ? AppTheme.primary : AppTheme.subtext)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.name)
                                .foregroundStyle(AppTheme.text)
                            if let productName = step.productName, !productName.isEmpty {
                                Text(productName)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                        }

                        Spacer()

                        Menu(step.productName?.isEmpty == false ? "已選產品" : "選擇產品") {
                            ForEach(store.state.products) { product in
                                Button(product.name) {
                                    store.assignProduct(product.name, to: step)
                                }
                            }
                            Button("清除綁定") {
                                store.assignProduct("", to: step)
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                    }
                }
            }
        }
    }

    private var productsContent: some View {
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

    private var trackingContent: some View {
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

    private var tutorialsContent: some View {
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

    private var historyContent: some View {
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

    private var adviceContent: some View {
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


