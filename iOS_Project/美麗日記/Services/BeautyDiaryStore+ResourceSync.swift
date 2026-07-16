import Combine
import Foundation

extension BeautyDiaryStore {
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

}
