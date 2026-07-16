import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts


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
                    VStack(alignment: .leading, spacing: 12) {
                        Text("基本資料")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

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

                HabitRemindersCard()

                AIProviderSettingsCard(
                    provider: $aiProvider,
                    apiKey: $aiAPIKey,
                    baseURL: $aiBaseURL,
                    model: $aiModel
                )

                SupabaseSyncSettingsCard(authEmail: $authEmail, authPassword: $authPassword)
            }
            .padding(20)
        }
        .background(AppTheme.background)
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

    private let themes = [("玫瑰金", Color(red: 0.79, green: 0.55, blue: 0.48)), ("珊瑚粉", Color(red: 0.95, green: 0.6, blue: 0.6)), ("薰衣草", Color(red: 0.7, green: 0.6, blue: 0.9)), ("薄荷綠", Color(red: 0.55, green: 0.8, blue: 0.7))]
    private let modules = ["變美", "體態", "成長", "財務", "情緒"]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "客製化") {}

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("模組開關")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        ForEach(modules, id: \.self) { module in
                            HStack {
                                Text(module)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Toggle("", isOn: Binding(
                                    get: { store.state.profile.enabledModules.contains(module) },
                                    set: { _ in store.toggleModule(module) }
                                ))
                                .labelsHidden()
                                .tint(AppTheme.primary)
                            }
                            .padding(12)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("主題配色")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 14) {
                            ForEach(themes, id: \.0) { theme in
                                Button {
                                    store.setThemeName(theme.0)
                                } label: {
                                    VStack(spacing: 6) {
                                        Circle()
                                            .fill(theme.1)
                                            .frame(width: 44, height: 44)
                                            .overlay(
                                                Circle()
                                                    .stroke(AppTheme.text, lineWidth: store.state.profile.themeName == theme.0 ? 2 : 0)
                                                    .padding(-3)
                                            )
                                        Text(theme.0)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("通知時間")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        reminderRow(title: "早晨提醒", time: store.state.profile.morningReminderTime) {
                            store.setMorningReminderTime($0)
                        }
                        reminderRow(title: "晚間提醒", time: store.state.profile.notificationTime) {
                            store.setEveningReminderTime($0)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private func reminderRow(title: String, time: String, onChange: @escaping (String) -> Void) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
            Spacer()
            Picker("", selection: Binding(get: { time }, set: onChange)) {
                ForEach(Self.timeOptions, id: \.self) { Text($0).tag($0) }
            }
        }
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private static let timeOptions: [String] = (0..<24).map { String(format: "%02d:00", $0) }
}

/// Lets each signed-in user bring their own AI provider (OpenAI/Anthropic
/// compatible) key instead of relying on a key shared across every
/// installation. Saved to the user's own RLS-scoped row in Supabase via
/// `BeautyDiaryStore.saveAIProviderSettings`, plus cached locally so it
/// still shows up while offline.
/// 每個習慣獨立的提醒時間設定；開關 + 時間選擇，改動即刻重排本機通知
private struct HabitRemindersCard: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("習慣提醒")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text("為每個習慣設定各自的提醒時間，時間到會收到通知直接來打卡。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)

                ForEach(HabitReminderKind.allCases) { kind in
                    HabitReminderRow(kind: kind)
                }
            }
        }
    }
}

private struct HabitReminderRow: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    let kind: HabitReminderKind
    @State private var isEnabled = false
    @State private var time = Date()

    var body: some View {
        HStack {
            Toggle(isOn: $isEnabled) {
                Text(kind.rawValue)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text)
            }
            .toggleStyle(.switch)
            .tint(AppTheme.primary)

            if isEnabled {
                DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            if let saved = store.habitReminderTime(kind), let parsed = Self.parse(saved) {
                isEnabled = true
                time = parsed
            }
        }
        .onChange(of: isEnabled) { enabled in
            store.setHabitReminder(kind, timeString: enabled ? Self.format(time) : nil)
        }
        .onChange(of: time) { newTime in
            guard isEnabled else { return }
            store.setHabitReminder(kind, timeString: Self.format(newTime))
        }
    }

    private static func format(_ date: Date) -> String {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", components.hour ?? 21, components.minute ?? 0)
    }

    private static func parse(_ value: String) -> Date? {
        let pieces = value.split(separator: ":")
        guard pieces.count == 2, let hour = Int(pieces[0]), let minute = Int(pieces[1]) else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }
}

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

