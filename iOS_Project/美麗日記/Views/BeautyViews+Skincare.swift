import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct SkincareManagementView: View {
    @EnvironmentObject var store: BeautyDiaryStore
    @State var section: SkincareSection = .steps
    @State var showAddProduct = false
    @State var showAddStep = false
    @State var showSkinRecord = false
    @State var showPunch = false
    @State var editingPunch: PunchRecord?
    @State var editingSkinRecord: SkinRecord?
    @State var editingTutorialLink: TutorialLink?
    @State var editingProduct: Product?

    let concerns = ["清潔", "乾燥", "泛紅", "毛孔", "粉刺", "暗沉", "敏感", "痘痘"]

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

    func routineCard(title: String, icon: String, steps: [RoutineStep]) -> some View {
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

}
