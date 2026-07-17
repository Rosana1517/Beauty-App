import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct ShapingPlanView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var weightText = ""
    @State private var bodyFatText = ""
    @State private var showAddSchedule = false
    @State private var editingTrainingItem: TrainingScheduleItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "塑型計畫") {}

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("體型目標設定")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 12) {
                            goalField(title: "目標體重", unit: "kg", text: $weightText)
                            goalField(title: "目標體脂", unit: "%", text: $bodyFatText)
                        }

                        PrimaryButton(title: "保存目標") {
                            store.setShapingGoal(targetWeight: Double(weightText), targetBodyFat: Double(bodyFatText))
                        }
                    }
                }
                .onAppear {
                    weightText = store.state.targetWeight.map { String(format: "%.1f", $0) } ?? ""
                    bodyFatText = store.state.targetBodyFat.map { String(format: "%.1f", $0) } ?? ""
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("訓練課表")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+添加") { showAddSchedule = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.trainingSchedule.isEmpty {
                            EmptyStateView(title: "暫無課表", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.trainingSchedule) { item in
                                    Text(item.name)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(AppTheme.primarySoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .recordActions(onEdit: { editingTrainingItem = item }) {
                                            store.deleteTrainingScheduleItem(item)
                                        }
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("執行率")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 12) {
                            rateStat(title: "本週", value: "\(store.exerciseCompletionRates.week)%")
                            rateStat(title: "本月", value: "\(store.exerciseCompletionRates.month)%")
                            rateStat(title: "總計", value: "\(store.exerciseCompletionRates.total)次")
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingTrainingItem) { record in
            FieldsEditSheet(
                title: "編輯訓練項目",
                fieldLabels: ["名稱"],
                values: [record.name],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = record
                updated.name = values[0]

                store.replaceRecord(updated, in: \.trainingSchedule)
            }
        }
        .sheet(isPresented: $showAddSchedule) {
            AddLinkSheet(sheetTitle: "新增訓練課表", titleFieldLabel: "課表名稱") { name, _ in
                store.addTrainingScheduleItem(name: name)
            }
        }
    }

    private func goalField(title: String, unit: String, text: Binding<String>) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
            TextField("--", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.title3.weight(.semibold))
            Text(unit)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func rateStat(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
