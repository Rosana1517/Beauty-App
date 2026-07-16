import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct MealRecordsView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var showAddRecipe = false
    @State private var editingFavoriteRecipe: TutorialLink?
    @State private var editingMeal: MealRecord?
    @State private var addedDietSuggestions: Set<String> = []
    @State private var showTDEESetup = false

    private var todaysMealSummaries: [String] {
        let summary = store.todayCalorieSummary()
        var lines = summary.meals.map { meal -> String in
            let calorieText = meal.calories.map { "約 \($0) 大卡" } ?? "熱量未知"
            return "\(meal.mealType): \(meal.summary)（\(calorieText)）"
        }
        if summary.total > 0 {
            lines.append("今日總熱量約 \(summary.total) 大卡")
        }
        let goal = store.areaGoal("體態")
        if !goal.isEmpty {
            lines.append("我的體態目標：\(goal)")
        }
        return lines
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "飲食記錄", action: "記錄") {
                    showAdd = true
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("今日熱量攝取")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button(store.dailyCalorieTarget() == nil ? "設定目標" : "調整目標") {
                                showTDEESetup = true
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                        }

                        let summary = store.todayCalorieSummary()
                        let target = store.dailyCalorieTarget()

                        if summary.meals.isEmpty {
                            Text("今天還沒有記錄，新增餐點後自動統計熱量。")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(summary.total)")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundStyle(AppTheme.primary)
                                if let target {
                                    Text("/ \(target) 大卡")
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.subtext)
                                } else {
                                    Text("大卡（\(summary.meals.count) 餐）")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                            }
                            if let target {
                                let remaining = target - summary.total
                                ProgressView(value: Double(min(summary.total, target)), total: Double(target))
                                    .tint(remaining >= 0 ? AppTheme.primary : .orange)
                                Text(remaining >= 0 ? "還可攝取 \(remaining) 大卡" : "已超標 \(-remaining) 大卡")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(remaining >= 0 ? AppTheme.subtext : .orange)
                            }
                            if summary.meals.contains(where: { $0.calories == nil }) {
                                Text("部分餐點未有熱量，總數僅供參考；長按餐點可補填。")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }

                        let dailyTotals = store.dailyCalorieTotals()
                        if dailyTotals.contains(where: { $0.calories > 0 }) {
                            Chart {
                                ForEach(dailyTotals, id: \.date) { entry in
                                    BarMark(
                                        x: .value("日期", entry.date, unit: .day),
                                        y: .value("大卡", entry.calories)
                                    )
                                    .foregroundStyle(AppTheme.primary.opacity(0.75))
                                }
                                if let target {
                                    RuleMark(y: .value("目標", target))
                                        .foregroundStyle(.orange)
                                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4]))
                                        .annotation(position: .top, alignment: .trailing) {
                                            Text("目標 \(target)")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisValueLabel(format: .dateTime.day())
                                }
                            }
                            .frame(height: 150)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                CardView {
                    if store.state.mealRecords.isEmpty {
                        EmptyStateView(title: "尚無飲食記錄", subtitle: "寫下今天的餐點與飲食心得。")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.mealRecords) { meal in
                                HStack(spacing: 10) {
                                    if let data = meal.photoData, let image = UIImage(data: data) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 52, height: 52)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(meal.mealType) · \(meal.summary)")
                                            .foregroundStyle(AppTheme.text)
                                        HStack(spacing: 6) {
                                            if let calories = meal.calories {
                                                Text("\(calories) 大卡")
                                                    .font(.caption.weight(.semibold))
                                                    .foregroundStyle(AppTheme.primary)
                                            }
                                            Text(meal.note.isEmpty ? meal.date.formatted(date: .abbreviated, time: .shortened) : meal.note)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.subtext)
                                        }
                                    }
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingMeal = meal }) {
                                    store.deleteMealRecord(meal)
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("AI 飲食建議")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("依今日餐點、熱量攝取與體態目標，生成後續飲食建議")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)

                        PrimaryButton(title: store.isLoadingAdvice(for: .diet) ? "正在分析…" : "分析熱量並建議後續飲食") {
                            Task { await store.requestAIAdvice(topic: .diet, concerns: todaysMealSummaries) }
                        }
                        .disabled(store.isLoadingAdvice(for: .diet))

                        if let errorMessage = store.errorMessage(for: .diet) {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        if !store.suggestions(for: .diet).isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(store.suggestions(for: .diet), id: \.self) { suggestion in
                                    HStack(alignment: .top, spacing: 10) {
                                        Text("• \(suggestion)")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.text)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button(addedDietSuggestions.contains(suggestion) ? "已加入" : "加入收藏食譜") {
                                            store.addFavoriteRecipe(title: suggestion, url: "")
                                            addedDietSuggestions.insert(suggestion)
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(addedDietSuggestions.contains(suggestion) ? AppTheme.subtext : AppTheme.primary)
                                        .disabled(addedDietSuggestions.contains(suggestion))
                                    }
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("收藏食譜")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("添加") { showAddRecipe = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.favoriteRecipes.isEmpty {
                            EmptyStateView(title: "暫無食譜", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.favoriteRecipes) { recipe in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(recipe.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(AppTheme.text)
                                        if !recipe.url.isEmpty {
                                            Text(recipe.url)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.subtext)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingFavoriteRecipe = recipe }) {
                                        store.deleteFavoriteRecipe(recipe)
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
        .sheet(item: $editingMeal) { meal in
            FieldsEditSheet(
                title: "編輯飲食記錄",
                fieldLabels: ["餐別", "餐點內容", "備註", "熱量（大卡）"],
                values: [meal.mealType, meal.summary, meal.note, meal.calories.map(String.init) ?? ""],
                showsDate: true,
                date: meal.date
            ) { values, newDate in
                var updated = meal
                updated.mealType = values[0]
                updated.summary = values[1]
                updated.note = values[2]
                updated.calories = Int(values[3]) ?? CalorieEstimator.estimate(from: values[1])
                updated.date = newDate
                store.replaceRecord(updated, in: \.mealRecords)
            }
        }
        .sheet(item: $editingFavoriteRecipe) { record in
            FieldsEditSheet(
                title: "編輯收藏食譜",
                fieldLabels: ["標題", "連結URL"],
                values: [record.title, record.url],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.title = values[0]
                updated.url = values[1]

                store.replaceRecord(updated, in: \.favoriteRecipes)
            }
        }
        .sheet(isPresented: $showAdd) { AddMealSheet() }
        .sheet(isPresented: $showTDEESetup) { TDEESetupSheet() }
        .sheet(isPresented: $showAddRecipe) {
            AddLinkSheet(sheetTitle: "添加食譜", titleFieldLabel: "食譜名稱") { title, url in
                store.addFavoriteRecipe(title: title, url: url)
            }
        }
    }
}

