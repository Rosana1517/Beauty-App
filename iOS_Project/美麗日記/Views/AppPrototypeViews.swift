import SwiftUI
import PhotosUI
import UIKit

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
                    NavigationLink {
                        SkincareManagementView()
                    } label: {
                        QuickLinkCard(title: "護膚管理", subtitle: "步驟、保養品、膚況追蹤", systemImage: "sparkles")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        BodyMetricsView()
                    } label: {
                        QuickLinkCard(title: "體態紀錄", subtitle: "體重體脂與飲食回顧", systemImage: "figure.walk")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ReadingTrackerView()
                    } label: {
                        QuickLinkCard(title: "閱讀追蹤", subtitle: "書單與外部連結收藏", systemImage: "book")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ResourceLibraryView()
                    } label: {
                        QuickLinkCard(title: "資源庫", subtitle: "匯入內容與 AI 推薦", systemImage: "folder")
                    }
                    .buttonStyle(.plain)
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
        VStack(spacing: 18) {
            AIAdviceSection(
                topic: .skincare,
                title: "AI 護膚建議",
                subtitle: "輸入臉部皮膚問題，AI 推薦適用產品及保養方式",
                commonConcerns: ["痘痘", "粉刺", "黑頭", "乾燥脫皮", "泛油", "泛紅", "暗沉", "毛孔粗大", "細紋", "色斑"],
                buttonTitle: "獲取 AI 護膚建議"
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
                                        subtitle: record.note.isEmpty ? record.date.formatted(date: .abbreviated, time: .omitted) : record.note
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
                                        subtitle: record.note.isEmpty ? record.date.formatted(date: .abbreviated, time: .omitted) : record.note
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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteBeforeAfterPhoto(pair)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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

    private func planRow(title: String, subtitle: String, onDelete: @escaping () -> Void) -> some View {
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
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteFaceLiftRating(rating)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteHairProduct(product)
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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteHairCareRecord(record)
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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteHairAppointment(appointment)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteBodyProduct(product)
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
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteBodySkinRecord(record)
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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteSavedHairstyle(hairstyle)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
        .sheet(isPresented: $showAddHairstyle) {
            AddLinkSheet(sheetTitle: "添加髮型", titleFieldLabel: "髮型名稱") { title, url in
                store.addSavedHairstyle(title: title, url: url)
            }
        }
    }
}

struct MakeupInspirationView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAddInspiration = false

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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteMakeupInspiration(inspiration)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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

    private let categories = ["有氧", "力量", "瑜珈", "HIIT", "拉伸", "核心"]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "運動塑型打卡") {}

                AIAdviceSection(
                    topic: .exercise,
                    title: "AI 運動推薦",
                    subtitle: "輸入想訓練的部位或想改善的外型問題",
                    commonConcerns: [],
                    buttonTitle: "獲取推薦"
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
                                    Text(exercise.name)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(AppTheme.primarySoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                store.deleteCustomExercise(exercise)
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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteExercisePunch(record)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                store.deleteTrainingScheduleItem(item)
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
                    GenericSummaryView(title: "養生內調", subtitle: "經期記錄、體質調養、茶飲食譜")
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showAddSymptom) { AddSymptomSheet() }
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
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteSymptomRecord(record)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
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
                buttonTitle: "獲取 AI 養生建議"
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
    @State private var showAddRecipe = false

    private var todaysMealSummaries: [String] {
        store.state.mealRecords
            .filter { Calendar.current.isDateInToday($0.date) }
            .map { "\($0.mealType): \($0.summary)" }
    }

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

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("AI 營養建議")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("根據今日飲食，獲取營養補充建議")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)

                        PrimaryButton(title: store.isLoadingAdvice(for: .diet) ? "正在分析…" : "分析今日營養") {
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
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteFavoriteRecipe(recipe)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
        .sheet(isPresented: $showAddRecipe) {
            AddLinkSheet(sheetTitle: "添加食譜", titleFieldLabel: "食譜名稱") { title, url in
                store.addFavoriteRecipe(title: title, url: url)
            }
        }
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
            case .courses:
                CourseTrackerView()
            case .notes:
                KnowledgeNotesView()
            case .videos:
                VideoLearningView()
            case .dailyQuote:
                DailyQuoteView()
            case .moodTracking:
                MoodTrackingView()
            case .finance:
                FinanceRootView()
            case .goals:
                GoalManagementView()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func growthIcon(for route: GrowthRoute) -> String {
        switch route {
        case .reading:
            return "book.pages"
        case .courses:
            return "graduationcap"
        case .notes:
            return "doc.text"
        case .videos:
            return "play.rectangle"
        case .dailyQuote:
            return "text.bubble"
        case .moodTracking:
            return "heart"
        case .finance:
            return "wallet.pass"
        case .goals:
            return "scope"
        }
    }

    private func growthSubtitle(for route: GrowthRoute) -> String {
        switch route {
        case .reading:
            return "書單、進度、筆記、時長統計"
        case .courses:
            return "課程庫、進度看板、技能樹、證書存檔"
        case .notes:
            return "文章收藏、標籤、搜尋、知識圖譜"
        case .videos:
            return "追蹤、時間戳筆記、頻道訂閱"
        case .dailyQuote:
            return "語錄庫、自我肯定、願景板、感恩日記"
        case .moodTracking:
            return "情緒日記、週期分析、心情曲線"
        case .finance:
            return "記帳、預算、消費分析、變美基金、購物清單"
        case .goals:
            return "主題模板、里程碑、產品推薦、資源整合"
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

struct CourseTrackerView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "課程學習", action: "添加") {
                    showAdd = true
                }

                CardView {
                    if store.state.courses.isEmpty {
                        EmptyStateView(title: "暫無課程", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.courses) { course in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(course.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.text)
                                        Spacer()
                                        Text("\(course.progressPercent)%")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                    Text(course.platform.isEmpty ? "未填寫平台" : course.platform)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    ProgressView(value: Double(course.progressPercent), total: 100)
                                        .tint(AppTheme.primary)
                                    HStack(spacing: 14) {
                                        Button("+10%") {
                                            store.updateCourseProgress(course, progressPercent: course.progressPercent + 10)
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)
                                    }
                                }
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteCourse(course)
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
        .sheet(isPresented: $showAdd) { AddCourseSheet() }
    }
}

struct KnowledgeNotesView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var tagFilter = "全部"

    private var allTags: [String] {
        let set = Set(store.state.knowledgeNotes.flatMap(\.tags)).filter { !$0.isEmpty }
        return ["全部"] + set.sorted()
    }

    private var filteredNotes: [KnowledgeNote] {
        guard tagFilter != "全部" else { return store.state.knowledgeNotes }
        return store.state.knowledgeNotes.filter { $0.tags.contains(tagFilter) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "知識筆記", action: "新建") {
                    showAdd = true
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(allTags, id: \.self) { tag in
                            Button {
                                tagFilter = tag
                            } label: {
                                Text(tag)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(tagFilter == tag ? AppTheme.primary : AppTheme.card)
                                    .foregroundStyle(tagFilter == tag ? Color.white : AppTheme.text)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                CardView {
                    if filteredNotes.isEmpty {
                        EmptyStateView(title: "暫無筆記", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredNotes) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(note.content)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    if !note.tags.isEmpty {
                                        Text(note.tags.joined(separator: "、"))
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteKnowledgeNote(note)
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
        .sheet(isPresented: $showAdd) { AddKnowledgeNoteSheet() }
    }
}

struct VideoLearningView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "影音學習追蹤", action: "添加") {
                    showAdd = true
                }

                CardView {
                    if store.state.videoLearningRecords.isEmpty {
                        EmptyStateView(title: "暫無影音記錄", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.videoLearningRecords) { record in
                                Button {
                                    store.toggleVideoLearningWatched(record)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: record.watched ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(record.watched ? AppTheme.primary : AppTheme.subtext)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(record.title)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(AppTheme.text)
                                            Text("\(record.contentType) · \(record.platform.isEmpty ? "未填寫平台" : record.platform)")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.subtext)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteVideoLearningRecord(record)
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
        .sheet(isPresented: $showAdd) { AddVideoLearningSheet() }
    }
}

struct DailyQuoteView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var quoteIndex = Int.random(in: 0..<DailyQuoteView.quotes.count)
    @State private var showAddAffirmation = false
    @State private var showAddVision = false
    @State private var showAddGratitude = false

    static let quotes = [
        "成為自己的太陽，無需借誰的光",
        "每一天都是新的開始",
        "你比自己想像的更堅強",
        "慢慢來，比較快",
        "先愛自己，再愛別人"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "每日金句") {}

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("「\(DailyQuoteView.quotes[quoteIndex])」")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(AppTheme.text)
                        Text("—— 今日金句")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                        Button("換一句") {
                            quoteIndex = Int.random(in: 0..<DailyQuoteView.quotes.count)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("自我肯定")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+添加") { showAddAffirmation = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.selfAffirmations.isEmpty {
                            EmptyStateView(title: "寫下你的肯定語", subtitle: "")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.state.selfAffirmations) { item in
                                    Text(item.text)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(AppTheme.primarySoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                store.deleteSelfAffirmation(item)
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
                            Text("願景板")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+添加") { showAddVision = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.visionBoardItems.isEmpty {
                            EmptyStateView(title: "創建你的願景板", subtitle: "")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.state.visionBoardItems) { item in
                                    Text(item.text)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(AppTheme.primarySoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                store.deleteVisionBoardItem(item)
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
                            Text("感恩日記")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+記錄") { showAddGratitude = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.gratitudeEntries.isEmpty {
                            EmptyStateView(title: "暫無記錄", subtitle: "")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.state.gratitudeEntries) { entry in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.text)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.text)
                                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteGratitudeEntry(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
        .sheet(isPresented: $showAddAffirmation) {
            AddLinkSheet(sheetTitle: "添加自我肯定", titleFieldLabel: "我值得被愛…") { text, _ in
                store.addSelfAffirmation(text: text)
            }
        }
        .sheet(isPresented: $showAddVision) {
            AddLinkSheet(sheetTitle: "添加願景板項目", titleFieldLabel: "願景內容") { text, _ in
                store.addVisionBoardItem(text: text)
            }
        }
        .sheet(isPresented: $showAddGratitude) {
            AddLinkSheet(sheetTitle: "添加感恩日記", titleFieldLabel: "今天感謝的事") { text, _ in
                store.addGratitudeEntry(text: text)
            }
        }
    }
}

struct MoodTrackingView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var selectedMood: String?
    @State private var note = ""

    private let moods = [("😊", "開心"), ("😌", "平靜"), ("😔", "低落"), ("😫", "煩躁"), ("🥺", "疲憊")]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "每日金句·情緒追蹤") {}

                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("「\(DailyQuoteView.quotes.first ?? "")」")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.text)
                        Text("—— 今日金句")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }

                if let firstAffirmation = store.state.selfAffirmations.first {
                    CardView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(firstAffirmation.text)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.text)
                            Text("—— 今日自我肯定")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("今日情緒")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 14) {
                            ForEach(moods, id: \.1) { mood in
                                Button {
                                    selectedMood = mood.1
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(mood.0)
                                            .font(.title2)
                                        Text(mood.1)
                                            .font(.caption2)
                                            .foregroundStyle(selectedMood == mood.1 ? AppTheme.primary : AppTheme.subtext)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedMood == mood.1 ? AppTheme.primarySoft : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        ThemedTextField(title: "記錄此刻的感受…", text: $note)

                        PrimaryButton(title: "保存") {
                            guard let selectedMood else { return }
                            store.addMoodEntry(mood: selectedMood, note: note)
                            note = ""
                        }
                    }
                }

                if !store.state.moodEntries.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("情緒紀錄")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            VStack(spacing: 8) {
                                ForEach(store.state.moodEntries) { entry in
                                    HStack {
                                        Text(entry.mood)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.note.isEmpty ? entry.date.formatted(date: .abbreviated, time: .omitted) : entry.note)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.text)
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteMoodEntry(entry)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
    }
}

struct FinanceRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "財務總覽", subtitle: "記帳、預算、消費分析、變美基金、購物清單")

                ForEach(FinanceRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: financeSubtitle(for: route), icon: financeIcon(for: route))
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: FinanceRoute.self) { route in
            switch route {
            case .ledger:
                LedgerView()
            case .budget:
                BudgetDashboardView()
            case .aiAdvice:
                FinanceAIAdviceView()
            case .spendingAnalysis:
                SpendingAnalysisView()
            case .beautyFund:
                SavingsGoalView()
            case .shoppingList:
                ShoppingListView()
            case .financialHealth:
                FinancialHealthView()
            }
        }
    }

    private func financeIcon(for route: FinanceRoute) -> String {
        switch route {
        case .ledger: return "creditcard"
        case .budget: return "gauge"
        case .aiAdvice: return "sparkles"
        case .spendingAnalysis: return "chart.pie"
        case .beautyFund: return "diamond"
        case .shoppingList: return "cart"
        case .financialHealth: return "checkmark.shield"
        }
    }

    private func financeSubtitle(for route: FinanceRoute) -> String {
        switch route {
        case .ledger: return "收支分類、多帳戶管理"
        case .budget: return "總預算、分類預算、進度展示"
        case .aiAdvice: return "智能記帳與預算建議"
        case .spendingAnalysis: return "圖表面、趨勢面展示"
        case .beautyFund: return "專屬帳戶、心願清單"
        case .shoppingList: return "需求記錄、冷靜期標記"
        case .financialHealth: return "儲蓄率、月度報告"
        }
    }
}

