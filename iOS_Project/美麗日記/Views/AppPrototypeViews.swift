import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("我的美麗日記")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    Text(Date.now.formatted(date: .complete, time: .omitted))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtext)
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("今日完成度")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Text("\(Int(store.progressValue * 100))%")
                                .font(.headline)
                                .foregroundStyle(AppTheme.primary)
                        }

                        ProgressView(value: store.progressValue)
                            .tint(AppTheme.primary)

                        Text("今日待完成 \(store.progressText)")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }

                sectionTitle("日常清單")
                VStack(spacing: 12) {
                    ForEach(store.state.checklistItems) { item in
                        Button {
                            store.toggleChecklist(item)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                                    .font(.title3)
                                    .foregroundStyle(item.isCompleted ? AppTheme.primary : AppTheme.subtext)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(AppTheme.text)
                                    Text(item.category)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }

                                Spacer()
                            }
                            .padding(16)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                        }
                        .buttonStyle(.plain)
                        .shadow(color: AppTheme.shadow, radius: 10, y: 5)
                    }
                }

                sectionTitle("快速入口")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    QuickLinkCard(title: "護膚管理", subtitle: "步驟、保養品、膚況追蹤", systemImage: "sparkles")
                    QuickLinkCard(title: "體態紀錄", subtitle: "體重體脂與飲食回顧", systemImage: "figure.walk")
                    QuickLinkCard(title: "閱讀追蹤", subtitle: "書單與外部連結收藏", systemImage: "book")
                    QuickLinkCard(title: "資源庫", subtitle: "匯入內容與 AI 推薦", systemImage: "folder")
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(AppTheme.text)
    }
}

