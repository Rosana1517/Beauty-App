import Combine
import Foundation

extension BeautyDiaryStore {
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
