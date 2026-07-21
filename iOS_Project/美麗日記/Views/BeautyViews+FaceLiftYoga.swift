import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct FaceLiftYogaView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAddAction = false
    @State private var showAddRating = false
    @State private var editingFaceLiftRating: FaceLiftRatingRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "面部拉提/瑜珈") {}

                AIAdviceSection(
                    topic: .facialLift,
                    title: "AI 臉部改善建議",
                    subtitle: "輸入想改善的臉部問題",
                    commonConcerns: ["法令紋", "雙下巴", "臉頰鬆弛", "額頭紋", "魚尾紋", "嘴角下垂", "水腫", "膚色不均", "毛孔粗大", "V臉塑形"],
                    buttonTitle: "獲取 AI 推薦"
                )

                FaceExerciseMatchSection()

                NavigationLink {
                    FaceExerciseLibraryView()
                } label: {
                    CardView {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.mind.and.body")
                                .font(.title2)
                                .foregroundStyle(AppTheme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("面部動作庫")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                Text("面部瑜珈・按摩・訓練，含示範動圖與分步教學")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .buttonStyle(.plain)

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("我的動作庫")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+添加") { showAddAction = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.faceLiftActions.isEmpty {
                            EmptyStateView(title: "暫無動作", subtitle: "添加你的第一個動作吧")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.faceLiftActions) { action in
                                    Text(action.name)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(AppTheme.primarySoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                store.deleteFaceLiftAction(action)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("每日打卡")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("打卡") { store.addFaceLiftPunch() }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(AppTheme.primary)
                                .clipShape(Capsule())
                        }

                        Text("本月打卡 \(store.faceLiftPunchDaysThisMonth) 天")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 14), spacing: 6) {
                            ForEach(1...daysInCurrentMonth, id: \.self) { day in
                                Circle()
                                    .fill(isDayPunched(day) ? AppTheme.primary : AppTheme.primarySoft)
                                    .frame(width: 16, height: 16)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("緊緻度評分歷史")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+評分") { showAddRating = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.faceLiftRatings.isEmpty {
                            EmptyStateView(title: "暫無評分記錄", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.faceLiftRatings) { rating in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("\(rating.score) 分")
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(AppTheme.text)
                                            Text(rating.note.isEmpty ? rating.date.formatted(date: .abbreviated, time: .omitted) : rating.note)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.subtext)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingFaceLiftRating = rating }, onDelete: {
                                        store.deleteFaceLiftRating(rating)
                                    })
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingFaceLiftRating) { record in
            FieldsEditSheet(
                title: "編輯效果評分",
                fieldLabels: ["評分(1-5)", "備註"],
                values: [String(record.score), record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.score = min(5, max(1, Int(values[0]) ?? updated.score))
                updated.note = values[1]
                updated.date = newDate
                store.replaceRecord(updated, in: \.faceLiftRatings)
            }
        }
        .sheet(isPresented: $showAddAction) { AddFaceLiftActionSheet() }
        .sheet(isPresented: $showAddRating) { AddFaceLiftRatingSheet() }
    }

    private var daysInCurrentMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
    }

    private func isDayPunched(_ day: Int) -> Bool {
        let calendar = Calendar.current
        let now = Date()
        return store.state.faceLiftPunches.contains { punch in
            calendar.isDate(punch.date, equalTo: now, toGranularity: .month)
                && calendar.dateComponents([.day], from: punch.date).day == day
        }
    }
}