struct BeautyRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "變美", subtitle: "建立你的護膚與美容管理流程")

                NavigationLink(value: BeautyRoute.skincare) {
                    HubCard(title: "護膚管理", subtitle: "護膚步驟、保養品、膚質追蹤", icon: "sparkles")
                }

                NavigationLink(value: BeautyRoute.whitening) {
                    HubCard(title: "美白計畫", subtitle: "產品使用、色號追蹤、前後對比", icon: "sun.max")
                }

                NavigationLink(value: BeautyRoute.appointments) {
                    HubCard(title: "美容預約", subtitle: "店家安排、日期提醒、服務備註", icon: "calendar")
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: BeautyRoute.self) { route in
            switch route {
            case .skincare:
                SkincareManagementView()
            case .whitening:
                WhiteningPlanView()
            case .appointments:
                BeautyAppointmentsView()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct SkincareManagementView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var section: SkincareSection = .steps
    @State private var showAddProduct = false
    @State private var showAddStep = false
    @State private var showSkinRecord = false
    @State private var showPunch = false

    private let concerns = ["清潔", "乾燥", "泛紅", "毛孔", "粉刺", "暗沉", "敏感", "痘痘"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleRow(title: "護膚管理", action: sectionActionTitle) {
                    switch section {
                    case .steps:
                        showAddStep = true
                    case .products:
                        showAddProduct = true
                    case .tracking:
                        showSkinRecord = true
                    case .history:
                        showPunch = true
                    case .tutorials, .advice:
                        break
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SkincareSection.allCases) { item in
                            chip(item.rawValue, selected: item == section) {
                                section = item
                            }
                        }
                    }
                }

                Group {
                    switch section {
                    case .steps:
                        stepsContent
                    case .products:
                        productsContent
                    case .tracking:
                        trackingContent
                    case .tutorials:
                        tutorialsContent
                    case .history:
                        historyContent
                    case .advice:
                        adviceContent
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showAddProduct) { AddProductSheet() }
        .sheet(isPresented: $showAddStep) { AddStepSheet() }
        .sheet(isPresented: $showSkinRecord) { AddSkinRecordSheet(concerns: concerns) }
        .sheet(isPresented: $showPunch) { AddPunchSheet() }
    }

    private var sectionActionTitle: String? {
        switch section {
        case .steps, .products:
            return "添加"
        case .tracking, .history:
            return "記錄"
        case .tutorials, .advice:
            return nil
        }
    }

    private var morningSteps: [RoutineStep] {
        store.state.routine.steps.filter { $0.period == .morning }
    }

    private var eveningSteps: [RoutineStep] {
        store.state.routine.steps.filter { $0.period == .evening }
    }

    private var stepsContent: some View {
        VStack(spacing: 18) {
            routineCard(title: "早間護膚", icon: "sun.max", steps: morningSteps)
            routineCard(title: "晚間護膚", icon: "moon", steps: eveningSteps)
        }
    }

    private func routineCard(title: String, icon: String, steps: [RoutineStep]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                ForEach(steps) { step in
                    HStack(spacing: 12) {
                        Button {
                            store.toggleRoutineStep(step)
                        } label: {
                            Image(systemName: step.isChecked ? "checkmark.square.fill" : "square")
                                .foregroundStyle(step.isChecked ? AppTheme.primary : AppTheme.subtext)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.name)
                                .foregroundStyle(AppTheme.text)
                            if let productName = step.productName, !productName.isEmpty {
                                Text(productName)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                        }

                        Spacer()

                        Menu(step.productName?.isEmpty == false ? "已選產品" : "選擇產品") {
                            ForEach(store.state.products) { product in
                                Button(product.name) {
                                    store.assignProduct(product.name, to: step)
                                }
                            }
                            Button("清除綁定") {
                                store.assignProduct("", to: step)
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                    }
                }
            }
        }
    }

    private var productsContent: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("我的保養品")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                if store.state.products.isEmpty {
                    EmptyStateView(title: "尚無保養品", subtitle: "新增後即可在護膚步驟中綁定。")
                } else {
                    ForEach(store.state.products) { product in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(product.name)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text("\(product.brand) · \(product.category)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                            if !product.notes.isEmpty {
                                Text(product.notes)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(AppTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteProduct(product)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var trackingContent: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("膚質追蹤")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                if !store.state.skinRecords.isEmpty {
                    ForEach(store.state.skinRecords.prefix(3)) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            InfoRow(title: "最近紀錄", value: record.skinType)
                            InfoRow(title: "主要困擾", value: record.concerns.joined(separator: "、"))
                            if !record.note.isEmpty {
                                Text(record.note)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtext)
                        }
                        .padding(14)
                        .background(AppTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .contextMenu {
                            Button(role: .destructive) {
                                store.deleteSkinRecord(record)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } else {
                    Text("目前尚無膚況紀錄，點右上角「記錄」開始建立。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtext)
                }

                WrapChips(items: concerns)
            }
        }
    }

    private var tutorialsContent: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("教程連結")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                ForEach(store.state.tutorialLinks) { link in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(link.title)
                            .foregroundStyle(AppTheme.text)
                        Text(link.url)
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(AppTheme.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var historyContent: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("打卡歷史")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                if store.state.punchRecords.isEmpty {
                    EmptyStateView(title: "暫無打卡", subtitle: "完成護膚後可補充今天的心得。")
                } else {
                    ForEach(store.state.punchRecords) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                            Text(record.summary)
                                .foregroundStyle(AppTheme.text)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(AppTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    private var adviceContent: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("AI 建議")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                ForEach(store.skincareAdvice, id: \.self) { advice in
                    Text(advice)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(AppTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }
}

struct WhiteningPlanView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "美白計畫", action: "記錄") {}

                CardView {
                    planEmptySection(title: "產品使用記錄", button: "+記錄", placeholder: "暫無記錄")
                }

                CardView {
                    planEmptySection(title: "色號追蹤", button: "+記錄", placeholder: "暫無記錄")
                }

                CardView {
                    planEmptySection(title: "前後對比照", button: "+添加", placeholder: "暫無對比照")
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private func planEmptySection(title: String, button: String, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text(button)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
            }

            EmptyStateView(title: placeholder, subtitle: "")
        }
    }
}

struct BeautyAppointmentsView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false

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
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteAppointment(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
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
        .sheet(isPresented: $showAdd) { AddAppointmentSheet() }
    }
}

struct BodyRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "體態", subtitle: "管理你的健康計畫、追蹤歷史記錄")

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
                GenericSummaryView(title: route.rawValue, subtitle: "運動類型設定、頻率規劃、歷史打卡、消耗熱量統計")
            case .shaping:
                GenericSummaryView(title: route.rawValue, subtitle: "體型目標設定、全身或局部訓練規劃、執行率")
            case .metrics:
                BodyMetricsView()
            case .meals:
                MealRecordsView()
            case .wellness:
                GenericSummaryView(title: route.rawValue, subtitle: "症狀追蹤、AI 養生建議、經期記錄、體質調養")
            case .album:
                GenericSummaryView(title: route.rawValue, subtitle: "進度照片與時間軸、對比功能")
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

struct BodyMetricsView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "體重體脂", action: "記錄") {
                    showAdd = true
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
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteBodyMetric(record)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
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
        .sheet(isPresented: $showAdd) { AddBodyMetricSheet() }
    }
}

struct MealRecordsView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "飲食記錄", action: "記錄") {
                    showAdd = true
                }

                CardView {
                    if store.state.mealRecords.isEmpty {
                        EmptyStateView(title: "尚無飲食記錄", subtitle: "寫下今天的餐點與飲食心得。")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.mealRecords) { meal in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(meal.mealType) · \(meal.summary)")
                                        .foregroundStyle(AppTheme.text)
                                    Text(meal.note.isEmpty ? meal.date.formatted(date: .abbreviated, time: .shortened) : meal.note)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteMealRecord(meal)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
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
        .sheet(isPresented: $showAdd) { AddMealSheet() }
    }
}

struct GrowthRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "成長", subtitle: "閱讀、輸入與每週整理放在同一個節奏裡")

                ForEach(GrowthRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: growthSubtitle(for: route), icon: growthIcon(for: route))
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: GrowthRoute.self) { route in
            switch route {
            case .reading:
                ReadingTrackerView()
            case .notes:
                GenericSummaryView(title: route.rawValue, subtitle: "收斂心得、行動清單、生活靈感")
            case .plan:
                GenericSummaryView(title: route.rawValue, subtitle: "本週目標、完成率、下週調整方向")
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func growthIcon(for route: GrowthRoute) -> String {
        switch route {
        case .reading:
            return "book.pages"
        case .notes:
            return "square.and.pencil"
        case .plan:
            return "calendar.badge.clock"
        }
    }

    private func growthSubtitle(for route: GrowthRoute) -> String {
        switch route {
        case .reading:
            return "書單、作者、外部連結與筆記整理"
        case .notes:
            return "收斂閱讀與生活靈感"
        case .plan:
            return "本週重點與完成率"
        }
    }
}

struct ReadingTrackerView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "閱讀追蹤", action: "添加") {
                    showAdd = true
                }

                CardView {
                    if store.state.bookRecords.isEmpty {
                        EmptyStateView(title: "暫無書籍，開始添加吧", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.bookRecords) { book in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(book.author.isEmpty ? "未填寫作者" : book.author)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    if !book.link.isEmpty {
                                        Text(book.link)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteBook(book)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
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
        .sheet(isPresented: $showAdd) { AddBookSheet() }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "我的", subtitle: store.state.profile.signature)

                CardView {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 52, height: 52)
                            .overlay(Image(systemName: "person").foregroundStyle(.white))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.state.profile.nickname)
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Text("連續打卡 \(store.state.profile.streakDays) 天")
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                        }

                        Spacer()

                        NavigationLink("編輯", value: ProfileRoute.settings)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }
                }

                ForEach(ProfileRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: profileSubtitle(for: route), icon: profileIcon(for: route))
                    }
                    .accessibilityIdentifier("profileLink_\(route.rawValue)")
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: ProfileRoute.self) { route in
            switch route {
            case .settings:
                PersonalSettingsView()
            case .customization:
                CustomizationView()
            case .resources:
                ResourceLibraryView()
            case .achievements:
                AchievementsView()
            case .export:
                DataExportView()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func profileIcon(for route: ProfileRoute) -> String {
        switch route {
        case .settings:
            return "person.crop.circle.badge.checkmark"
        case .customization:
            return "slider.horizontal.3"
        case .resources:
            return "folder"
        case .achievements:
            return "medal"
        case .export:
            return "square.and.arrow.up"
        }
    }

    private func profileSubtitle(for route: ProfileRoute) -> String {
        switch route {
        case .settings:
            return "暱稱、膚況、體質、臉型、經期設定"
        case .customization:
            return "模組開關、主題配色、通知時間"
        case .resources:
            return "小紅書、YouTube、Instagram 匯入、AI 分析、智能分類"
        case .achievements:
            return "連續打卡、里程碑達成、特殊成就"
        case .export:
            return "PDF 報告 / JSON 匯出預覽"
        }
    }
}

struct ResourceLibraryView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showImport = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "資源庫", action: "匯入精靈") {
                    showImport = true
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("匯入管線")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        Text("貼上來源連結後，自動判斷平台、抓取 metadata、進入預覽，必要時再手動補齊。")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(ImportSourceType.allCases) { source in
                                Button {
                                    showImport = true
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Image(systemName: source.systemImage)
                                            .font(.title2)
                                            .foregroundStyle(AppTheme.primary)
                                        Text(source.rawValue)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.text)
                                        Text(source.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
                                    .padding(14)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("真實資料狀態")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 10) {
                            RuntimeStatusChip(
                                title: "YouTube API",
                                active: AppRuntimeConfiguration.hasYouTubeAPI,
                                activeDetail: "正式 metadata",
                                inactiveDetail: "HTML fallback"
                            )
                            RuntimeStatusChip(
                                title: "Supabase",
                                active: AppRuntimeConfiguration.hasSupabaseConfig,
                                activeDetail: "已配置",
                                inactiveDetail: "僅本地 JSON"
                            )
                        }

                        Text("目前小紅書仍以公開頁面解析為主，YouTube 在有 `YOUTUBE_API_KEY` 時會優先走官方 Data API。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("AI 智能分析")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        if store.state.resourceItems.isEmpty {
                            EmptyStateView(title: "先導入資源再進行分析", subtitle: "")
                        } else {
                            ForEach(store.resourceRecommendations, id: \.self) { suggestion in
                                Text(suggestion)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(14)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("智能分類")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        WrapSelectableChips(items: ResourceCategory.allCases, selected: store.state.resourceFilter) { category in
                            store.setResourceFilter(category)
                        }

                        if store.filteredResources.isEmpty {
                            EmptyStateView(title: "暫無資源", subtitle: "")
                        } else {
                            ForEach(store.filteredResources) { item in
                                NavigationLink {
                                    ResourceDetailView(item: item)
                                } label: {
                                    ResourceListCard(item: item)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteResource(item)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                if !store.state.resourceImportHistory.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("最近匯入")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)

                            ForEach(store.state.resourceImportHistory.prefix(3)) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(entry.title.isEmpty ? entry.originalURL : entry.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.text)
                                            .lineLimit(1)
                                        Spacer()
                                        StatusBadge(status: entry.status)
                                    }

                                    Text("\(entry.source.rawValue) · \(entry.importedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("智能推薦")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        ForEach(store.resourceRecommendations, id: \.self) { suggestion in
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showImport, onDismiss: {
            store.clearPendingImportDraft()
        }) {
            ImportWizardSheet()
        }
    }
}

struct PersonalSettingsView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var nickname = ""
    @State private var signature = ""
    @State private var bodyFocus = ""
    @State private var skincareFocus = ""
    @State private var notificationTime = ""
    @State private var authEmail = ""
    @State private var authPassword = ""
    @State private var aiProvider: AIProviderKind = .openai
    @State private var aiAPIKey = ""
    @State private var aiBaseURL = ""
    @State private var aiModel = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "個人設定") {}

                CardView {
                    VStack(spacing: 12) {
                        ThemedTextField(title: "暱稱", text: $nickname)
                        ThemedTextField(title: "個人簡介", text: $signature)
                        ThemedTextField(title: "體態焦點", text: $bodyFocus)
                        ThemedTextField(title: "護膚焦點", text: $skincareFocus)
                        ThemedTextField(title: "通知時間", text: $notificationTime)

                        PrimaryButton(title: "儲存設定") {
                            store.updateProfile(
                                nickname: nickname,
                                signature: signature,
                                bodyFocus: bodyFocus,
                                skincareFocus: skincareFocus,
                                notificationTime: notificationTime
                            )
                        }

                        Button {
                            store.updateProfile(
                                nickname: nickname,
                                signature: signature,
                                bodyFocus: bodyFocus,
                                skincareFocus: skincareFocus,
                                notificationTime: notificationTime
                            )
                            Task {
                                await store.enableDailyReminder()
                            }
                        } label: {
                            Text("啟用每日提醒")
                                .font(.headline)
                                .foregroundStyle(AppTheme.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(AppTheme.primarySoft)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }

                AIProviderSettingsCard(
                    provider: $aiProvider,
                    apiKey: $aiAPIKey,
                    baseURL: $aiBaseURL,
                    model: $aiModel
                )
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .safeAreaInset(edge: .bottom) {
            SupabaseSyncSettingsCard(authEmail: $authEmail, authPassword: $authPassword)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(AppTheme.background.opacity(0.001))
        }
        .onAppear {
            nickname = store.state.profile.nickname
            signature = store.state.profile.signature
            bodyFocus = store.state.profile.bodyFocus
            skincareFocus = store.state.profile.skincareFocus
            notificationTime = store.state.profile.notificationTime
            authEmail = store.authSession?.email ?? ""

            let aiSettings = store.state.aiProviderSettings ?? .empty
            aiProvider = aiSettings.provider
            aiAPIKey = aiSettings.apiKey
            aiBaseURL = aiSettings.baseURL
            aiModel = aiSettings.model
        }
    }
}

struct CustomizationView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "客製化") {}

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(title: "主題配色", value: store.state.profile.themeName)
                        InfoRow(title: "通知時間", value: store.state.profile.notificationTime)
                        InfoRow(title: "體態模組", value: store.state.profile.bodyFocus)
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}

/// Lets each signed-in user bring their own AI provider (OpenAI/Anthropic
/// compatible) key instead of relying on a key shared across every
/// installation. Saved to the user's own RLS-scoped row in Supabase via
/// `BeautyDiaryStore.saveAIProviderSettings`, plus cached locally so it
/// still shows up while offline.
private struct AIProviderSettingsCard: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @Binding var provider: AIProviderKind
    @Binding var apiKey: String
    @Binding var baseURL: String
    @Binding var model: String

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("AI 解析設定")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text("接入你自己的 OpenAI 或 Anthropic 帳號，資源匯入後的 AI 分析會改用這組設定，而不是共用金鑰。金鑰只會存在你自己的帳號底下。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)

                Picker("Provider", selection: $provider) {
                    ForEach(AIProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)

                ThemedTextField(title: "API Base URL（留空使用官方端點）", text: $baseURL)
                ThemedSecureField(title: "API Key", text: $apiKey)
                ThemedTextField(title: "Model（留空使用預設）", text: $model)

                if let message = store.authMessage, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }

                PrimaryButton(title: "儲存 AI 設定") {
                    Task {
                        await store.saveAIProviderSettings(
                            AIProviderSettings(provider: provider, apiKey: apiKey, baseURL: baseURL, model: model)
                        )
                    }
                }

                if store.state.aiProviderSettings?.isConfigured == true {
                    Button {
                        Task {
                            await store.clearAIProviderSettings()
                            apiKey = ""
                            baseURL = ""
                            model = ""
                        }
                    } label: {
                        Text("移除 AI 設定")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct SupabaseSyncSettingsCard: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @Binding var authEmail: String
    @Binding var authPassword: String

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Supabase Cloud Sync")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                InfoRow(title: "Status", value: authStatusText)
                InfoRow(title: "User", value: resolvedEmail)
                InfoRow(title: "Sync User ID", value: resolvedSyncUserID)

                if let authMessage = store.authMessage, !authMessage.isEmpty {
                    Text(authMessage)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(AppTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                ThemedTextField(title: "Supabase email", text: $authEmail)
                ThemedSecureField(title: "Supabase password", text: $authPassword)

                PrimaryButton(title: "Sign in and sync") {
                    Task {
                        await store.signInToSupabase(email: authEmail, password: authPassword)
                    }
                }

                PrimaryButton(title: "Send magic link") {
                    Task {
                        await store.requestSupabaseMagicLink(email: authEmail)
                    }
                }

                PrimaryButton(title: "Sync pending resources now") {
                    Task {
                        await store.syncCloudNow()
                    }
                }

                if store.authSession != nil {
                    PrimaryButton(title: "Sign out") {
                        Task {
                            await store.signOutFromSupabase()
                        }
                    }
                }
            }
        }
    }

    private var authStatusText: String {
        switch store.authStatus {
        case .unavailable:
            return "Unavailable"
        case .signedOut:
            return "Signed out"
        case .restoring:
            return "Restoring session"
        case .authenticating:
            return "Authenticating"
        case .authenticated:
            return "Authenticated"
        }
    }

    private var resolvedEmail: String {
        let email = store.authSession?.email ?? ""
        return email.isEmpty ? "Not signed in" : email
    }

    private var resolvedSyncUserID: String {
        let sessionUserID = store.authSession?.userID ?? ""
        if !sessionUserID.isEmpty {
            return sessionUserID
        }

        let configured = AppRuntimeConfiguration.resourceSyncUserID
        return configured.isEmpty ? "Unavailable" : configured
    }
}

struct AchievementsView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "成就徽章") {}

