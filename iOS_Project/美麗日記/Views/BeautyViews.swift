import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts


struct BeautyRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "變美", subtitle: "建立你的護膚與美容管理流程")

                GoalAdviceCard(area: "變美", topic: .skincare)

                ForEach(BeautyRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: beautySubtitle(for: route), icon: beautyIcon(for: route))
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: BeautyRoute.self) { route in
            switch route {
            case .skincare:
                SkincareManagementView()
            case .hairCare:
                HairCareView()
            case .whitening:
                WhiteningPlanView()
            case .faceLift:
                FaceLiftYogaView()
            case .hairstyleMatch:
                HairstyleMatchView()
            case .bodySkincare:
                BodySkincareView()
            case .productLibrary:
                ProductLibraryView()
            case .appointments:
                BeautyAppointmentsView()
            case .makeupInspiration:
                MakeupInspirationView()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func beautyIcon(for route: BeautyRoute) -> String {
        switch route {
        case .skincare:
            return "sparkles"
        case .hairCare:
            return "comb"
        case .whitening:
            return "sun.max"
        case .faceLift:
            return "face.smiling"
        case .hairstyleMatch:
            return "person.crop.circle"
        case .bodySkincare:
            return "figure.arms.open"
        case .productLibrary:
            return "shippingbox"
        case .appointments:
            return "calendar"
        case .makeupInspiration:
            return "paintpalette"
        }
    }

    private func beautySubtitle(for route: BeautyRoute) -> String {
        switch route {
        case .skincare:
            return "護膚步驟、保養品、膚質追蹤"
        case .hairCare:
            return "洗護週期設定、髮質檢測、護髮療程預約"
        case .whitening:
            return "產品使用記錄、色號追蹤、前後對比"
        case .faceLift:
            return "動作課表、每日打卡、緊緻度評分歷史"
        case .hairstyleMatch:
            return "臉型設定、髮型收藏、試髮型對比"
        case .bodySkincare:
            return "身體皮膚問題、AI產品推薦、保養記錄"
        case .productLibrary:
            return "產品庫存、成分記錄、空瓶提醒、使用週期"
        case .appointments:
            return "店家安排、日期提醒、服務備註"
        case .makeupInspiration:
            return "妝容收藏、產品試色、妝容打卡"
        }
    }
}

struct SkincareManagementView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var section: SkincareSection = .steps
    @State private var showAddProduct = false
    @State private var showAddStep = false
    @State private var showSkinRecord = false
    @State private var showPunch = false
    @State private var editingPunch: PunchRecord?
    @State private var editingSkinRecord: SkinRecord?
    @State private var editingTutorialLink: TutorialLink?
    @State private var editingProduct: Product?

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
        .sheet(item: $editingProduct) { record in
            FieldsEditSheet(
                title: "編輯保養品",
                fieldLabels: ["名稱", "品牌", "分類", "備註"],
                values: [record.name, record.brand, record.category, record.notes],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.name = values[0]
                updated.brand = values[1]
                updated.category = values[2]
                updated.notes = values[3]

                store.replaceRecord(updated, in: \.products)
            }
        }
        .sheet(isPresented: $showAddProduct) { AddProductSheet() }
        .sheet(isPresented: $showAddStep) { AddStepSheet() }
        .sheet(isPresented: $showSkinRecord) { AddSkinRecordSheet(concerns: concerns) }
        .sheet(isPresented: $showPunch) { AddPunchSheet() }
        .sheet(item: $editingPunch) { record in
            EditPunchSheet(record: record)
        }
        .sheet(item: $editingSkinRecord) { record in
            TypeNoteEditSheet(
                title: "編輯膚況紀錄",
                typeLabel: "膚質類型",
                typeOptions: ["乾性", "油性", "混合", "敏感", "中性"],
                typeValue: record.skinType,
                note: record.note
            ) { newType, newNote in
                var updated = record
                updated.skinType = newType
                updated.note = newNote
                store.replaceRecord(updated, in: \.skinRecords)
            }
        }
        .sheet(item: $editingTutorialLink) { link in
            TitleURLEditSheet(title: "編輯教程連結", itemTitle: link.title, url: link.url) { newTitle, newURL in
                var updated = link
                updated.title = newTitle
                updated.url = newURL
                store.replaceRecord(updated, in: \.tutorialLinks)
            }
        }
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
                        .recordActions(onEdit: { editingProduct = product }) {
                            store.deleteProduct(product)
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
                        .recordActions(onEdit: { editingSkinRecord = record }) {
                            store.deleteSkinRecord(record)
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
                    .recordActions(onEdit: { editingTutorialLink = link }) {
                        store.removeRecord(link, from: \.tutorialLinks)
                    }
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
                        .contextMenu {
                            Button {
                                editingPunch = record
                            } label: {
                                Label("編輯", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                store.removeRecord(record, from: \.punchRecords)
                            } label: {
                                Label("刪除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var adviceContent: some View {
        VStack(spacing: 18) {
            AIAdviceSection(
                topic: .skincare,
                title: "AI 護膚建議",
                subtitle: "輸入臉部皮膚問題，AI 推薦適用產品及保養方式",
                commonConcerns: ["痘痘", "粉刺", "黑頭", "乾燥脫皮", "泛油", "泛紅", "暗沉", "毛孔粗大", "細紋", "色斑"],
                buttonTitle: "獲取 AI 護膚建議",
                onAddRoutineStep: { step in
                    store.addRoutineStep(period: .morning, name: step)
                },
                onAddProduct: { product in
                    store.addProduct(name: product, brand: "AI 推薦", category: "AI建議", notes: product)
                }
            )

            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("本地快速建議")
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
}

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
                                        onEdit: { editingWhiteningUsage = record }
                                    ) { store.deleteWhiteningProductUsage(record) }
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
                                        onEdit: { editingShadeRecord = record }
                                    ) { store.deleteShadeTrackingRecord(record) }
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

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("動作庫")
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
                                    .recordActions(onEdit: { editingFaceLiftRating = rating }) {
                                        store.deleteFaceLiftRating(rating)
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

struct HairCareView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var showAddProduct = false
    @State private var showAddAppointment = false
    @State private var editingHairProduct: Product?
    @State private var editingHairCareRecord: HairCareRecord?
    @State private var editingHairAppointment: Appointment?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "頭髮保養") {}

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
                                    .recordActions(onEdit: { editingHairProduct = product }) {
                                        store.deleteHairProduct(product)
                                    }
                                }
                            }
                        }
                    }
                }

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
                                    .recordActions(onEdit: { editingHairCareRecord = record }) {
                                        store.deleteHairCareRecord(record)
                                    }
                                }
                            }
                        }
                    }
                }

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
                                    .recordActions(onEdit: { editingHairAppointment = appointment }) {
                                        store.deleteHairAppointment(appointment)
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
        .sheet(item: $editingHairProduct) { record in
            FieldsEditSheet(
                title: "編輯護髮產品",
                fieldLabels: ["名稱", "品牌", "分類", "備註"],
                values: [record.name, record.brand, record.category, record.notes],
                showsDate: false,
                date: .now
            ) { values, newDate in
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
                                    .recordActions(onEdit: { editingBodyProduct = product }) {
                                        store.deleteBodyProduct(product)
                                    }
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
                                .recordActions(onEdit: { editingBodySkinRecord = record }) {
                                    store.deleteBodySkinRecord(record)
                                }
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
            ) { values, newDate in
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

struct ProductLibraryView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var categoryFilter = "全部"

    private var categories: [String] {
        let set = Set(store.state.products.map(\.category)).filter { !$0.isEmpty }
        return ["全部"] + set.sorted()
    }

    private var filteredProducts: [Product] {
        guard categoryFilter != "全部" else { return store.state.products }
        return store.state.products.filter { $0.category == categoryFilter }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "產品管理庫", action: "新增產品") {
                    showAdd = true
                }

                if categories.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(categories, id: \.self) { category in
                                Button {
                                    categoryFilter = category
                                } label: {
                                    Text(category)
                                        .font(.subheadline.weight(.medium))
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(categoryFilter == category ? AppTheme.primary : AppTheme.card)
                                        .foregroundStyle(categoryFilter == category ? Color.white : AppTheme.text)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                }

                CardView {
                    if filteredProducts.isEmpty {
                        EmptyStateView(title: "尚無產品", subtitle: "新增保養品、彩妝或其他產品到管理庫。")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredProducts) { product in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(product.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(AppTheme.text)
                                        Spacer()
                                        if !product.category.isEmpty {
                                            Text(product.category)
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(AppTheme.primary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(AppTheme.primarySoft)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    Text(product.brand.isEmpty ? "未填寫品牌" : product.brand)
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
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showAdd) { AddProductSheet() }
    }
}

struct HairstyleMatchView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAddHairstyle = false
    @State private var editingSavedHairstyle: TutorialLink?
    @State private var facePhotoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var detecting = false
    @State private var detectionMessage: String?

    private let faceShapes = ["圓臉", "長臉", "方臉", "心形臉", "鵜蛋臉", "菱形臉"]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "髮型臉型適配") {}

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("我的臉型")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 10) {
                            Button {
                                showCamera = true
                            } label: {
                                Label("拍照偵測", systemImage: "camera.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.primary)
                                    .foregroundStyle(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            PhotosPicker(selection: $facePhotoItem, matching: .images) {
                                Label("相簿選照", systemImage: "photo.on.rectangle")
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.primarySoft)
                                    .foregroundStyle(AppTheme.primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        if detecting {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("正在偵測臉型…")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                        } else if let detectionMessage {
                            Text(detectionMessage)
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                        }

                        Text("或手動選擇：")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(faceShapes, id: \.self) { shape in
                                Button {
                                    store.setFaceShape(shape)
                                } label: {
                                    Text(shape)
                                        .font(.subheadline.weight(.medium))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(store.state.faceShape == shape ? AppTheme.primary : AppTheme.primarySoft)
                                        .foregroundStyle(store.state.faceShape == shape ? Color.white : AppTheme.text)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }
                    }
                }

                if let currentShape = store.state.faceShape, !currentShape.isEmpty,
                   let recommendations = HairstyleRecommendation.byFaceShape[currentShape] {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("適合「\(currentShape)」的髮型")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)

                            ForEach(recommendations, id: \.style) { item in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.style)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(AppTheme.text)
                                    Text(item.reason)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("髮型收藏")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("添加") { showAddHairstyle = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.savedHairstyles.isEmpty {
                            EmptyStateView(title: "暫無收藏", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.savedHairstyles) { hairstyle in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(hairstyle.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(AppTheme.text)
                                        if !hairstyle.url.isEmpty {
                                            Text(hairstyle.url)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.subtext)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingSavedHairstyle = hairstyle }) {
                                        store.deleteSavedHairstyle(hairstyle)
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
        .sheet(item: $editingSavedHairstyle) { record in
            FieldsEditSheet(
                title: "編輯髮型收藏",
                fieldLabels: ["標題", "連結URL"],
                values: [record.title, record.url],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.title = values[0]
                updated.url = values[1]

                store.replaceRecord(updated, in: \.savedHairstyles)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let image {
                    runFaceDetection(on: image)
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: facePhotoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    runFaceDetection(on: image)
                } else {
                    detectionMessage = "無法讀取照片，請重新選擇。"
                }
                facePhotoItem = nil
            }
        }
        .sheet(isPresented: $showAddHairstyle) {
            AddLinkSheet(sheetTitle: "添加髮型", titleFieldLabel: "髮型名稱") { title, url in
                store.addSavedHairstyle(title: title, url: url)
            }
        }
    }

    private func runFaceDetection(on image: UIImage) {
        detecting = true
        detectionMessage = nil
        FaceShapeDetector.detect(from: image) { result in
            detecting = false
            switch result {
            case .success(let detection):
                store.setFaceShape(detection.shape)
                detectionMessage = "偵測結果：\(detection.shape)（\(detection.confidenceNote)）。照片僅在本機分析，不會上傳或保存。"
            case .failure(let error):
                detectionMessage = error.localizedDescription
            }
        }
    }
}

/// 相機拍照元件（照片僅回傳記憶體，不寫入相簿）
struct CameraPicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraDevice = .front
        }
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onCapture(info[.originalImage] as? UIImage)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCapture(nil)
            parent.dismiss()
        }
    }
}

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

