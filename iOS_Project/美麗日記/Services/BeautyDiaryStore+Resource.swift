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

}