/// This is the developer's own private login channel - signing in here
/// with your own Supabase account is what makes the AI provider settings
/// card above personal to you (stored RLS-scoped to your user ID) instead
/// of falling back to the shared env-var key. Regular end users of this
/// app never need to see or touch this card.
private struct SupabaseSyncSettingsCard: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @Binding var authEmail: String
    @Binding var authPassword: String

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text("開發者登入（雲端同步）")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text("這是開發者專用的登入入口。如果還沒有帳號，先按「註冊新帳號」建立一個；登入後，上方的 AI 提供者設定會綁定到你的帳號並同步到雲端，一般使用者不需要也看不到這裡。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)

                InfoRow(title: "登入狀態", value: authStatusText)
                    .accessibilityElement(children: .ignore)
                    .accessibilityIdentifier("supabaseSync.statusValue")
                    .accessibilityValue(authStatusText)
                InfoRow(title: "帳號", value: resolvedEmail)
                InfoRow(title: "同步 ID", value: resolvedSyncUserID)

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

                ThemedTextField(title: "開發者帳號 Email", text: $authEmail)
                    .accessibilityIdentifier("supabaseSync.emailField")
                ThemedSecureField(title: "密碼", text: $authPassword)
                    .accessibilityIdentifier("supabaseSync.passwordField")

                HStack(spacing: 10) {
                    PrimaryButton(title: "登入並同步") {
                        Task {
                            await store.signInToSupabase(email: authEmail, password: authPassword)
                        }
                    }
                    .accessibilityIdentifier("supabaseSync.signInButton")

                    Button {
                        Task {
                            await store.signUpToSupabase(email: authEmail, password: authPassword)
                        }
                    } label: {
                        Text("註冊新帳號")
                            .font(.headline)
                            .foregroundStyle(AppTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.primarySoft)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("supabaseSync.signUpButton")
                }

                Button {
                    Task {
                        await store.requestSupabaseMagicLink(email: authEmail)
                    }
                } label: {
                    Text("改用 Email 連結登入（免密碼）")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                PrimaryButton(title: "立即同步資源") {
                    Task {
                        await store.syncCloudNow()
                    }
                }
                .accessibilityIdentifier("supabaseSync.syncButton")

                if store.authSession != nil {
                    Button {
                        Task {
                            await store.signOutFromSupabase()
                        }
                    } label: {
                        Text("登出")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var authStatusText: String {
        switch store.authStatus {
        case .unavailable:
            return "目前無法使用"
        case .signedOut:
            return "未登入"
        case .restoring:
            return "正在恢復登入狀態"
        case .authenticating:
            return "登入中"
        case .authenticated:
            return "已登入"
        }
    }

    private var resolvedEmail: String {
        let email = store.authSession?.email ?? ""
        return email.isEmpty ? "尚未登入" : email
    }

    private var resolvedSyncUserID: String {
        let sessionUserID = store.authSession?.userID ?? ""
        if !sessionUserID.isEmpty {
            return sessionUserID
        }

        let configured = AppRuntimeConfiguration.resourceSyncUserID
        return configured.isEmpty ? "尚未設定" : configured
    }
}

struct AchievementsView: View {
    @EnvironmentObject private var store: BeautyDiaryStore

    private let streakMilestones = [(3, "🌱"), (7, "🌿"), (14, "🌳"), (30, "🏆"), (60, "💎"), (100, "👑")]

    private var milestoneAchievements: [(title: String, detail: String, unlocked: Bool)] {
        [
            ("初次打卡", "完成第一次打卡", !store.state.punchRecords.isEmpty || store.weeklyCompletionRate.completed > 0),
            ("目標啟程", "創建第一個目標", !store.state.wishes.isEmpty || !store.state.trainingSchedule.isEmpty),
            ("週度堅持", "連續打卡 7 天", store.state.profile.streakDays >= 7),
            ("月度達人", "連續打卡 30 天", store.state.profile.streakDays >= 30)
        ]
    }

    private var specialAchievements: [(title: String, detail: String, unlocked: Bool)] {
        [
            ("美麗啟航", "使用全部分頁", store.hasUsedBeautyModule && store.hasUsedBodyModule && store.hasUsedGrowthModule),
            ("知識積累", "記錄 10 次以上", store.knowledgeRecordCount >= 10),
            ("財務管家", "記帳超過 5 筆", store.state.transactions.count >= 5),
            ("完美主義", "一天全部打卡", store.hasPerfectChecklistDay)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "成就徽章") {}

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("連續打卡")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(streakMilestones, id: \.0) { milestone in
                                let unlocked = store.state.profile.streakDays >= milestone.0
                                VStack(spacing: 4) {
                                    Text(milestone.1)
                                        .font(.title2)
                                        .opacity(unlocked ? 1 : 0.35)
                                    Text("\(milestone.0)天")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(unlocked ? "已達成" : "還差\(milestone.0 - store.state.profile.streakDays)天")
                                        .font(.caption2)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }

                achievementGroup(title: "里程碑達成", items: milestoneAchievements)
                achievementGroup(title: "特殊成就", items: specialAchievements)

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("統計總覽")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 12) {
                            statBlock(title: "連續打卡", value: "\(store.state.profile.streakDays)天")
                            statBlock(title: "知識記錄", value: "\(store.knowledgeRecordCount)次")
                            statBlock(title: "財務記錄", value: "\(store.state.transactions.count)筆")
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    private func achievementGroup(title: String, items: [(title: String, detail: String, unlocked: Bool)]) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(items, id: \.title) { item in
                        VStack(spacing: 6) {
                            Image(systemName: item.unlocked ? "star.fill" : "lock.fill")
                                .foregroundStyle(item.unlocked ? Color.white : AppTheme.subtext)
                            Text(item.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(item.unlocked ? Color.white : AppTheme.text)
                            Text(item.detail)
                                .font(.caption2)
                                .foregroundStyle(item.unlocked ? Color.white.opacity(0.85) : AppTheme.subtext)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(item.unlocked ? AppTheme.primary : AppTheme.primarySoft)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct DataExportView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var exportPreview = ""
    @State private var showClearConfirm = false

    private var storageRows: [(label: String, count: Int)] {
        [
            ("打卡記錄", store.state.punchRecords.count),
            ("體態數據", store.state.bodyMetricRecords.count),
            ("飲食記錄", store.state.mealRecords.count),
            ("茶飲記錄", 0),
            ("食譜", store.state.favoriteRecipes.count),
            ("食材", 0),
            ("書籍", store.state.bookRecords.count),
            ("課程", store.state.courses.count),
            ("筆記", store.state.knowledgeNotes.count),
            ("影音", store.state.videoLearningRecords.count),
            ("財務記錄", store.state.transactions.count),
            ("目標", store.state.wishes.count)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "資源庫與數據匯出") {}

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("數據匯出")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("將所有本地數據匯出為JSON文件備份")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)

                        PrimaryButton(title: "匯出數據") {
                            exportPreview = store.createExport(format: .json)
                        }

                        if !exportPreview.isEmpty {
                            Text(exportPreview)
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("清除數據")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("清除所有本地存儲的數據，此操作不可恢復")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)

                        Button("清除所有數據") {
                            showClearConfirm = true
                        }
                        .font(.headline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("存儲空間")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        ForEach(storageRows, id: \.label) { row in
                            HStack {
                                Text(row.label)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                                Text("\(row.count) 條記錄")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.subtext)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .alert("確定要清除所有數據嗎？", isPresented: $showClearConfirm) {
            Button("取消", role: .cancel) {}
            Button("清除", role: .destructive) {
                store.clearAllLocalData()
            }
        } message: {
            Text("此操作不可恢復。")
        }
    }
}

