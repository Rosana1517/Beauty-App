import Combine
import Foundation

extension BeautyDiaryStore {
    func updateProfile(nickname: String, signature: String, bodyFocus: String, skincareFocus: String, notificationTime: String) {
        state.profile.nickname = nickname
        state.profile.signature = signature
        state.profile.bodyFocus = bodyFocus
        state.profile.skincareFocus = skincareFocus
        state.profile.notificationTime = notificationTime
        save()

        Task {
            await scheduleDailyReminderIfPossible(requestPermission: false)
        }

        guard authSession != nil else { return }
        Task {
            await syncCurrentUserProfileIfNeeded()
        }
    }

    func enableDailyReminder() async {
        await scheduleDailyReminderIfPossible(requestPermission: true)
    }

    func setThemeName(_ name: String) {
        state.profile.themeName = name
        save()
    }

    func setMorningReminderTime(_ time: String) {
        state.profile.morningReminderTime = time
        save()
    }

    func setEveningReminderTime(_ time: String) {
        state.profile.notificationTime = time
        save()
    }

    func toggleModule(_ module: String) {
        if state.profile.enabledModules.contains(module) {
            state.profile.enabledModules.remove(module)
        } else {
            state.profile.enabledModules.insert(module)
        }
        save()
    }

    func clearAllLocalData() {
        state = .seed
        save()
    }

    var hasPerfectChecklistDay: Bool {
        guard !state.checklistItems.isEmpty else { return false }
        let grouped = Dictionary(grouping: state.checklistCompletions) { Calendar.current.startOfDay(for: $0.date) }
        return grouped.values.contains { dayEntries in
            Set(dayEntries.map(\.itemID)).count >= state.checklistItems.count
        }
    }

    var hasUsedBeautyModule: Bool {
        !state.skinRecords.isEmpty || !state.hairCareRecords.isEmpty || !state.faceLiftActions.isEmpty || !state.bodySkinRecords.isEmpty
    }

    var hasUsedBodyModule: Bool {
        !state.bodyMetricRecords.isEmpty || !state.exercisePunches.isEmpty || !state.mealRecords.isEmpty
    }

    var hasUsedGrowthModule: Bool {
        !state.bookRecords.isEmpty || !state.courses.isEmpty || !state.knowledgeNotes.isEmpty
    }

    var knowledgeRecordCount: Int {
        state.knowledgeNotes.count + state.courses.count + state.bookRecords.count + state.videoLearningRecords.count
    }

    func createExport(format: ExportFormat) -> String {
        let summary = format == .json
            ? "本地 JSON 匯出預覽：包含護膚、體態、成長與資源摘要。"
            : "PDF 報告預覽：護膚步驟、體態趨勢、閱讀進度與資源整理。"

        state.exportHistory.insert(
            ExportRecord(
                id: UUID(),
                format: format,
                createdAt: Date(),
                summary: summary
            ),
            at: 0
        )
        save()
        return summary
    }

}
