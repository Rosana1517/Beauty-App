import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

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