struct LedgerView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "記帳", action: "記帳") {
                    showAdd = true
                }

                HStack(spacing: 12) {
                    statCard(title: "本月收入", value: store.monthlyIncome, color: .green)
                    statCard(title: "本月支出", value: store.monthlyExpense, color: .red)
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("帳戶")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        HStack(spacing: 12) {
                            statCard(title: "現金", value: store.accountBalance("現金"), color: AppTheme.primary)
                            statCard(title: "銀行卡", value: store.accountBalance("銀行卡"), color: AppTheme.primary)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("最近記錄")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        if store.state.transactions.isEmpty {
                            EmptyStateView(title: "暫無記錄", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.transactions) { transaction in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(transaction.category)
                                                .font(.subheadline.weight(.medium))
                                                .foregroundStyle(AppTheme.text)
                                            Text(transaction.account)
                                                .font(.caption2)
                                                .foregroundStyle(AppTheme.subtext)
                                        }
                                        Spacer()
                                        Text("\(transaction.type == .income ? "+" : "-")\(Int(transaction.amount))")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(transaction.type == .income ? .green : .red)
                                    }
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteTransaction(transaction)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
        .sheet(isPresented: $showAdd) { AddTransactionSheet() }
    }

    private func statCard(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
            Text("\(Int(value))")
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct BudgetDashboardView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showSetBudget = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "預算儀表板", action: "設定") {
                    showSetBudget = true
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("總預算")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.subtext)
                            Spacer()
                            Text("\(Int(store.totalBudget))")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.text)
                        }
                        let percent = store.totalBudget > 0 ? min(1, store.monthlyExpense / store.totalBudget) : 0
                        ProgressView(value: percent)
                            .tint(AppTheme.primary)
                        Text("已花 \(Int(store.monthlyExpense)) (\(Int(percent * 100))%)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }

                if !store.state.budgetCategories.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(store.state.budgetCategories) { budget in
                                HStack {
                                    Text(budget.category)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                    Spacer()
                                    Text("\(Int(budget.amount))")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                                .padding(12)
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
        .sheet(isPresented: $showSetBudget) { SetBudgetSheet() }
    }
}

struct FinanceAIAdviceView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "AI預算建議") {}

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("你的消費概況")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("本月支出：\(Int(store.monthlyExpense)) 元")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                        Text("最大開銷：\(store.expenseByCategory.first?.category ?? "暫無數據")")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                    }
                }

                PrimaryButton(title: store.isLoadingAdvice(for: .finance) ? "正在分析…" : "獲取AI建議") {
                    let summary = store.expenseByCategory.map { "\($0.category): \(Int($0.total))元" }
                    Task { await store.requestAIAdvice(topic: .finance, concerns: summary) }
                }
                .disabled(store.isLoadingAdvice(for: .finance))

                if let errorMessage = store.errorMessage(for: .finance) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !store.suggestions(for: .finance).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.suggestions(for: .finance), id: \.self) { suggestion in
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
            .padding(20)
        }
        .background(AppTheme.background)
    }
}

