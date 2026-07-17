import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

extension HairCareView {
    var productsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("洗護產品")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    Button("+添加") { showAddProduct = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }

                if store.state.hairProducts.isEmpty {
                    EmptyStateView(title: "尚無產品", subtitle: "")
                } else {
                    VStack(spacing: 10) {
                        ForEach(store.state.hairProducts) { product in
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
                            .recordActions(onEdit: { editingHairProduct = product }, onDelete: {
                                store.deleteHairProduct(product)
                            })
                        }
                    }
                }
            }
        }
    }

    var recordsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("髮質檢測記錄")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    Button("+記錄") { showAdd = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }

                if store.state.hairCareRecords.isEmpty {
                    EmptyStateView(title: "暫無記錄", subtitle: "")
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.state.hairCareRecords) { record in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.careType)
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
                            .recordActions(onEdit: { editingHairCareRecord = record }, onDelete: {
                                store.deleteHairCareRecord(record)
                            })
                        }
                    }
                }
            }
        }
    }

    var appointmentsCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("護髮療程預約")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    Button("+預約") { showAddAppointment = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }

                if store.state.hairAppointments.isEmpty {
                    EmptyStateView(title: "暫無預約", subtitle: "")
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.state.hairAppointments) { appointment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(appointment.title) · \(appointment.storeName)")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppTheme.text)
                                Text(appointment.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .recordActions(onEdit: { editingHairAppointment = appointment }, onDelete: {
                                store.deleteHairAppointment(appointment)
                            })
                        }
                    }
                }
            }
        }
    }
}