                CardView {
                    VStack(spacing: 12) {
                        ForEach(store.state.achievements) { badge in
                            HStack(spacing: 12) {
                                Image(systemName: badge.unlocked ? "medal.fill" : "medal")
                                    .foregroundStyle(badge.unlocked ? AppTheme.primary : AppTheme.subtext)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(badge.title)
                                        .foregroundStyle(AppTheme.text)
                                    Text(badge.detail)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }

                                Spacer()
                            }
                            .padding(14)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}

struct DataExportView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var exportPreview = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "數據匯出") {}

                CardView {
                    VStack(spacing: 12) {
                        ForEach(ExportFormat.allCases) { format in
                            PrimaryButton(title: "建立 \(format.rawValue) 匯出預覽") {
                                exportPreview = store.createExport(format: format)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("匯出預覽")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text(exportPreview.isEmpty ? "尚未建立匯出預覽" : exportPreview)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}

struct GenericSummaryView: View {
    let title: String
    let subtitle: String

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: title) {}

                CardView {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtext)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}

private struct AddStepSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var period: RoutinePeriod = .morning
    @State private var name = ""

    var body: some View {
        FormSheet(title: "新增步驟") {
            Picker("時段", selection: $period) {
                ForEach(RoutinePeriod.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            ThemedTextField(title: "新增步驟", text: $name)

            PrimaryButton(title: "保存") {
                store.addRoutineStep(period: period, name: name)
                dismiss()
            }
        }
    }
}

private struct AddProductSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var name = ""
    @State private var brand = ""
    @State private var category = ""
    @State private var notes = ""

    var body: some View {
        FormSheet(title: "新增保養品") {
            ThemedTextField(title: "產品名稱", text: $name)
            ThemedTextField(title: "品牌", text: $brand)
            ThemedTextField(title: "分類", text: $category)
            ThemedTextField(title: "備註", text: $notes)

            PrimaryButton(title: "保存") {
                store.addProduct(name: name, brand: brand, category: category, notes: notes)
                dismiss()
            }
        }
    }
}

private struct AddSkinRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    let concerns: [String]

    @State private var type = "混合肌"
    @State private var selected: Set<String> = []
    @State private var note = ""

    var body: some View {
        FormSheet(title: "膚況記錄") {
            ThemedTextField(title: "膚質類型", text: $type)
            WrapToggleChips(items: concerns, selection: $selected)
            ThemedTextField(title: "補充說明", text: $note)

            PrimaryButton(title: "保存") {
                store.addSkinRecord(type: type, concerns: Array(selected), note: note)
                dismiss()
            }
        }
    }
}

private struct AddPunchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var summary = ""

    var body: some View {
        FormSheet(title: "新增打卡") {
            ThemedTextField(title: "今日心得", text: $summary)

            PrimaryButton(title: "保存") {
                store.addPunchRecord(summary: summary)
                dismiss()
            }
        }
    }
}

private struct AddAppointmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var storeName = ""
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增預約") {
            ThemedTextField(title: "服務名稱", text: $title)
            ThemedTextField(title: "店家名稱", text: $storeName)
            DatePicker("預約時間", selection: $date)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addAppointment(title: title, storeName: storeName, date: date, note: note)
                dismiss()
            }
        }
    }
}