struct SpendingAnalysisView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "消費分析") {}

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("本月分類支出")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        if store.expenseByCategory.isEmpty {
                            EmptyStateView(title: "暫無支出記錄", subtitle: "")
                        } else {
                            let maxTotal = store.expenseByCategory.first?.total ?? 1
                            VStack(spacing: 10) {
                                ForEach(store.expenseByCategory, id: \.category) { entry in
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(entry.category)
                                                .font(.subheadline)
                                                .foregroundStyle(AppTheme.text)
                                            Spacer()
                                            Text("\(Int(entry.total))")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.primary)
                                        }
                                        GeometryReader { geo in
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(AppTheme.primary)
                                                .frame(width: geo.size.width * (entry.total / maxTotal), height: 10)
                                        }
                                        .frame(height: 10)
                                    }
                                    .padding(10)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
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

struct SavingsGoalView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAddWish = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "變美基金", action: "心願") {
                    showAddWish = true
                }

                CardView {
                    VStack(spacing: 14) {
                        Text("變美基金餘額")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                        Text("\(Int(store.beautyFundBalance))")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                        HStack(spacing: 16) {
                            fundButton(title: "存入") { store.addBeautyFundTransaction(type: .deposit, amount: 100) }
                            fundButton(title: "支出") { store.addBeautyFundTransaction(type: .withdrawal, amount: 100) }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(colors: [AppTheme.primary, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("心願清單")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        if store.state.wishes.isEmpty {
                            EmptyStateView(title: "暫無心願", subtitle: "")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(store.state.wishes) { wish in
                                    HStack {
                                        Text(wish.name)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.text)
                                        Spacer()
                                        Text("目標 \(Int(wish.targetAmount))")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.deleteWish(wish)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
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
        .sheet(isPresented: $showAddWish) { AddWishSheet() }
    }

    private func fundButton(title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.primary)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
    }
}

struct ShoppingListView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "購物清單", action: "添加") {
                    showAdd = true
                }

                CardView {
                    if store.state.shoppingItems.isEmpty {
                        EmptyStateView(title: "暫無購物需求", subtitle: "")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.state.shoppingItems) { item in
                                Button {
                                    store.toggleShoppingItem(item)
                                } label: {
                                    HStack {
                                        Image(systemName: item.isPurchased ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(item.isPurchased ? AppTheme.primary : AppTheme.subtext)
                                        Text(item.name)
                                            .font(.subheadline)
                                            .strikethrough(item.isPurchased)
                                            .foregroundStyle(AppTheme.text)
                                        Spacer()
                                        Text("\(Int(item.estimatedPrice))")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .contextMenu {
                                    Button(role: .destructive) {
                                        store.deleteShoppingItem(item)
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
        .sheet(isPresented: $showAdd) { AddShoppingItemSheet() }
    }
}

struct FinancialHealthView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    private var fixedExpenseRatio: Int {
        guard store.monthlyExpense > 0 else { return 0 }
        let fixed = store.state.transactions
            .filter { $0.type == .expense && $0.category == "固定支出" }
            .reduce(0) { $0 + $1.amount }
        return Int(fixed / store.monthlyExpense * 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "財務健康評估") {}

                CardView {
                    VStack(spacing: 6) {
                        Text("儲蓄率")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                        Text(String(format: "%.1f%%", store.savingsRate * 100))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(store.savingsRate < 0.2 ? .red : .green)
                        Text(store.savingsRate < 0.2 ? "需改善" : "狀態良好")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    .frame(maxWidth: .infinity)
                }

                HStack(spacing: 12) {
                    healthStat(title: "月收入", value: store.monthlyIncome, color: .green)
                    healthStat(title: "月支出", value: store.monthlyExpense, color: .red)
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("月度報告")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        reportRow(title: "固定支出佔比", value: "\(fixedExpenseRatio)%")
                        reportRow(title: "可自由支配", value: "\(Int(store.monthlyIncome - store.monthlyExpense)) 元")
                        reportRow(title: "建議儲蓄", value: "\(Int(store.monthlyIncome * 0.2)) 元")
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("改善建議")
                            .font(.headline)
                            .foregroundStyle(AppTheme.primary)
                        ForEach(healthAdvice, id: \.self) { advice in
                            Text("· \(advice)")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private var healthAdvice: [String] {
        var advice: [String] = []
        if store.savingsRate < 0.2 {
            advice.append("建議將儲蓄率提升至20%以上")
        }
        if store.monthlyExpense > store.monthlyIncome {
            advice.append("支出過高，建議削減非必要消費")
        }
        advice.append("每月固定存入變美基金，積少成多")
        advice.append("區分「想要」和「需要」，理性消費")
        return advice
    }

    private func healthStat(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
            Text("\(Int(value))")
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func reportRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.subtext)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
        }
    }
}

struct GoalManagementView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "目標管理", subtitle: "設定目標、追蹤里程碑")

                Text("快速開始")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    NavigationLink {
                        WhiteningPlanView()
                    } label: {
                        goalTemplateCard(icon: "✨", title: "美白計畫", subtitle: "3個月美白目標")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ShapingPlanView()
                    } label: {
                        goalTemplateCard(icon: "💪", title: "健身塑型", subtitle: "12週健身計畫")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ReadingTrackerView()
                    } label: {
                        goalTemplateCard(icon: "📚", title: "讀書目標", subtitle: "每月4本書")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        SavingsGoalView()
                    } label: {
                        goalTemplateCard(icon: "💰", title: "儲蓄計畫", subtitle: "每月存2000")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private func goalTemplateCard(icon: String, title: String, subtitle: String) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text(icon)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
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
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("supabaseSync.statusValue")
                    .accessibilityValue(authStatusText)
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
                        .accessibilityIdentifier("supabaseSync.authMessage")
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

    /// nil defaults to the skincare product list (the original use of this
    /// sheet); 身體保養品/洗護產品 pass their own store method so the same
    /// form can add to a different list without duplicating the sheet.
    var onSave: ((String, String, String, String) -> Void)?
    var title: String = "新增保養品"

    var body: some View {
        FormSheet(title: title) {
            ThemedTextField(title: "產品名稱", text: $name)
            ThemedTextField(title: "品牌", text: $brand)
            ThemedTextField(title: "分類", text: $category)
            ThemedTextField(title: "備註", text: $notes)

            PrimaryButton(title: "保存") {
                if let onSave {
                    onSave(name, brand, category, notes)
                } else {
                    store.addProduct(name: name, brand: brand, category: category, notes: notes)
                }
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

/// Generic title+url add form, shared by 收藏食譜/髮型收藏/妝容靈感 (and
/// anything else that's just "save a link with a title").
private struct AddLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sheetTitle: String
    let titleFieldLabel: String
    let onSave: (String, String) -> Void

    @State private var title = ""
    @State private var url = ""

    var body: some View {
        FormSheet(title: sheetTitle) {
            ThemedTextField(title: titleFieldLabel, text: $title)
            ThemedTextField(title: "連結（選填）", text: $url)

            PrimaryButton(title: "保存") {
                onSave(title, url)
                dismiss()
            }
        }
    }
}

private struct AddWhiteningProductUsageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var productName = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增產品使用記錄") {
            ThemedTextField(title: "產品名稱", text: $productName)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addWhiteningProductUsage(productName: productName, note: note)
                dismiss()
            }
        }
    }
}

private struct AddShadeTrackingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var shadeName = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增色號記錄") {
            ThemedTextField(title: "色號", text: $shadeName)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addShadeTrackingRecord(shadeName: shadeName, note: note)
                dismiss()
            }
        }
    }
}

private struct AddBeforeAfterPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var beforeItem: PhotosPickerItem?
    @State private var afterItem: PhotosPickerItem?
    @State private var beforeData: Data?
    @State private var afterData: Data?
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增前後對比照") {
            HStack(spacing: 16) {
                photoPickerSlot(label: "前", item: $beforeItem, data: $beforeData)
                photoPickerSlot(label: "後", item: $afterItem, data: $afterData)
            }

            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addBeforeAfterPhoto(beforeImageData: beforeData, afterImageData: afterData, note: note)
                dismiss()
            }
        }
    }

    private func photoPickerSlot(label: String, item: Binding<PhotosPickerItem?>, data: Binding<Data?>) -> some View {
        VStack(spacing: 6) {
            PhotosPicker(selection: item, matching: .images) {
                if let value = data.wrappedValue, let uiImage = UIImage(data: value) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.primarySoft)
                        .frame(width: 90, height: 90)
                        .overlay(Image(systemName: "camera").foregroundStyle(AppTheme.primary))
                }
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
        }
        .onChange(of: item.wrappedValue) { newItem in
            Task {
                if let newItem, let loaded = try? await newItem.loadTransferable(type: Data.self) {
                    data.wrappedValue = loaded
                }
            }
        }
    }
}

private struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var type: TransactionType = .expense
    @State private var amountText = ""
    @State private var category = "餐飲"
    @State private var account = "現金"
    @State private var note = ""

    private let categories = ["餐飲", "交通", "購物", "娛樂", "醫療", "固定支出", "其他"]
    private let accounts = ["現金", "銀行卡"]

    var body: some View {
        FormSheet(title: "記帳") {
            Picker("類型", selection: $type) {
                Text("支出").tag(TransactionType.expense)
                Text("收入").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)

            ThemedTextField(title: "金額", text: $amountText)
                .keyboardType(.decimalPad)

            Picker("分類", selection: $category) {
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }

            Picker("帳戶", selection: $account) {
                ForEach(accounts, id: \.self) { Text($0).tag($0) }
            }

            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                guard let amount = Double(amountText) else { return }
                store.addTransaction(type: type, amount: amount, category: category, account: account, note: note)
                dismiss()
            }
        }
    }
}

private struct SetBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var category = "餐飲"
    @State private var amountText = ""

    private let categories = ["餐飲", "交通", "購物", "娛樂", "醫療", "固定支出", "其他"]

    var body: some View {
        FormSheet(title: "設定預算") {
            Picker("分類", selection: $category) {
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }

            ThemedTextField(title: "預算金額", text: $amountText)
                .keyboardType(.decimalPad)

            PrimaryButton(title: "保存") {
                guard let amount = Double(amountText) else { return }
                store.setBudget(category: category, amount: amount)
                dismiss()
            }
        }
    }
}

