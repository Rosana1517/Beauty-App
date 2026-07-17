import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

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
