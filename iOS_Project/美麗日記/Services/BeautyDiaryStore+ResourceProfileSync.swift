import Combine
import Foundation

extension BeautyDiaryStore {
    func applyBackendRecommendationsIfNeeded(for item: ResourceItem) async {
        do {
            let cards = try await cloudSyncService.requestRecommendations(for: item)
            guard let index = state.resourceItems.firstIndex(where: { $0.id == item.id }), !cards.isEmpty else { return }
            state.resourceItems[index].recommendationCards = cards
            state.resourceItems[index].analysisStatus = .analyzed
            save()
        } catch {
            return
        }
    }

    /// 小紅書影片筆記同步成功後，背景觸發雲端語音轉錄整理教學步驟。
    /// 非同步、不等待完成也不擋 UI；結果之後靠 refreshCloudResources 帶回。
    func requestVideoTranscriptionIfNeeded(for item: ResourceItem) async {
        guard item.source == .xiaohongshu,
              item.platformContentType == .video,
              !item.remoteRecordID.isEmpty,
              !item.descriptionText.contains("📋 教學步驟") else { return }
        guard let videoURL = item.mediaAssets.first(where: { $0.type == .video })?.remoteURL,
              !videoURL.isEmpty else { return }

        await cloudSyncService.requestVideoTranscription(resourceRemoteID: item.remoteRecordID, videoURL: videoURL)
    }

    func unlockBadgeIfNeeded(title: String, when condition: Bool) {
        guard condition, let index = state.achievements.firstIndex(where: { $0.title == title }) else { return }
        state.achievements[index].unlocked = true
    }

    func cleanupExpiredTemporaryMedia(now: Date = Date()) {
        state.resourceItems = state.resourceItems.map { item in
            var updated = item
            let activeLeases = item.temporaryMediaLeases.filter { lease in
                lease.cleanedAt == nil && lease.expiresAt > now
            }
            updated.temporaryMediaLeases = activeLeases
            if item.mediaRetentionPolicy == .temporaryCache {
                updated.mediaAssets = item.mediaAssets.map { asset in
                    var mutable = asset
                    if let expiresAt = asset.expiresAt, expiresAt <= now {
                        mutable.localStoragePath = nil
                        mutable.retentionPolicy = .metadataOnly
                    }
                    return mutable
                }
            }
            return updated
        }
    }

    func scheduleDailyReminderIfPossible(requestPermission: Bool) async {
        let reminderTime = state.profile.notificationTime.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reminderTime.isEmpty else { return }

        do {
            let isAuthorized = requestPermission
                ? try await notificationScheduler.requestAuthorizationIfNeeded()
                : true
            guard isAuthorized else {
                authMessage = "通知權限已關閉，請至「設定」開啟才能收到提醒。"
                return
            }
            try await notificationScheduler.scheduleDailyReminder(
                timeString: reminderTime,
                nickname: state.profile.nickname
            )
        } catch {
            authMessage = error.localizedDescription
        }
    }

    func syncCurrentUserProfileIfNeeded() async {
        await syncCurrentUserProfileIfNeeded(allowRetry: true)
    }