private struct AddBodyMetricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "體重體脂記錄") {
            ThemedTextField(title: "體重 (kg)", text: $weight)
            ThemedTextField(title: "體脂 (%)", text: $bodyFat)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addBodyMetric(weight: Double(weight) ?? 0, bodyFat: Double(bodyFat) ?? 0, note: note)
                dismiss()
            }
        }
    }
}

private struct AddMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var type = "早餐"
    @State private var summary = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "飲食記錄") {
            ThemedTextField(title: "餐別", text: $type)
            ThemedTextField(title: "餐點內容", text: $summary)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addMealRecord(type: type, summary: summary, note: note)
                dismiss()
            }
        }
    }
}

private struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var author = ""
    @State private var link = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "添加書籍") {
            ThemedTextField(title: "書名", text: $title)
            ThemedTextField(title: "作者", text: $author)
            ThemedTextField(title: "外部連結", text: $link)
            ThemedTextField(title: "筆記", text: $note)

            PrimaryButton(title: "保存") {
                store.addBook(title: title, author: author, link: link, note: note)
                dismiss()
            }
        }
    }
}

private struct ImportWizardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var url = ""
    @State private var isLoading = false
    @State private var draft = ResourceImportDraft.empty(url: "")
    @State private var parseMessage = ""
    @State private var currentStep: ImportWizardStep = .input

    private enum ImportWizardStep {
        case input
        case preview
        case manual
    }

    var body: some View {
        FormSheet(title: "匯入精靈") {
            if currentStep == .input {
                VStack(alignment: .leading, spacing: 12) {
                    Text("貼上來源連結後，系統會先嘗試抓取標題、作者、縮圖、時間與內容型別。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtext)

                    ThemedTextField(title: "來源連結", text: $url)

                    if !parseMessage.isEmpty {
                        InfoCallout(title: "解析提醒", detail: parseMessage)
                    }

                    PrimaryButton(title: isLoading ? "解析中..." : "開始解析") {
                        guard !isLoading else { return }
                        Task {
                            await parseURL()
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("支援來源")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)

                            ForEach(ImportSourceType.allCases) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.systemImage)
                                        .foregroundStyle(AppTheme.primary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.rawValue)
                                            .foregroundStyle(AppTheme.text)
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            } else if currentStep == .preview {
                ImportPreviewView(draft: draft) {
                    store.saveImportedResource(draft)
                    dismiss()
                } manualAction: {
                    currentStep = .manual
                }
            } else {
                ManualCompleteView(draft: $draft) {
                    store.updateImportDraft(draft)
                    store.saveImportedResource(draft)
                    dismiss()
                }
            }
        }
        .onAppear {
            if let pending = store.state.pendingImportDraft {
                draft = pending
                url = pending.originalURL
                currentStep = pending.requiresManualCompletion ? .manual : .preview
            }
        }
    }

    private func parseURL() async {
        isLoading = true
        let parsed = await store.importResource(from: url)
        draft = parsed
        parseMessage = parsed.lastErrorMessage ?? ""
        currentStep = .preview
        isLoading = false
    }
}

private struct ImportPreviewView: View {
    let draft: ResourceImportDraft
    let saveAction: () -> Void
    let manualAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("匯入預覽")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        StatusBadge(status: draft.importStatus)
                    }

                    MetadataHero(draft: draft)

                    if !draft.missingFields.isEmpty {
                        InfoCallout(title: "待補欄位", detail: draft.missingFields.joined(separator: "、"))
                    }

                    if let lastErrorMessage = draft.lastErrorMessage, !lastErrorMessage.isEmpty {
                        InfoCallout(title: "解析提醒", detail: lastErrorMessage)
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("來源資訊")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    MetadataRow(title: "平台", value: draft.source.rawValue)
                    MetadataRow(title: "內容型別", value: draft.platformContentType.rawValue)
                    MetadataRow(title: "分類建議", value: draft.category == .all ? "待確認" : draft.category.rawValue)
                    MetadataRow(title: "作者", value: draft.authorName.isEmpty ? "待補齊" : draft.authorName)
                    MetadataRow(title: "時間", value: draft.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "未解析")
                    MetadataRow(title: "信心分數", value: "\(Int(draft.metadataConfidence * 100))%")
                }
            }

            if !draft.mediaAssets.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("媒體資產")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            MediaRetentionBadge(policy: draft.mediaRetentionPolicy)
                        }
                        Text("已識別 \(draft.mediaAssets.count) 筆媒體，預設只保存 metadata。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                        MediaAssetListView(assets: draft.mediaAssets)
                    }
                }
            }

            if let payload = draft.sourcePayloadSummary, !payload.commentsPreview.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("評論預覽")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        ForEach(payload.commentsPreview, id: \.self) { comment in
                            Text(comment)
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }

            PrimaryButton(title: "保存到資源庫") {
                saveAction()
            }

            if draft.requiresManualCompletion {
                PrimaryButton(title: "手動補齊後再保存") {
                    manualAction()
                }
            }
        }
    }
}

