import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct HairCareView: View {
    @EnvironmentObject var store: BeautyDiaryStore
    @State var showAdd = false
    @State var showAddProduct = false
    @State var showAddAppointment = false
    @State var editingHairProduct: Product?
    @State var editingHairCareRecord: HairCareRecord?
    @State var editingHairAppointment: Appointment?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "頭髮保養") {}

                productsCard

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("洗護週期設定")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        frequencyRow(title: "洗髮頻率", days: store.state.washFrequencyDays) {
                            store.adjustWashFrequency(by: $0)
                        }
                        frequencyRow(title: "護髮頻率", days: store.state.careFrequencyDays) {
                            store.adjustCareFrequency(by: $0)
                        }
                    }
                }

                AIAdviceSection(
                    topic: .hair,
                    title: "AI 頭皮/養髮建議",
                    subtitle: "輸入你想改善的頭髮或頭皮問題",
                    commonConcerns: ["掉髮", "頭皮屑", "毛躁", "頭皮癢", "髮質乾燥", "出油", "分岔"],
                    buttonTitle: "獲取建議"
                )

                recordsCard

                appointmentsCard
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingHairProduct) { record in
            FieldsEditSheet(
                title: "編輯護髮產品",
                fieldLabels: ["名稱", "品牌", "分類", "備註"],
                values: [record.name, record.brand, record.category, record.notes],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = record
                updated.name = values[0]
                updated.brand = values[1]
                updated.category = values[2]
                updated.notes = values[3]

                store.replaceRecord(updated, in: \.hairProducts)
            }
        }
        .sheet(item: $editingHairCareRecord) { record in
            FieldsEditSheet(
                title: "編輯護理記錄",
                fieldLabels: ["護理類型", "備註"],
                values: [record.careType, record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.careType = values[0]
                updated.note = values[1]
                updated.date = newDate
                store.replaceRecord(updated, in: \.hairCareRecords)
            }
        }
        .sheet(item: $editingHairAppointment) { record in
            FieldsEditSheet(
                title: "編輯預約",
                fieldLabels: ["標題", "店家", "備註"],
                values: [record.title, record.storeName, record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.title = values[0]
                updated.storeName = values[1]
                updated.note = values[2]
                updated.date = newDate
                store.replaceRecord(updated, in: \.hairAppointments)
            }
        }
        .sheet(isPresented: $showAdd) { AddHairCareSheet() }
        .sheet(isPresented: $showAddProduct) {
            AddProductSheet(
                onSave: { name, brand, category, notes in
                    store.addHairProduct(name: name, brand: brand, category: category, notes: notes)
                },
                title: "新增洗護產品"
            )
        }
        .sheet(isPresented: $showAddAppointment) {
            AddAppointmentSheet(
                onSave: { title, storeName, date, note in
                    store.addHairAppointment(title: title, storeName: storeName, date: date, note: note)
                },
                sheetTitle: "新增護髮療程預約"
            )
        }
    }

    private func frequencyRow(title: String, days: Int, onAdjust: @escaping (Int) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
            Spacer()
            Button {
                onAdjust(-1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(AppTheme.primary)
            }
            Text("\(days)天/次")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .frame(minWidth: 56)
            Button {
                onAdjust(1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(AppTheme.primary)
            }
        }
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct BodySkincareView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var showAddProduct = false
    @State private var editingBodyProduct: Product?
    @State private var editingBodySkinRecord: BodySkinRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "身體皮膚保養", action: "記錄") {
                    showAdd = true
                }

                AIAdviceSection(
                    topic: .bodySkin,
                    title: "AI 身體皮膚建議",
                    subtitle: "輸入身體皮膚問題，獲取產品與保養建議",
                    commonConcerns: ["乾燥脫皮", "粗糙暗沉", "背部痘痘", "手臂疹", "橘皮組織", "妊娠紋", "生長紋", "曬傷", "色素沉澱", "皮膚鬆弛"],
                    buttonTitle: "獲取 AI 推薦"
                )

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("身體保養品")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+添加") { showAddProduct = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.bodyProducts.isEmpty {
                            EmptyStateView(title: "暫無身體保養品", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.bodyProducts) { product in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(AppTheme.text)
                                        Text(product.brand.isEmpty ? "未填寫品牌" : product.brand)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingBodyProduct = product }, onDelete: {
                                        store.deleteBodyProduct(product)
                                    })
                                }
                            }
                        }
                    }
                }

                CardView {
                    if store.state.bodySkinRecords.isEmpty {
                        EmptyStateView(title: "尚無保養紀錄", subtitle: "記錄身體皮膚問題與保養進度。")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.bodySkinRecords) { record in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(record.area) · \(record.concern)")
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(AppTheme.text)
                                    Text(record.note.isEmpty ? record.date.formatted(date: .abbreviated, time: .shortened) : record.note)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingBodySkinRecord = record }, onDelete: {
                                    store.deleteBodySkinRecord(record)
                                })
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingBodyProduct) { record in
            FieldsEditSheet(
                title: "編輯身體保養品",
                fieldLabels: ["名稱", "品牌", "分類", "備註"],
                values: [record.name, record.brand, record.category, record.notes],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = record
                updated.name = values[0]
                updated.brand = values[1]
                updated.category = values[2]
                updated.notes = values[3]

                store.replaceRecord(updated, in: \.bodyProducts)
            }
        }
        .sheet(item: $editingBodySkinRecord) { record in
            FieldsEditSheet(
                title: "編輯身體肌膚紀錄",
                fieldLabels: ["部位", "困擾", "備註"],
                values: [record.area, record.concern, record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.area = values[0]
                updated.concern = values[1]
                updated.note = values[2]
                updated.date = newDate
                store.replaceRecord(updated, in: \.bodySkinRecords)
            }
        }
        .sheet(isPresented: $showAdd) { AddBodySkinRecordSheet() }
        .sheet(isPresented: $showAddProduct) {
            AddProductSheet(
                onSave: { name, brand, category, notes in
                    store.addBodyProduct(name: name, brand: brand, category: category, notes: notes)
                },
                title: "新增身體保養品"
            )
        }
    }
}