    func syncCurrentUserProfileIfNeeded(allowRetry: Bool) async {
        guard let session = authSession else { return }

        do {
            try await cloudSyncService.upsertCurrentUserProfile(session: session, profile: state.profile)
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await syncCurrentUserProfileIfNeeded(allowRetry: false)
                return
            }
            authMessage = error.localizedDescription
        }
    }

    func reconcileCurrentUserProfileWithCloud() async {
        await reconcileCurrentUserProfileWithCloud(allowRetry: true)
    }

    func reconcileCurrentUserProfileWithCloud(allowRetry: Bool) async {
        guard let session = authSession else { return }

        do {
            if let remoteProfile = try await cloudSyncService.fetchCurrentUserProfile(session: session),
               shouldAdoptRemoteProfile(remoteProfile) {
                state.profile = remoteProfile
                save()
            }

            try await cloudSyncService.upsertCurrentUserProfile(session: session, profile: state.profile)
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await reconcileCurrentUserProfileWithCloud(allowRetry: false)
                return
            }
            authMessage = error.localizedDescription
        }
    }

    /// Saves the signed-in user's own AI provider config (URL/key/model) to
    /// their RLS-scoped row in `user_ai_provider_settings`. Each user brings
    /// their own key instead of sharing one baked into backend env vars.
    func saveAIProviderSettings(_ settings: AIProviderSettings) async {
        await saveAIProviderSettings(settings, allowRetry: true)
    }

    func saveAIProviderSettings(_ settings: AIProviderSettings, allowRetry: Bool) async {
        state.aiProviderSettings = settings
        save()

        guard let session = authSession else {
            authMessage = "登入 Supabase 後，AI 設定才能同步到其他裝置。"
            return
        }

        do {
            try await cloudSyncService.upsertAIProviderSettings(session: session, settings: settings)
            authMessage = "AI 提供者設定已儲存。"
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await saveAIProviderSettings(settings, allowRetry: false)
                return
            }
            authMessage = "已儲存在本機，但雲端同步失敗：\(error.localizedDescription)"
        }
    }

    func clearAIProviderSettings() async {
        await clearAIProviderSettings(allowRetry: true)
    }

    func clearAIProviderSettings(allowRetry: Bool) async {
        state.aiProviderSettings = nil
        save()

        guard let session = authSession else { return }

        do {
            try await cloudSyncService.deleteAIProviderSettings(session: session)
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await clearAIProviderSettings(allowRetry: false)
                return
            }
            authMessage = "已從本機移除，但雲端刪除失敗：\(error.localizedDescription)"
        }
    }

    func fetchAIProviderSettingsFromCloud() async {
        await fetchAIProviderSettingsFromCloud(allowRetry: true)
    }

    func fetchAIProviderSettingsFromCloud(allowRetry: Bool) async {
        guard let session = authSession else { return }

        do {
            if let remoteSettings = try await cloudSyncService.fetchAIProviderSettings(session: session) {
                state.aiProviderSettings = remoteSettings
                save()
            }
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await fetchAIProviderSettingsFromCloud(allowRetry: false)
                return
            }
            // Non-fatal: keep whatever AI provider settings are already
            // cached locally rather than surfacing this as a user-facing error.
        }
    }

    func recoverSessionIfNeeded(after error: Error) async -> Bool {
        guard case SupabaseRESTError.unauthorized = error else { return false }
        let restoredSession = await authService.restoreSession()
        guard let restoredSession else {
            authSession = nil
            authStatus = .signedOut
            authMessage = "登入已過期，請重新登入。"
            return false
        }

        authSession = restoredSession
        authStatus = .authenticated
        authMessage = "登入狀態已更新，正在重新同步。"
        return true
    }

    func shouldAdoptRemoteProfile(_ remoteProfile: UserProfileRecord) -> Bool {
        guard remoteProfile != state.profile else { return false }
        return state.profile == BeautyDiaryState.seed.profile
    }

    func isSupabaseCallbackURL(_ url: URL) -> Bool {
        guard let redirectURL = URL(string: AppRuntimeConfiguration.supabaseAuthRedirectURL),
              let callbackComponents = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let expectedComponents = URLComponents(url: redirectURL, resolvingAgainstBaseURL: false) else {
            return false
        }

        let sameScheme = callbackComponents.scheme?.caseInsensitiveCompare(expectedComponents.scheme ?? "") == .orderedSame
        let sameHost = (callbackComponents.host ?? "").caseInsensitiveCompare(expectedComponents.host ?? "") == .orderedSame
        let samePath = callbackComponents.path == expectedComponents.path
        return sameScheme && sameHost && samePath
    }

}
