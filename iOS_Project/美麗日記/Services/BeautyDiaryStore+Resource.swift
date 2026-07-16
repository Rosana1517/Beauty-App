import Combine
import Foundation

extension BeautyDiaryStore {
    func addResource(title: String, source: ImportSourceType, category: ResourceCategory, url: String, summary: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let normalizedCategory = category == .all ? .other : category
        state.resourceItems.insert(
            ResourceItem(
                title: trimmed,
                source: source,
                category: normalizedCategory,
                platformContentType: source == .youtube ? .video : (source == .web ? .article : .imagePost),
                canonicalURL: url,
                originalURL: url,
                externalID: "",
                authorName: "",
                thumbnailURL: "",
                publishedAt: nil,
                descriptionText: summary,
                tags: [],
                importStatus: .manualCompleted,
                metadataConfidence: 0.2,
                rawMetadataSnapshot: ""
            ),
            at: 0
        )
        unlockBadgeIfNeeded(title: "資源收藏家", when: state.resourceItems.count >= 10)
        save()
    }

    func setResourceFilter(_ category: ResourceCategory) {
        state.resourceFilter = category
        save()
    }

    func deleteResource(_ item: ResourceItem) {
        state.resourceItems.removeAll { $0.id == item.id }
        state.resourceImportHistory.removeAll { $0.originalURL == item.originalURL || $0.title == item.title }
        state.resourceSyncQueue.removeAll { $0.resourceID == item.id }
        save()
    }

}

extension BeautyDiaryStore {
    func importResource(from url: String) async -> ResourceImportDraft {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return markImportFailure(url: url, message: "請先貼上要匯入的內容連結。")
        }

