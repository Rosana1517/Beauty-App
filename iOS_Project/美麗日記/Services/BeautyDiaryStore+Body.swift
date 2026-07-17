import Combine
import Foundation

extension BeautyDiaryStore {
    func addExercisePunch(category: String, durationMinutes: Int) {
        state.exercisePunches.insert(
            ExercisePunchRecord(id: UUID(), date: Date(), category: category, durationMinutes: durationMinutes),
            at: 0
        )
        save()
    }

    func deleteExercisePunch(_ record: ExercisePunchRecord) {
        state.exercisePunches.removeAll { $0.id == record.id }
        save()
    }

    func addCustomExercise(name: String, linkedResourceRemoteID: String? = nil) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // 同一篇教學筆記不重複加入
        if let linkedResourceRemoteID,
           state.customExercises.contains(where: { $0.linkedResourceRemoteID == linkedResourceRemoteID }) {
            return
        }

        state.customExercises.append(
            CustomExercise(id: UUID(), name: trimmed, linkedResourceRemoteID: linkedResourceRemoteID)
        )
        save()
    }

    func deleteCustomExercise(_ exercise: CustomExercise) {
        state.customExercises.removeAll { $0.id == exercise.id }
        save()
    }

    func setShapingGoal(targetWeight: Double?, targetBodyFat: Double?) {
        state.targetWeight = targetWeight
        state.targetBodyFat = targetBodyFat
        save()
    }

    func addTrainingScheduleItem(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.trainingSchedule.append(TrainingScheduleItem(id: UUID(), name: trimmed))
        save()
    }

    func deleteTrainingScheduleItem(_ item: TrainingScheduleItem) {
        state.trainingSchedule.removeAll { $0.id == item.id }
        save()
    }

    var exerciseCompletionRates: (week: Int, month: Int, total: Int) {
        let calendar = Calendar.current
        let now = Date()
        let weekCount = state.exercisePunches.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .weekOfYear) }.count
        let monthCount = state.exercisePunches.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }.count
        let weeklyGoal = 7
        let monthlyGoal = 30
        let weekPercent = min(100, Int(Double(weekCount) / Double(weeklyGoal) * 100))
        let monthPercent = min(100, Int(Double(monthCount) / Double(monthlyGoal) * 100))
        return (weekPercent, monthPercent, state.exercisePunches.count)
    }

    func addSymptomRecord(symptom: String, note: String) {
        let trimmed = symptom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.symptomRecords.insert(
            SymptomRecord(id: UUID(), date: Date(), symptom: trimmed, note: note),
            at: 0
        )
        save()
    }

    func deleteSymptomRecord(_ record: SymptomRecord) {
        state.symptomRecords.removeAll { $0.id == record.id }
        save()
    }

    var symptomFrequency: [(symptom: String, count: Int)] {
        let grouped = Dictionary(grouping: state.symptomRecords, by: \.symptom)
        return grouped.map { (symptom: $0.key, count: $0.value.count) }.sorted { $0.count > $1.count }
    }

    func addMenstrualRecord(note: String) {
        state.menstrualRecords.insert(MenstrualRecord(id: UUID(), date: Date(), note: note), at: 0)
        save()
    }

    func deleteMenstrualRecord(_ record: MenstrualRecord) {
        state.menstrualRecords.removeAll { $0.id == record.id }
        save()
    }

    func addNourishmentRecipe(title: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.nourishmentRecipes.append(TutorialLink(id: UUID(), title: trimmed, url: url))
        save()
    }

    func deleteNourishmentRecipe(_ link: TutorialLink) {
        state.nourishmentRecipes.removeAll { $0.id == link.id }
        save()
    }

    func setBodyConstitution(_ constitution: String) {
        state.bodyConstitution = constitution
        save()
    }

    func addBodyAlbumPhoto(imageData: Data?, note: String) {
        guard let imageData else { return }

        state.bodyAlbumPhotos.insert(
            BodyAlbumPhoto(id: UUID(), date: Date(), imageData: imageData, note: note),
            at: 0
        )
        save()
    }

    func deleteBodyAlbumPhoto(_ photo: BodyAlbumPhoto) {
        state.bodyAlbumPhotos.removeAll { $0.id == photo.id }
        save()
    }

}

extension BeautyDiaryStore {
    func addPunchRecord(summary: String) {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.punchRecords.insert(
            PunchRecord(id: UUID(), date: Date(), summary: trimmed),
            at: 0
        )
        state.profile.streakDays += 1
        save()
    }

    func addAppointment(title: String, storeName: String, date: Date, note: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.appointments.insert(
            Appointment(
                id: UUID(),
                title: trimmed,
                storeName: storeName,
                date: date,
                note: note
            ),
            at: 0
        )
        save()
    }

    func deleteAppointment(_ appointment: Appointment) {
        state.appointments.removeAll { $0.id == appointment.id }
        save()
    }

    func addBodyMetric(weight: Double, bodyFat: Double, note: String) {
        state.bodyMetricRecords.insert(
            BodyMetricRecord(
                id: UUID(),
                date: Date(),
                weight: weight,
                bodyFat: bodyFat,
                note: note
            ),
            at: 0
        )
        save()
    }

    func deleteBodyMetric(_ record: BodyMetricRecord) {
        state.bodyMetricRecords.removeAll { $0.id == record.id }
        save()
    }

    func addMealRecord(type: String, summary: String, note: String, calories: Int? = nil, photoData: Data? = nil) {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.mealRecords.insert(
            MealRecord(
                id: UUID(),
                date: Date(),
                mealType: type,
                summary: trimmed,
                note: note,
                calories: calories ?? CalorieEstimator.estimate(from: trimmed),
                photoData: photoData
            ),
            at: 0
        )
        save()
    }

    /// 今日各餐與總熱量
    func todayCalorieSummary() -> (meals: [MealRecord], total: Int) {
        let todays = state.mealRecords.filter { Calendar.current.isDateInToday($0.date) }
        let total = todays.compactMap(\.calories).reduce(0, +)
        return (todays, total)
    }

    func deleteMealRecord(_ record: MealRecord) {
        state.mealRecords.removeAll { $0.id == record.id }
        save()
    }

}
