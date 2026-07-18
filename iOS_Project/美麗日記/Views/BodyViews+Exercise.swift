import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct ExercisePunchView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var selectedCategory: String?
    @State private var durationText = ""
    @State private var showAddExercise = false
    @State private var editingCustomExercise: CustomExercise?
    @State private var editingExercisePunch: ExercisePunchRecord?
    @State private var viewingExerciseTutorial: ResourceItem?

    private let categories = ["有氧", "力量", "瑜珈", "HIIT", "拉伸", "核心"]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "運動塑型打卡") {}

                AIAdviceSection(
                    topic: .exercise,
                    title: "AI 運動推薦",
                    subtitle: "輸入想訓練的部位或想改善的外型問題",
                    commonConcerns: ["瘦大腿", "瘦小腿", "翹臀", "假胯寬", "骨盆前傾", "駝背", "腰腹", "副乳", "拉伸放鬆"],
                    buttonTitle: "獲取推薦",
                    onAddExercise: { resource in
                        store.addCustomExercise(name: resource.title, linkedResourceRemoteID: resource.id)
                    }
                )

                CardView {
                    NavigationLink {
                        ExerciseMatchView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "wand.and.stars")
                                .font(.title3)
                                .foregroundStyle(AppTheme.primary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("AI 動作匹配")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                Text("輸入需求,AI 從資料庫挑出最適合你的動作組合")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                    .buttonStyle(.plain)
                }

                CardView {
                    NavigationLink {
                        ExerciseLibraryView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "books.vertical.fill")
                                .font(.title3)
                                .foregroundStyle(AppTheme.primary)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("運動資料庫")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                Text("1,300+ 健身動作與瑜伽體式,繁中教學 + GIF 示範")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                    .buttonStyle(.plain)
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("今日運動")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                Button {
                                    selectedCategory = category
                                } label: {
                                    Text(category)
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(selectedCategory == category ? AppTheme.primary : AppTheme.primarySoft)
                                        .foregroundStyle(selectedCategory == category ? Color.white : AppTheme.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            ThemedTextField(title: "時長(分鐘)", text: $durationText)
                                .keyboardType(.numberPad)
                            Button("打卡") {
                                guard let category = selectedCategory, let duration = Int(durationText) else { return }
                                store.addExercisePunch(category: category, durationMinutes: duration)
                                durationText = ""
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(AppTheme.primary)
                            .clipShape(Capsule())
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("自訂運動")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+添加") { showAddExercise = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.customExercises.isEmpty {
                            EmptyStateView(title: "暫無自訂運動", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.customExercises) { exercise in
                                    HStack(spacing: 8) {
                                        Text(exercise.name)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.text)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        if let remoteID = exercise.linkedResourceRemoteID {
                                            Button {
                                                if let item = store.resourceItem(remoteID: remoteID) {
                                                    viewingExerciseTutorial = item
                                                }
                                            } label: {
                                                Label("教學", systemImage: "book.fill")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(AppTheme.primary)
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingCustomExercise = exercise }, onDelete: {
                                        store.deleteCustomExercise(exercise)
                                    })
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        NavigationLink(value: BodyRoute.shaping) {
                            HStack {
                                Text("塑型計畫")
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(AppTheme.subtext)
                            }
                        }

                        if store.state.targetWeight == nil && store.state.trainingSchedule.isEmpty {
                            EmptyStateView(title: "暫無計畫", subtitle: "")
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("打卡記錄")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        if store.state.exercisePunches.isEmpty {
                            EmptyStateView(title: "暫無記錄", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.exercisePunches) { record in
                                    HStack {
                                        Text("\(record.category) · \(record.durationMinutes) 分鐘")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.text)
                                        Spacer()
                                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingExercisePunch = record }, onDelete: {
                                        store.deleteExercisePunch(record)
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
        .sheet(item: $viewingExerciseTutorial) { item in
            NavigationStack {
                ResourceDetailView(item: item)
                    .background(AppTheme.background)
            }
        }
        .sheet(item: $editingCustomExercise) { record in
            FieldsEditSheet(
                title: "編輯自訂運動",
                fieldLabels: ["名稱"],
                values: [record.name],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = record
                updated.name = values[0]

                store.replaceRecord(updated, in: \.customExercises)
            }
        }
        .sheet(item: $editingExercisePunch) { record in
            FieldsEditSheet(
                title: "編輯運動打卡",
                fieldLabels: ["類型", "時長(分鐘)"],
                values: [record.category, String(record.durationMinutes)],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.category = values[0]
                updated.durationMinutes = Int(values[1]) ?? updated.durationMinutes
                updated.date = newDate
                store.replaceRecord(updated, in: \.exercisePunches)
            }
        }
        .sheet(isPresented: $showAddExercise) {
            AddLinkSheet(sheetTitle: "新增自訂運動", titleFieldLabel: "運動名稱") { name, _ in
                store.addCustomExercise(name: name)
            }
        }
    }
}