private struct AddWishSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var name = ""
    @State private var targetAmountText = ""

    var body: some View {
        FormSheet(title: "添加心願") {
            ThemedTextField(title: "心願名稱", text: $name)
            ThemedTextField(title: "目標金額", text: $targetAmountText)
                .keyboardType(.decimalPad)

            PrimaryButton(title: "保存") {
                store.addWish(name: name, targetAmount: Double(targetAmountText) ?? 0)
                dismiss()
            }
        }
    }
}

private struct AddShoppingItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var name = ""
    @State private var priceText = ""

    var body: some View {
        FormSheet(title: "添加購物項") {
            ThemedTextField(title: "商品名稱", text: $name)
            ThemedTextField(title: "預估價格", text: $priceText)
                .keyboardType(.decimalPad)

            PrimaryButton(title: "保存") {
                store.addShoppingItem(name: name, estimatedPrice: Double(priceText) ?? 0)
                dismiss()
            }
        }
    }
}

private struct AddCourseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var platform = ""
    @State private var url = ""

    var body: some View {
        FormSheet(title: "添加課程") {
            ThemedTextField(title: "課程名稱", text: $title)
            ThemedTextField(title: "平台", text: $platform)
            ThemedTextField(title: "連結URL (選填)", text: $url)

            PrimaryButton(title: "保存") {
                store.addCourse(title: title, platform: platform, url: url)
                dismiss()
            }
        }
    }
}

