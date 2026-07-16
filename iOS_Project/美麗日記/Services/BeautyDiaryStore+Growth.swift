import Combine
import Foundation

extension BeautyDiaryStore {
    func addCourse(title: String, platform: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.courses.append(Course(id: UUID(), title: trimmed, platform: platform, url: url, progressPercent: 0))
        save()
    }

    func deleteCourse(_ course: Course) {
        state.courses.removeAll { $0.id == course.id }
        save()
    }

    func updateCourseProgress(_ course: Course, progressPercent: Int) {
        guard let index = state.courses.firstIndex(where: { $0.id == course.id }) else { return }
        state.courses[index].progressPercent = min(100, max(0, progressPercent))
        save()
    }

    func addKnowledgeNote(title: String, content: String, tags: [String]) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.knowledgeNotes.insert(
            KnowledgeNote(id: UUID(), date: Date(), title: trimmed, content: content, tags: tags),
            at: 0
        )
        save()
    }

    func deleteKnowledgeNote(_ note: KnowledgeNote) {
        state.knowledgeNotes.removeAll { $0.id == note.id }
        save()
    }

    func addVideoLearningRecord(title: String, contentType: String, platform: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.videoLearningRecords.append(
            VideoLearningRecord(id: UUID(), title: trimmed, contentType: contentType, platform: platform, url: url, watched: false)
        )
        save()
    }

    func toggleVideoLearningWatched(_ record: VideoLearningRecord) {
        guard let index = state.videoLearningRecords.firstIndex(where: { $0.id == record.id }) else { return }
        state.videoLearningRecords[index].watched.toggle()
        save()
    }

    func deleteVideoLearningRecord(_ record: VideoLearningRecord) {
        state.videoLearningRecords.removeAll { $0.id == record.id }
        save()
    }

    func addSelfAffirmation(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.selfAffirmations.append(SelfAffirmation(id: UUID(), text: trimmed))
        save()
    }

    func deleteSelfAffirmation(_ item: SelfAffirmation) {
        state.selfAffirmations.removeAll { $0.id == item.id }
        save()
    }

    func addVisionBoardItem(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.visionBoardItems.append(VisionBoardItem(id: UUID(), text: trimmed))
        save()
    }

    func deleteVisionBoardItem(_ item: VisionBoardItem) {
        state.visionBoardItems.removeAll { $0.id == item.id }
        save()
    }

    func addGratitudeEntry(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.gratitudeEntries.insert(GratitudeEntry(id: UUID(), date: Date(), text: trimmed), at: 0)
        save()
    }

    func deleteGratitudeEntry(_ entry: GratitudeEntry) {
        state.gratitudeEntries.removeAll { $0.id == entry.id }
        save()
    }

    func addMoodEntry(mood: String, note: String) {
        state.moodEntries.insert(MoodEntry(id: UUID(), date: Date(), mood: mood, note: note), at: 0)
        save()
    }

    func deleteMoodEntry(_ entry: MoodEntry) {
        state.moodEntries.removeAll { $0.id == entry.id }
        save()
    }

}

extension BeautyDiaryStore {
    func addBook(title: String, author: String, link: String, note: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.bookRecords.insert(
            BookRecord(
                id: UUID(),
                title: trimmed,
                author: author,
                link: link,
                note: note
            ),
            at: 0
        )
        save()
    }

    func deleteBook(_ book: BookRecord) {
        state.bookRecords.removeAll { $0.id == book.id }
        save()
    }

}

