import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct WhiteningPlanView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAddUsage = false
    @State private var showAddShade = false
    @State private var showAddPhoto = false
    @State private var editingWhiteningUsage: WhiteningProductUsage?
    @State private var editingShadeRecord: ShadeTrackingRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "美白計畫") {}

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        planHeader(title: "產品使用記錄", button: "+記錄") { showAddUsage = true }

                        if store.state.whiteningProductUsages.isEmpty {
                            EmptyStateView(title: "暫無記錄", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.whiteningProductUsages) { record in
                                    planRow(
                                        title: record.productName,
                                        subtitle: record.note.isEmpty ? record.date.formatted(date: .abbreviated, time: .omitted) : record.note,
                                        onEdit: { editingWhiteningUsage = record },
                                        onDelete: { store.deleteWhiteningProductUsage(record) }
                                    )
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        planHeader(title: "色號追蹤", button: "+記錄") { showAddShade = true }

                        if store.state.shadeTrackingRecords.isEmpty {
                            EmptyStateView(title: "暫無記錄", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.shadeTrackingRecords) { record in
                                    planRow(
                                        title: record.shadeName,
                                        subtitle: record.note.isEmpty ? record.date.formatted(date: .abbreviated, time: .omitted) : record.note,
                                        onEdit: { editingShadeRecord = record },
                                        onDelete: { store.deleteShadeTrackingRecord(record) }
                                    )
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        planHeader(title: "前後對比照", button: "+添加") { showAddPhoto = true }

                        if store.state.beforeAfterPhotos.isEmpty {
                            EmptyStateView(title: "暫無對比照", subtitle: "")
                        } else {
                            VStack(spacing: 12) {
                                ForEach(store.state.beforeAfterPhotos) { pair in
                                    HStack(spacing: 12) {
                                        photoThumbnail(pair.beforeImageData, label: "前")
                                        photoThumbnail(pair.afterImageData, label: "後")
                                        Spacer()
                                        Text(pair.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    .padding(10)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions {
                                        store.deleteBeforeAfterPhoto(pair)
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
        .sheet(item: $editingWhiteningUsage) { record in
            FieldsEditSheet(
                title: "編輯美白產品使用",
                fieldLabels: ["產品名稱", "備註"],
                values: [record.productName, record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.productName = values[0]
                updated.note = values[1]
                updated.date = newDate
                store.replaceRecord(updated, in: \.whiteningProductUsages)
            }
        }
        .sheet(item: $editingShadeRecord) { record in
            FieldsEditSheet(
                title: "編輯色號追蹤",
                fieldLabels: ["色號", "備註"],
                values: [record.shadeName, record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.shadeName = values[0]
                updated.note = values[1]
                updated.date = newDate
                store.replaceRecord(updated, in: \.shadeTrackingRecords)
            }
        }
        .sheet(isPresented: $showAddUsage) { AddWhiteningProductUsageSheet() }
        .sheet(isPresented: $showAddShade) { AddShadeTrackingSheet() }
        .sheet(isPresented: $showAddPhoto) { AddBeforeAfterPhotoSheet() }
    }

    private func planHeader(title: String, button: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            Spacer()
            Button(button, action: action)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
        }
    }

    private func planRow(title: String, subtitle: String, onEdit: (() -> Void)? = nil, onDelete: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(AppTheme.text)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .recordActions(onEdit: onEdit, onDelete: onDelete)
    }

    @ViewBuilder
    private func photoThumbnail(_ data: Data?, label: String) -> some View {
        VStack(spacing: 4) {
            if let data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppTheme.card)
                    .frame(width: 64, height: 64)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtext)
        }
    }
}
