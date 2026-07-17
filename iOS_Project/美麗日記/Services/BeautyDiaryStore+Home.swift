import Combine
import Foundation

extension BeautyDiaryStore {
    func toggleChecklist(_ item: ChecklistItem) {
        if isChecklistItemCompletedToday(item) {
            state.checklistCompletions.removeAll { $0.itemID == item.id && Calendar.current.isDateInToday($0.date) }
        } else {
            state.checklistCompletions.append(ChecklistCompletionEntry(id: UUID(), itemID: item.id, date: Date()))
        }
        save()
    }

    func addCustomChecklistItem(title: String, category: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.checklistItems.append(ChecklistItem(id: UUID(), title: trimmed, category: category))
        save()
    }

    func deleteChecklistItem(_ item: ChecklistItem) {
        state.checklistItems.removeAll { $0.id == item.id }
        state.checklistCompletions.removeAll { $0.itemID == item.id }
        save()
    }

}
