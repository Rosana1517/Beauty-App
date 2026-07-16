import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct BodyAlbumView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack {
                    Text("體態相簿")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text("添加照片")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(AppTheme.primary)
                            .clipShape(Capsule())
                    }
                }

                if store.state.bodyAlbumPhotos.isEmpty {
                    EmptyStateView(title: "上傳照片進行對比", subtitle: "")
                        .padding(.top, 60)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(store.state.bodyAlbumPhotos) { photo in
                            VStack(spacing: 6) {
                                if let data = photo.imageData, let uiImage = UIImage(data: data) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    store.deleteBodyAlbumPhoto(photo)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .onChange(of: photoItem) { newItem in
            Task {
                if let newItem, let data = try? await newItem.loadTransferable(type: Data.self) {
                    store.addBodyAlbumPhoto(imageData: data, note: "")
                }
            }
        }
    }
}

struct BodyMetricsView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var editingBodyMetric: BodyMetricRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "體重體脂", action: "記錄") {
                    showAdd = true
                }

                let chartRecords = store.state.bodyMetricRecords.sorted { $0.date < $1.date }
                if chartRecords.count >= 2 {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("體重趨勢")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Chart(chartRecords) { record in
                                LineMark(
                                    x: .value("日期", record.date),
                                    y: .value("體重", record.weight)
                                )
                                .foregroundStyle(AppTheme.primary)
                                .interpolationMethod(.catmullRom)
                                PointMark(
                                    x: .value("日期", record.date),
                                    y: .value("體重", record.weight)
                                )
                                .foregroundStyle(AppTheme.primary)
                            }
                            .chartYScale(domain: .automatic(includesZero: false))
                            .frame(height: 180)

                            let fatRecords = chartRecords.filter { $0.bodyFat > 0 }
                            if fatRecords.count >= 2 {
                                Text("體脂趨勢")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                Chart(fatRecords) { record in
                                    LineMark(
                                        x: .value("日期", record.date),
                                        y: .value("體脂", record.bodyFat)
                                    )
                                    .foregroundStyle(Color.orange)
                                    .interpolationMethod(.catmullRom)
                                    PointMark(
                                        x: .value("日期", record.date),
                                        y: .value("體脂", record.bodyFat)
                                    )
                                    .foregroundStyle(Color.orange)
                                }
                                .chartYScale(domain: .automatic(includesZero: false))
                                .frame(height: 160)
                            }
                        }
                    }
                }

                CardView {
                    if !store.state.bodyMetricRecords.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(store.state.bodyMetricRecords) { record in
                                VStack(alignment: .leading, spacing: 10) {
                                    InfoRow(title: "最新體重", value: String(format: "%.1f kg", record.weight))
                                    InfoRow(title: "最新體脂", value: String(format: "%.1f %%", record.bodyFat))
                                    Text(record.note.isEmpty ? "尚無補充說明" : record.note)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingBodyMetric = record }) {
                                    store.deleteBodyMetric(record)
                                }
                            }
                        }
                    } else {
                        EmptyStateView(title: "尚無數據", subtitle: "新增第一筆體重與體脂紀錄。")
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingBodyMetric) { record in
            FieldsEditSheet(
                title: "編輯體重體脂",
                fieldLabels: ["體重(kg)", "體脂(%)", "備註"],
                values: [String(record.weight), String(record.bodyFat), record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.weight = Double(values[0]) ?? updated.weight
                updated.bodyFat = Double(values[1]) ?? updated.bodyFat
                updated.note = values[2]
                updated.date = newDate
                store.replaceRecord(updated, in: \.bodyMetricRecords)
            }
        }
        .sheet(isPresented: $showAdd) { AddBodyMetricSheet() }
    }
}