private struct ManualCompleteView: View {
    @Binding var draft: ResourceImportDraft
    let saveAction: () -> Void
    @State private var tagsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("手動補齊")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    Picker("來源平台", selection: $draft.source) {
                        ForEach(ImportSourceType.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    Picker("分類", selection: $draft.category) {
                        ForEach(ResourceCategory.allCases.filter { $0 != .all }) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    Picker("內容型別", selection: $draft.platformContentType) {
                        ForEach(ImportedContentType.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    Picker("媒體保存策略", selection: $draft.mediaRetentionPolicy) {
                        ForEach(MediaRetentionPolicy.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    ThemedTextField(title: "標題", text: $draft.title)
                    ThemedTextField(title: "作者", text: $draft.authorName)
                    ThemedTextField(title: "縮圖 URL", text: $draft.thumbnailURL)
                    ThemedTextField(title: "描述", text: $draft.descriptionText)
                    ThemedTextField(title: "標籤（以逗號分隔）", text: $tagsText)
                }
            }

            if !draft.mediaAssets.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("媒體選擇")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        MediaAssetSelectionList(assets: $draft.mediaAssets)
                    }
                }
            }

            if !draft.resolvedURL.isEmpty {
                CardView {
                    MetadataRow(title: "來源連結", value: draft.resolvedURL)
                }
            }

            PrimaryButton(title: "完成並保存") {
                draft.tags = tagsText
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                draft.importStatus = draft.metadataConfidence < 0.2 ? .failedFallbackSaved : .manualCompleted
                saveAction()
            }
        }
        .onAppear {
            tagsText = draft.tags.joined(separator: ", ")
        }
    }
}