private struct AddKnowledgeNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var content = ""
    @State private var tagsText = ""

    var body: some View {
        FormSheet(title: "新建筆記") {
            ThemedTextField(title: "標題", text: $title)
            ThemedTextField(title: "重點摘錄…", text: $content)
            ThemedTextField(title: "標籤（逗號分隔）", text: $tagsText)

            PrimaryButton(title: "保存") {
                let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                store.addKnowledgeNote(title: title, content: content, tags: tags)
                dismiss()
            }
        }
    }
}

private struct AddVideoLearningSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var contentType = "影片"
    @State private var platform = ""
    @State private var url = ""

    var body: some View {
        FormSheet(title: "添加影音") {
            ThemedTextField(title: "標題", text: $title)
            Picker("類型", selection: $contentType) {
                Text("影片").tag("影片")
                Text("Podcast").tag("Podcast")
            }
            .pickerStyle(.segmented)
            ThemedTextField(title: "平台", text: $platform)
            ThemedTextField(title: "連結URL (選填)", text: $url)

            PrimaryButton(title: "保存") {
                store.addVideoLearningRecord(title: title, contentType: contentType, platform: platform, url: url)
                dismiss()
            }
        }
    }
}

private struct AddSymptomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var symptom = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增症狀記錄") {
            ThemedTextField(title: "症狀", text: $symptom)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addSymptomRecord(symptom: symptom, note: note)
                dismiss()
            }
        }
    }
}

