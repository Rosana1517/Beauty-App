import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct HabitRemindersCard: View {
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

struct HabitReminderRow: View {
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

struct AIProviderSettingsCard: View {
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
struct SupabaseSyncSettingsCard: View {
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