private struct ResourceListCard: View {
    let item: ResourceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                    Text("\(item.source.rawValue) · \(item.platformContentType.rawValue) · \(item.category.rawValue)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }
                Spacer()
                StatusBadge(status: item.importStatus)
            }

            Text(item.displaySummary)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
                .lineLimit(2)

            HStack {
                MediaRetentionBadge(policy: item.mediaRetentionPolicy)
                if !item.selectedMediaAssets.isEmpty {
                    Text("媒體 \(item.selectedMediaAssets.count) 筆")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.subtext)
                }
                Spacer()
                if !item.temporaryMediaLeases.isEmpty {
                    Text("暫存 \(item.temporaryMediaLeases.count)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            if !item.authorName.isEmpty || !item.tags.isEmpty {
                HStack {
                    if !item.authorName.isEmpty {
                        Text("作者：\(item.authorName)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    Spacer()
                    if !item.tags.isEmpty {
                        Text(item.tags.prefix(2).joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct ResourceDetailView: View {
    let item: ResourceItem

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "資源詳情") {}

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        MetadataHero(item: item)
                        if !item.descriptionText.isEmpty {
                            Text(item.descriptionText)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("詳細欄位")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        MetadataRow(title: "平台", value: item.source.rawValue)
                        MetadataRow(title: "內容型別", value: item.platformContentType.rawValue)
                        MetadataRow(title: "解析狀態", value: item.importStatus.rawValue)
                        MetadataRow(title: "分類", value: item.category.rawValue)
                        MetadataRow(title: "作者", value: item.authorName.isEmpty ? "未提供" : item.authorName)
                        MetadataRow(title: "發佈時間", value: item.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "未解析")
                        MetadataRow(title: "原始連結", value: item.originalURL)
                        MetadataRow(title: "標準連結", value: item.canonicalURL.isEmpty ? "未提供" : item.canonicalURL)
                        MetadataRow(title: "外部 ID", value: item.externalID.isEmpty ? "未提供" : item.externalID)
                        MetadataRow(title: "媒體策略", value: item.mediaRetentionPolicy.rawValue)
                        MetadataRow(title: "媒體數量", value: "\(item.selectedMediaAssets.count)")
                        MetadataRow(title: "匯入時間", value: item.importedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                if !item.selectedMediaAssets.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("媒體清單")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            MediaAssetListView(assets: item.selectedMediaAssets)
                        }
                    }
                }

                if !item.temporaryMediaLeases.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("暫存清理狀態")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            ForEach(item.temporaryMediaLeases) { lease in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lease.storagePath)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.text)
                                            .lineLimit(1)
                                        Text("到期：\(lease.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    Spacer()
                                    Text(lease.cleanupStatus.rawValue)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                                .padding(10)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}

private struct FormSheet<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    content
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct QuickLinkCard: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(AppTheme.primary)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
            }
            .frame(maxWidth: .infinity, minHeight: 118, alignment: .leading)
        }
    }
}

private struct HubCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        CardView {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.primarySoft)
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: icon).foregroundStyle(AppTheme.primary))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.subtext)
            }
        }
    }
}

private struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: AppTheme.shadow, radius: 16, y: 8)
    }
}

private struct StatusBadge: View {
    let status: ResourceImportStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .parsed:
            return AppTheme.primary
        case .partial:
            return .orange
        case .manualCompleted:
            return .blue
        case .failedFallbackSaved:
            return .pink
        }
    }
}

private struct RuntimeStatusChip: View {
    let title: String
    let active: Bool
    let activeDetail: String
    let inactiveDetail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(active ? AppTheme.success : AppTheme.subtext)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
            }

            Text(active ? activeDetail : inactiveDetail)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct InfoCallout: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(AppTheme.text)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MediaRetentionBadge: View {
    let policy: MediaRetentionPolicy

    var body: some View {
        Text(policy.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(policyColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(policyColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var policyColor: Color {
        switch policy {
        case .metadataOnly:
            return AppTheme.primary
        case .temporaryCache:
            return .orange
        case .explicitKeep:
            return .blue
        }
    }
}

private struct MediaAssetListView: View {
    let assets: [XHSMediaAsset]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(assets) { asset in
                HStack(spacing: 12) {
                    ThumbnailPreview(thumbnailURL: asset.displayURL, size: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assetTypeLabel(asset.type))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text(asset.displayURL)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                            .lineLimit(1)
                        if let expiresAt = asset.expiresAt {
                            Text("到期：\(expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    MediaRetentionBadge(policy: asset.retentionPolicy)
                }
            }
        }
    }

    private func assetTypeLabel(_ type: XHSMediaAssetType) -> String {
        switch type {
        case .image:
            return "圖片"
        case .video:
            return "影片"
        case .cover:
            return "封面"
        case .livePhoto:
            return "LivePhoto"
        case .unknown:
            return "未知"
        }
    }
}

private struct MediaAssetSelectionList: View {
    @Binding var assets: [XHSMediaAsset]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(assets.indices), id: \.self) { index in
                Button {
                    assets[index].isSelectedForImport.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: assets[index].isSelectedForImport ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(assets[index].isSelectedForImport ? AppTheme.primary : AppTheme.subtext)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(assets[index].type.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(assets[index].displayURL)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtext)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("#\(max(assets[index].index, 0) + 1)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    .padding(12)
                    .background(AppTheme.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MetadataHero: View {
    let title: String
    let subtitle: String
    let sourceLabel: String
    let thumbnailURL: String
    let mediaAssets: [XHSMediaAsset]

    init(draft: ResourceImportDraft) {
        self.title = draft.title.isEmpty ? "尚未解析出標題" : draft.title
        self.subtitle = draft.descriptionText.isEmpty ? draft.resolvedURL : draft.descriptionText
        self.sourceLabel = "\(draft.source.rawValue) · \(draft.platformContentType.rawValue)"
        self.thumbnailURL = draft.thumbnailURL
        self.mediaAssets = draft.selectedMediaAssets.isEmpty ? draft.mediaAssets : draft.selectedMediaAssets
    }

    init(item: ResourceItem) {
        self.title = item.title
        self.subtitle = item.displaySummary
        self.sourceLabel = "\(item.source.rawValue) · \(item.platformContentType.rawValue)"
        self.thumbnailURL = item.thumbnailURL
        self.mediaAssets = item.selectedMediaAssets
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ThumbnailPreview(thumbnailURL: mediaAssets.first?.displayURL ?? thumbnailURL)

            VStack(alignment: .leading, spacing: 6) {
                Text(sourceLabel)
                    .font(.caption)
                    .foregroundStyle(AppTheme.primary)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                    .lineLimit(4)
            }
        }
    }
}

private struct ThumbnailPreview: View {
    let thumbnailURL: String
    var size: CGFloat = 92

    var body: some View {
        Group {
            if let url = URL(string: thumbnailURL), !thumbnailURL.isEmpty {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.primarySoft)
                        .overlay(ProgressView().tint(AppTheme.primary))
                }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.primarySoft)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(AppTheme.primary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .foregroundStyle(AppTheme.subtext)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110)
    }
}

private struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
    }
}

private struct ThemedTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .padding(14)
            .background(AppTheme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier(title)
    }
}

private struct ThemedSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        SecureField(title, text: $text)
            .padding(14)
            .background(AppTheme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier(title)
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.subtext)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.text)
        }
        .font(.subheadline)
    }
}