        let parsed = await importService.parse(url: trimmed)
        let analyzed = await analysisService.analyze(draft: parsed)
        var draft = parsed
        draft = analyzed
        if draft.category == .all {
            draft.category = ResourceCategory.suggestedCategory(
                title: draft.title,
                description: draft.descriptionText,
                source: draft.source
            )
        }
        state.pendingImportDraft = draft
        save()
        return draft
    }

    func updateImportDraft(_ draft: ResourceImportDraft) {
        state.pendingImportDraft = draft
        save()
    }

    @discardableResult
    func markImportFailure(url: String, message: String) -> ResourceImportDraft {
        var draft = ResourceImportDraft.empty(url: url)
        draft.lastErrorMessage = message
        draft.importStatus = .partial
        draft.platformContentType = draft.source == .web ? .article : .unknown
        draft.analysisStatus = .fallback
        state.pendingImportDraft = draft
        save()
        return draft
    }

    func saveImportedResource(_ draft: ResourceImportDraft) {
        let trimmedTitle = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        // A completely failed fetch (e.g. unreachable host) leaves the
        // title empty - falling back to the URL instead of silently
        // dropping the save, since the "保存到資源庫" button is always
        // shown regardless of parse outcome and gives no feedback when it
        // no-ops.
        let resolvedTitle = trimmedTitle.isEmpty
            ? draft.originalURL.trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmedTitle
        guard !resolvedTitle.isEmpty else { return }

        var normalizedDraft = draft
        normalizedDraft.title = resolvedTitle
        normalizedDraft.category = draft.category == .all ? .other : draft.category
        normalizedDraft.importedAt = Date()
        normalizedDraft.temporaryMediaLeases = normalizedDraft.temporaryMediaLeases.filter { $0.cleanedAt == nil }

        if normalizedDraft.mediaRetentionPolicy == .metadataOnly {
            normalizedDraft.temporaryMediaLeases = []
            normalizedDraft.mediaAssets = normalizedDraft.selectedMediaAssets.map {
                var asset = $0
                asset.localStoragePath = nil
                asset.expiresAt = nil
                asset.retentionPolicy = .metadataOnly
                return asset
            }
        } else if normalizedDraft.mediaRetentionPolicy == .temporaryCache {
            let expiry = Date().addingTimeInterval(60 * 60)
            normalizedDraft.mediaAssets = normalizedDraft.selectedMediaAssets.map {
                var asset = $0
                asset.retentionPolicy = .temporaryCache
                asset.expiresAt = expiry
                return asset
            }
        } else {
            normalizedDraft.mediaAssets = normalizedDraft.selectedMediaAssets
        }

        if var payload = normalizedDraft.sourcePayloadSummary {
            payload.mediaAssets = normalizedDraft.mediaAssets
            normalizedDraft.sourcePayloadSummary = payload
        }

        if draft.importStatus == .partial {
            normalizedDraft.importStatus = draft.metadataConfidence < 0.2 ? .failedFallbackSaved : .manualCompleted
        } else if draft.requiresManualCompletion {
            normalizedDraft.importStatus = .manualCompleted
        } else {
            normalizedDraft.importStatus = .parsed
        }

        let resourceItem = ResourceItem(from: normalizedDraft)
        state.resourceItems.insert(resourceItem, at: 0)
        state.resourceImportHistory.insert(
            ResourceImportHistoryEntry(
                id: UUID(),
                source: normalizedDraft.source,
                title: normalizedDraft.title,
                originalURL: normalizedDraft.originalURL,
                status: normalizedDraft.importStatus,
                importedAt: normalizedDraft.importedAt ?? Date(),
                note: normalizedDraft.lastErrorMessage ?? ""
            ),
            at: 0
        )
        state.resourceSyncQueue.insert(
            ResourceSyncQueueItem(
                id: UUID(),
                resourceID: resourceItem.id,
                jobType: .importJob,
                syncTarget: "supabase",
                syncStatus: .pending,
                retryCount: 0,
                requestPayload: resourceItem.originalURL,
                lastErrorMessage: nil,
                createdAt: Date(),
                updatedAt: Date()
            ),
            at: 0
        )
        state.pendingImportDraft = nil
        unlockBadgeIfNeeded(title: "資源收藏家", when: state.resourceItems.count >= 10)
        save()

        Task {
            await syncResource(resourceItem.id)
            await scheduleMediaCleanupIfNeeded(for: resourceItem.id)
        }
    }

    func clearPendingImportDraft() {
        state.pendingImportDraft = nil
        save()
    }

    func syncPendingResources() async {
        await syncPendingResources(respectBackoff: true)
    }

    /// `respectBackoff: false` is used for explicit user-triggered syncs
    /// (e.g. `syncCloudNow()`) so a manual retry isn't silently skipped just
    /// because the automatic backoff window hasn't elapsed yet. The max
    /// retry cap still applies either way, since repeated failures usually
    /// mean a real error, not a transient one.
    func syncPendingResources(respectBackoff: Bool) async {
        let dueResourceIDs = state.resourceSyncQueue
            .filter { item in
                guard item.jobType == .importJob else { return false }
                guard item.syncStatus == .pending || item.syncStatus == .failed else { return false }
                guard item.retryCount < Self.maxResourceSyncRetryCount else { return false }
                return !respectBackoff || isDueForRetry(item)
            }
            .map(\.resourceID)

        for resourceID in Set(dueResourceIDs) {
            await syncResource(resourceID)
        }
    }

    static let maxResourceSyncRetryCount = 5

    func backoffInterval(forRetryCount retryCount: Int) -> TimeInterval {
        min(pow(2.0, Double(retryCount)) * 5, 300)
    }

    func isDueForRetry(_ item: ResourceSyncQueueItem) -> Bool {
        guard item.syncStatus == .failed else { return true }
        return Date().timeIntervalSince(item.updatedAt) >= backoffInterval(forRetryCount: item.retryCount)
    }

    func isTransientNetworkError(_ error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }

    func requestBackendReparse(for item: ResourceItem, reason: String) async {
        do {
            let queueItem = try await cloudSyncService.enqueueReparse(for: item, reason: reason)
            state.resourceSyncQueue.insert(queueItem, at: 0)
            save()
        } catch {
            appendSyncFailure(resourceID: item.id, message: "建立重解析佇列失敗：\(error.localizedDescription)")
        }
    }

    func refreshCloudResources() async {
        await refreshCloudResources(allowRetry: true)
    }

    func refreshCloudResources(allowRetry: Bool) async {
        do {
            let remoteItems = try await cloudSyncService.fetchResources()
            guard !remoteItems.isEmpty else { return }
            state.resourceItems = merge(local: state.resourceItems, remote: remoteItems)
            save()
        } catch {
            if allowRetry, await recoverSessionIfNeeded(after: error) {
                await refreshCloudResources(allowRetry: false)
            }
            return
        }
    }

    func restoreAuthSession() async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else {
            authStatus = .unavailable
            authSession = nil
            authMessage = "Supabase 尚未設定。"
            return
        }

        authStatus = .restoring
        authMessage = nil
        authSession = await authService.restoreSession()

        if authSession == nil {
            authStatus = .signedOut
            return
        }

        authStatus = .authenticated
        await reconcileCurrentUserProfileWithCloud()
        await fetchAIProviderSettingsFromCloud()
        await refreshCloudResources()
        await syncPendingResources()
    }

    func signUpToSupabase(email: String, password: String) async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else {
            authStatus = .unavailable
            authMessage = "Supabase 尚未設定。"
            return
        }

        authStatus = .authenticating
        authMessage = nil

        do {
            let session = try await authService.signUp(email: email, password: password)
            if let session {
                authSession = session
                authStatus = .authenticated
                authMessage = "註冊成功，已自動登入。"
                await reconcileCurrentUserProfileWithCloud()
                await fetchAIProviderSettingsFromCloud()
                await refreshCloudResources()
                await syncPendingResources()
            } else {
                authStatus = .signedOut
                authMessage = "帳號已建立，請至信箱完成驗證後再登入。"
            }
        } catch {
            authStatus = .signedOut
            authMessage = error.localizedDescription
        }
    }

    func signInToSupabase(email: String, password: String) async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else {
            authStatus = .unavailable
            authMessage = "Supabase 尚未設定。"
            return
        }

        authStatus = .authenticating
        authMessage = nil

        do {
            let session = try await authService.signIn(email: email, password: password)
            authSession = session
            authStatus = .authenticated
            authMessage = "登入成功，雲端同步已就緒。"
            await reconcileCurrentUserProfileWithCloud()
            await fetchAIProviderSettingsFromCloud()
            await refreshCloudResources()
            await syncPendingResources()
        } catch {
            authSession = nil
            authStatus = .signedOut
            authMessage = error.localizedDescription
        }
    }

    func handleSupabaseAuthCallback(_ url: URL) async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else { return }
        guard isSupabaseCallbackURL(url) else { return }

        authStatus = .authenticating
        authMessage = nil

        do {
            let session = try await authService.completeMagicLinkSignIn(from: url)
            authSession = session
            authStatus = .authenticated
            authMessage = "已透過 Email 連結完成登入。"
            await reconcileCurrentUserProfileWithCloud()
            await fetchAIProviderSettingsFromCloud()
            await refreshCloudResources()
            await syncPendingResources()
        } catch {
            authSession = nil
            authStatus = .signedOut
            authMessage = error.localizedDescription
        }
    }

    func requestSupabaseMagicLink(email: String) async {
        guard AppRuntimeConfiguration.hasSupabaseConfig else {
            authStatus = .unavailable
            authMessage = "Supabase 尚未設定。"
            return
        }

        authStatus = .authenticating
        authMessage = nil

        do {
            try await authService.requestMagicLink(email: email)
            authStatus = authSession == nil ? .signedOut : .authenticated
            authMessage = "登入連結已寄出，請至信箱完成登入。"
        } catch {
            authStatus = authSession == nil ? .signedOut : .authenticated
            authMessage = error.localizedDescription
        }
    }

    func signOutFromSupabase() async {
        do {
            try await authService.signOut()
        } catch {
            authMessage = error.localizedDescription
        }

        authSession = nil
        authStatus = AppRuntimeConfiguration.hasSupabaseConfig ? .signedOut : .unavailable
    }

    func syncCloudNow() async {
        guard authSession != nil else {
            authMessage = "請先登入 Supabase 才能同步。"
            return
        }

        authMessage = nil
        await reconcileCurrentUserProfileWithCloud()
        await syncPendingResources(respectBackoff: false)
        await refreshCloudResources()
        authMessage = "雲端同步完成。"
    }

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

    func syncResource(_ resourceID: UUID) async {
        await syncResource(resourceID, allowSessionRetry: true, allowTransientRetry: true)
    }

    func syncResource(_ resourceID: UUID, allowSessionRetry: Bool, allowTransientRetry: Bool) async {
        guard let resourceIndex = state.resourceItems.firstIndex(where: { $0.id == resourceID }) else { return }

        updateSyncState(for: resourceID, jobType: .importJob, status: .syncing, errorMessage: nil)
        do {
            let result = try await cloudSyncService.pushResource(state.resourceItems[resourceIndex])
            state.resourceItems[resourceIndex].syncStatus = .succeeded
            state.resourceItems[resourceIndex].remoteRecordID = result.remoteRecordID
            state.resourceItems[resourceIndex].lastSyncedAt = result.syncedAt
            updateSyncState(for: resourceID, jobType: .importJob, status: .succeeded, errorMessage: nil)
            save()
            await applyBackendRecommendationsIfNeeded(for: state.resourceItems[resourceIndex])
            await requestVideoTranscriptionIfNeeded(for: state.resourceItems[resourceIndex])
        } catch {
            if allowSessionRetry, await recoverSessionIfNeeded(after: error) {
                await syncResource(resourceID, allowSessionRetry: false, allowTransientRetry: allowTransientRetry)
                return
            }
            // A single short-delay retry for transient network blips (timeout,
            // dropped connection) so a flaky network during bulk import
            // doesn't immediately burn through the queue's retry budget.
            if allowTransientRetry, isTransientNetworkError(error) {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await syncResource(resourceID, allowSessionRetry: false, allowTransientRetry: false)
                return
            }
            state.resourceItems[resourceIndex].syncStatus = .failed
            updateSyncState(for: resourceID, jobType: .importJob, status: .failed, errorMessage: error.localizedDescription)
            save()
        }
    }

    func scheduleMediaCleanupIfNeeded(for resourceID: UUID) async {
        guard let resource = state.resourceItems.first(where: { $0.id == resourceID }) else { return }
        guard resource.mediaRetentionPolicy != .explicitKeep else { return }
        guard !resource.mediaAssets.isEmpty || !resource.temporaryMediaLeases.isEmpty else { return }

        do {
            let queueItem = try await cloudSyncService.enqueueMediaCleanup(for: resource)
            state.resourceSyncQueue.insert(queueItem, at: 0)
            save()
        } catch {
            appendSyncFailure(resourceID: resourceID, message: "建立媒體清理佇列失敗：\(error.localizedDescription)")
        }
    }

    func updateSyncState(for resourceID: UUID, jobType: ResourceSyncJobType, status: ResourceSyncStatus, errorMessage: String?) {
        if let queueIndex = state.resourceSyncQueue.firstIndex(where: { $0.resourceID == resourceID && $0.jobType == jobType }) {
            state.resourceSyncQueue[queueIndex].syncStatus = status
            state.resourceSyncQueue[queueIndex].updatedAt = Date()
            state.resourceSyncQueue[queueIndex].lastErrorMessage = errorMessage
            if status == .failed {
                state.resourceSyncQueue[queueIndex].retryCount += 1
            }
        } else {
            state.resourceSyncQueue.insert(
                ResourceSyncQueueItem(
                    id: UUID(),
                    resourceID: resourceID,
                    jobType: jobType,
                    syncTarget: "supabase",
                    syncStatus: status,
                    retryCount: status == .failed ? 1 : 0,
                    requestPayload: "",
                    lastErrorMessage: errorMessage,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                at: 0
            )
        }
    }

    func appendSyncFailure(resourceID: UUID, message: String) {
        updateSyncState(for: resourceID, jobType: .importJob, status: .failed, errorMessage: message)
        save()
    }

    func merge(local: [ResourceItem], remote: [ResourceItem]) -> [ResourceItem] {
        var merged = local
        for remoteItem in remote {
            if let index = merged.firstIndex(where: { $0.remoteRecordID == remoteItem.remoteRecordID && !$0.remoteRecordID.isEmpty }) {
                guard canOverwriteWithRemote(merged[index]) else { continue }
                merged[index] = remoteItem
            } else if let index = merged.firstIndex(where: { $0.originalURL == remoteItem.originalURL && $0.source == remoteItem.source }) {
                guard canOverwriteWithRemote(merged[index]) else { continue }
                merged[index] = remoteItem
            } else {
                merged.append(remoteItem)
            }
        }
        return merged.sorted { $0.importedAt > $1.importedAt }
    }

    /// Local edits made while a push is pending/in-flight/failed haven't been
    /// confirmed by the server yet. If a cloud refresh overwrote them with
    /// (possibly stale) remote data, the unsynced local change would be lost
    /// silently. Only items the server has already acknowledged
    /// (`.succeeded`) are safe to replace wholesale here; pending ones will
    /// reconcile themselves once `syncPendingResources()` pushes them up.
    func canOverwriteWithRemote(_ localItem: ResourceItem) -> Bool {
        localItem.syncStatus == .succeeded
    }

}