private struct AddFaceLiftActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var name = ""

    var body: some View {
        FormSheet(title: "新增動作") {
            ThemedTextField(title: "動作名稱", text: $name)

            PrimaryButton(title: "保存") {
                store.addFaceLiftAction(name: name)
                dismiss()
            }
        }
    }
}

private struct AddFaceLiftRatingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var score: Double = 7
    @State private var note = ""

    var body: some View {
        FormSheet(title: "緊緻度評分") {
            VStack(alignment: .leading, spacing: 8) {
                Text("評分：\(Int(score)) 分")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text)
                Slider(value: $score, in: 1...10, step: 1)
                    .tint(AppTheme.primary)
            }

            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addFaceLiftRating(score: Int(score), note: note)
                dismiss()
            }
        }
    }
}

private struct AddHairCareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var careType = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增護髮紀錄") {
            ThemedTextField(title: "保養類型（洗髮、護髮療程…）", text: $careType)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addHairCareRecord(careType: careType, note: note)
                dismiss()
            }
        }
    }
}

private struct AddBodySkinRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var area = ""
    @State private var concern = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增身體保養紀錄") {
            ThemedTextField(title: "部位", text: $area)
            ThemedTextField(title: "膚況問題", text: $concern)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addBodySkinRecord(area: area, concern: concern, note: note)
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

    /// nil defaults to 美容預約's own list; 護髮療程預約 passes its own
    /// store method so the same form can target a different list.
    var onSave: ((String, String, Date, String) -> Void)?
    var sheetTitle: String = "新增預約"

    var body: some View {
        FormSheet(title: sheetTitle) {
            ThemedTextField(title: "服務名稱", text: $title)
            ThemedTextField(title: "店家名稱", text: $storeName)
            DatePicker("預約時間", selection: $date)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                if let onSave {
                    onSave(title, storeName, date, note)
                } else {
                    store.addAppointment(title: title, storeName: storeName, date: date, note: note)
                }
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

/// Reusable "type your concern -> get AI suggestions" card, shared by every
/// screen with this pattern (護膚/頭髮/面部拉提/身體皮膚/飲食/妝容) so each
/// one doesn't duplicate the chip-selector + custom-input + button + result
/// list wiring.
struct AIAdviceSection: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    let topic: AIAdviceTopic
    let title: String
    let subtitle: String
    let commonConcerns: [String]
    let buttonTitle: String

    @State private var selectedConcerns: Set<String> = []
    @State private var customConcern = ""
    @State private var customConcerns: [String] = []

    private var allConcerns: [String] {
        Array(selectedConcerns) + customConcerns
    }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)

                if !commonConcerns.isEmpty {
                    WrapToggleChips(items: commonConcerns, selection: $selectedConcerns)
                }

                HStack(spacing: 10) {
                    ThemedTextField(title: "自訂問題…", text: $customConcern)
                    Button("加入") {
                        let trimmed = customConcern.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        customConcerns.append(trimmed)
                        customConcern = ""
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                }

                if !customConcerns.isEmpty {
                    WrapToggleChips(items: customConcerns, selection: .constant(Set(customConcerns)))
                }

                PrimaryButton(title: store.isLoadingAdvice(for: topic) ? "正在取得建議…" : buttonTitle) {
                    Task { await store.requestAIAdvice(topic: topic, concerns: allConcerns) }
                }
                .disabled(store.isLoadingAdvice(for: topic))

                if let errorMessage = store.errorMessage(for: topic) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !store.suggestions(for: topic).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.suggestions(for: topic), id: \.self) { suggestion in
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
                .accessibilityIdentifier("infoCallout.detail")
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
                    .accessibilityIdentifier("metadataHero.title")
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
