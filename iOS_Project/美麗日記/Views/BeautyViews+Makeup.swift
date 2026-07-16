import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct MakeupInspirationView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAddInspiration = false
    @State private var editingMakeupInspiration: TutorialLink?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "妝容靈感") {}

                AIAdviceSection(
                    topic: .makeup,
                    title: "AI 妝容推薦",
                    subtitle: "輸入場合、臉型、髮型、穿搭等資訊",
                    commonConcerns: ["日常通勤", "約會", "派對", "面試", "婚禮", "晚宴", "運動", "度假", "韓系", "日系", "歐美", "中式", "自然裸妝", "甜美", "高冷", "復古"],
                    buttonTitle: "AI 推薦妝容"
                )

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("妝容收藏")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("添加") { showAddInspiration = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.makeupInspirations.isEmpty {
                            EmptyStateView(title: "暫無靈感，開始收藏吧", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.makeupInspirations) { inspiration in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(inspiration.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(AppTheme.text)
                                        if !inspiration.url.isEmpty {
                                            Text(inspiration.url)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.subtext)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingMakeupInspiration = inspiration }) {
                                        store.deleteMakeupInspiration(inspiration)
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
        .sheet(item: $editingMakeupInspiration) { record in
            FieldsEditSheet(
                title: "編輯妝容靈感",
                fieldLabels: ["標題", "連結URL"],
                values: [record.title, record.url],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.title = values[0]
                updated.url = values[1]

                store.replaceRecord(updated, in: \.makeupInspirations)
            }
        }
        .sheet(isPresented: $showAddInspiration) {
            AddLinkSheet(sheetTitle: "添加妝容靈感", titleFieldLabel: "妝容名稱") { title, url in
                store.addMakeupInspiration(title: title, url: url)
            }
        }
    }
}

struct BeautyAppointmentsView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var editingAppointment: Appointment?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "美容預約", action: "新建") {
                    showAdd = true
                }

                CardView {
                    if store.state.appointments.isEmpty {
                        EmptyStateView(title: "暫無預約", subtitle: "建立新的店家與服務安排。")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.appointments) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text("\(item.storeName) · \(item.date.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    if !item.note.isEmpty {
                                        Text(item.note)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingAppointment = item }) {
                                    store.deleteAppointment(item)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingAppointment) { record in
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
                store.replaceRecord(updated, in: \.appointments)
            }
        }
        .sheet(isPresented: $showAdd) { AddAppointmentSheet() }
    }
}