private struct WrapChips: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.primarySoft)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct WrapToggleChips: View {
    let items: [String]
    @Binding var selection: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Button {
                    if selection.contains(item) {
                        selection.remove(item)
                    } else {
                        selection.insert(item)
                    }
                } label: {
                    Text(item)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selection.contains(item) ? AppTheme.primary : AppTheme.primarySoft)
                        .foregroundStyle(selection.contains(item) ? Color.white : AppTheme.text)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct WrapSelectableChips: View {
    let items: [ResourceCategory]
    let selected: ResourceCategory
    let action: (ResourceCategory) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                Button {
                    action(item)
                } label: {
                    Text(item.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected == item ? AppTheme.primary : AppTheme.primarySoft)
                        .foregroundStyle(selected == item ? Color.white : AppTheme.text)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private func header(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(AppTheme.text)
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(AppTheme.subtext)
    }
}

private func titleRow(title: String, action: String? = nil, onTap: @escaping () -> Void = {}) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(AppTheme.text)
        Spacer()
        if let action {
            Button(action) {
                onTap()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppTheme.primary)
            .clipShape(Capsule())
            .accessibilityIdentifier(action)
        }
    }
}

private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selected ? AppTheme.primary : AppTheme.subtext)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selected ? AppTheme.card : AppTheme.primarySoft)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? AppTheme.primary.opacity(0.18) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(BeautyDiaryStore.preview)
    }
}
