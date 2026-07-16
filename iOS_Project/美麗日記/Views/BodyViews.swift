import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts


struct BodyRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "體態", subtitle: "管理你的健康計畫、追蹤歷史記錄")

                GoalAdviceCard(area: "體態", topic: .exercise)

                ForEach(BodyRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: bodySubtitle(for: route), icon: bodyIcon(for: route))
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: BodyRoute.self) { route in
            switch route {
            case .exercise:
                ExercisePunchView()
            case .shaping:
                ShapingPlanView()
            case .metrics:
                BodyMetricsView()
            case .meals:
                MealRecordsView()
            case .wellness:
                WellnessView()
            case .album:
                BodyAlbumView()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func bodyIcon(for route: BodyRoute) -> String {
        switch route {
        case .exercise:
            return "dumbbell"
        case .shaping:
            return "target"
        case .metrics:
            return "chart.line.uptrend.xyaxis"
        case .meals:
            return "fork.knife"
        case .wellness:
            return "heart.text.square"
        case .album:
            return "camera"
        }
    }

    private func bodySubtitle(for route: BodyRoute) -> String {
        switch route {
        case .exercise:
            return "運動類型設定、燃脂規劃、歷史打卡、消耗熱量統計"
        case .shaping:
            return "體型目標設定、全身或局部訓練規劃、執行率"
        case .metrics:
            return "數據記錄、曲線圖表、圍度變化"
        case .meals:
            return "熱量與營養素記錄、食譜收藏、AI 飲食建議"
        case .wellness:
            return "症狀追蹤、AI 養生建議、經期記錄、體質調養"
        case .album:
            return "進度照片與時間軸、對比功能"
        }
    }
}

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
                                    .recordActions(onEdit: { editingCustomExercise = exercise }) {
                                        store.deleteCustomExercise(exercise)
                                    }
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
                                    .recordActions(onEdit: { editingExercisePunch = record }) {
                                        store.deleteExercisePunch(record)
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
            ) { values, newDate in
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
            ) { values, newDate in
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

struct WellnessView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var section: WellnessSection = .status
    @State private var showAddSymptom = false
    @State private var improvementDirection = ""
    @State private var showAddMenstrual = false
    @State private var showAddNourishmentRecipe = false
    @State private var selectedTeaCategory: String?
    @State private var editingNourishmentRecipe: TutorialLink?
    @State private var editingMenstrualRecord: MenstrualRecord?
    @State private var editingSymptomRecord: SymptomRecord?

    private let teaCategories = ["養身", "豐胸", "瘦身", "美白", "助眠"]
    private let teaRecipeLibrary: [String: [String]] = [
        "養身": ["紅棗枸杞茶", "黃耆人蔘茶", "四物飲"],
        "豐胸": ["木瓜銀耳湯", "山藥豆漿"],
        "瘦身": ["荷葉決明子茶", "陳皮普洱茶"],
        "美白": ["玫瑰珍珠茶", "百合蓮子茶"],
        "助眠": ["甘麥大棗湯", "酸棗仁茶"]
    ]
    private let constitutions = [("寒性", "手腳冰冷‧怕冷"), ("熱性", "易上火‧口渴"), ("虛性", "易疲倦‧氣短"), ("實性", "體力充沛‧易便秘")]

    /// 把使用者已記錄的症狀歷史整理成一段脈絡，靜默併入 AI 請求，
    /// 讓建議是依照實際紀錄而非僅憑當下輸入的單一問題。
    private var symptomHistoryContext: [String] {
        guard !store.state.symptomRecords.isEmpty else { return [] }
        let recent = store.state.symptomRecords.prefix(8).map { record -> String in
            record.note.isEmpty ? record.symptom : "\(record.symptom)（\(record.note)）"
        }
        return ["我近期記錄的症狀：\(recent.joined(separator: "、"))"]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "養生健康") {}

                Picker("", selection: $section) {
                    ForEach(WellnessSection.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                switch section {
                case .status:
                    statusContent
                case .nourishment:
                    nourishmentContent
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingNourishmentRecipe) { record in
            FieldsEditSheet(
                title: "編輯食譜連結",
                fieldLabels: ["標題", "連結URL"],
                values: [record.title, record.url],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.title = values[0]
                updated.url = values[1]

                store.replaceRecord(updated, in: \.nourishmentRecipes)
            }
        }
        .sheet(item: $editingMenstrualRecord) { record in
            FieldsEditSheet(
                title: "編輯生理記錄",
                fieldLabels: ["備註"],
                values: [record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.note = values[0]
                updated.date = newDate
                store.replaceRecord(updated, in: \.menstrualRecords)
            }
        }
        .sheet(item: $editingSymptomRecord) { record in
            FieldsEditSheet(
                title: "編輯症狀記錄",
                fieldLabels: ["症狀", "備註"],
                values: [record.symptom, record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.symptom = values[0]
                updated.note = values[1]
                updated.date = newDate
                store.replaceRecord(updated, in: \.symptomRecords)
            }
        }
        .sheet(isPresented: $showAddSymptom) { AddSymptomSheet() }
        .sheet(isPresented: $showAddMenstrual) { AddMenstrualRecordSheet() }
        .sheet(isPresented: $showAddNourishmentRecipe) { AddNourishmentRecipeSheet() }
    }

    private var nourishmentContent: some View {
        VStack(spacing: 18) {
            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("AI 內調養生方案")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text("基於你的健康狀況，生成個人化養生內調方案")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)

                    if store.state.symptomRecords.isEmpty {
                        Text("尚無症狀記錄，請先在「健康狀況」Tab中記錄")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        ThemedTextField(title: "想要改善的方向，如：調理體質、養顏美容…", text: $improvementDirection)

                        PrimaryButton(title: store.isLoadingAdvice(for: .nourishment) ? "正在生成…" : "生成養生內調方案") {
                            let symptoms = store.state.symptomRecords.map(\.symptom)
                            let concerns = improvementDirection.isEmpty ? symptoms : symptoms + [improvementDirection]
                            Task { await store.requestAIAdvice(topic: .nourishment, concerns: concerns) }
                        }
                        .disabled(store.isLoadingAdvice(for: .nourishment))

                        if let errorMessage = store.errorMessage(for: .nourishment) {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        ForEach(store.suggestions(for: .nourishment), id: \.self) { suggestion in
                            Text("• \(suggestion)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("茶飲配方庫")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    HStack(spacing: 10) {
                        ForEach(teaCategories, id: \.self) { category in
                            Button {
                                selectedTeaCategory = selectedTeaCategory == category ? nil : category
                            } label: {
                                Text(category)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selectedTeaCategory == category ? Color.white : AppTheme.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTeaCategory == category ? AppTheme.primary : AppTheme.primarySoft)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if let category = selectedTeaCategory, let recipes = teaRecipeLibrary[category] {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(recipes, id: \.self) { recipe in
                                Text("· \(recipe)")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                            }
                        }
                    }
                }
            }

            CardView {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("滋補食譜庫")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("調理食譜收藏與管理")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    Spacer()
                    Button("添加") { showAddNourishmentRecipe = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }

            if !store.state.nourishmentRecipes.isEmpty {
                CardView {
                    VStack(spacing: 10) {
                        ForEach(store.state.nourishmentRecipes) { link in
                            HStack {
                                Text(link.title)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                            }
                            .padding(12)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .recordActions(onEdit: { editingNourishmentRecipe = link }) {
                                store.deleteNourishmentRecipe(link)
                            }
                        }
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("經期記錄")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Button("+記錄") { showAddMenstrual = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    if store.state.menstrualRecords.isEmpty {
                        EmptyStateView(title: "暫無經期記錄", subtitle: "")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.state.menstrualRecords) { record in
                                HStack {
                                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                    Spacer()
                                    Text(record.note)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .recordActions(onEdit: { editingMenstrualRecord = record }) {
                                    store.deleteMenstrualRecord(record)
                                }
                            }
                        }
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("體質追蹤")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(constitutions, id: \.0) { constitution in
                            let selected = store.state.bodyConstitution == constitution.0
                            Button {
                                store.setBodyConstitution(constitution.0)
                            } label: {
                                VStack(spacing: 4) {
                                    Text(constitution.0)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selected ? Color.white : AppTheme.text)
                                    Text(constitution.1)
                                        .font(.caption2)
                                        .foregroundStyle(selected ? Color.white.opacity(0.85) : AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(selected ? AppTheme.primary : AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }
        }
    }

    private var statusContent: some View {
        VStack(spacing: 18) {
            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("症狀記錄")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Button("+記錄") { showAddSymptom = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    if store.state.symptomRecords.isEmpty {
                        EmptyStateView(title: "暫無症狀記錄", subtitle: "")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.state.symptomRecords) { record in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.symptom)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(AppTheme.text)
                                    Text(record.note.isEmpty ? record.date.formatted(date: .abbreviated, time: .omitted) : record.note)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .recordActions(onEdit: { editingSymptomRecord = record }) {
                                    store.deleteSymptomRecord(record)
                                }
                            }
                        }
                    }
                }
            }

            AIAdviceSection(
                topic: .wellness,
                title: "AI 健康建議",
                subtitle: "基於當前症狀，輸入想要改善的方向，獲取個人化養生建議",
                commonConcerns: [],
                buttonTitle: "獲取 AI 養生建議",
                additionalContext: symptomHistoryContext,
                onAddRecipe: { text in
                    store.addNourishmentRecipe(title: text, url: "")
                }
            )

            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("症狀頻率統計")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    if store.symptomFrequency.isEmpty {
                        EmptyStateView(title: "暫無統計數據", subtitle: "")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.symptomFrequency, id: \.symptom) { entry in
                                HStack {
                                    Text(entry.symptom)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                    Spacer()
                                    Text("\(entry.count) 次")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }
        }
    }
}

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

