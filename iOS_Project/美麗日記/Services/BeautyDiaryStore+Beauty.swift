import Combine
import Foundation

extension BeautyDiaryStore {
    func toggleRoutineStep(_ step: RoutineStep) {
        guard let index = state.routine.steps.firstIndex(where: { $0.id == step.id }) else { return }
        state.routine.steps[index].isChecked.toggle()
        save()
    }

    func assignProduct(_ productName: String, to step: RoutineStep) {
        guard let index = state.routine.steps.firstIndex(where: { $0.id == step.id }) else { return }
        state.routine.steps[index].productName = productName.isEmpty ? nil : productName
        save()
    }

    func addRoutineStep(period: RoutinePeriod, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.routine.steps.append(
            RoutineStep(
                id: UUID(),
                period: period,
                name: trimmed,
                productName: nil,
                isChecked: false
            )
        )
        save()
    }

    func addProduct(name: String, brand: String, category: String, notes: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.products.append(
            Product(
                id: UUID(),
                name: trimmed,
                brand: brand,
                category: category,
                notes: notes
            )
        )
        save()
    }

    func deleteProduct(_ product: Product) {
        state.products.removeAll { $0.id == product.id }
        state.routine.steps = state.routine.steps.map { step in
            var updated = step
            if updated.productName == product.name {
                updated.productName = nil
            }
            return updated
        }
        save()
    }

    func addSkinRecord(type: String, concerns: [String], note: String) {
        guard !type.isEmpty else { return }

        state.skinRecords.insert(
            SkinRecord(
                id: UUID(),
                date: Date(),
                skinType: type,
                concerns: concerns,
                note: note
            ),
            at: 0
        )
        save()
    }

    func deleteSkinRecord(_ record: SkinRecord) {
        state.skinRecords.removeAll { $0.id == record.id }
        save()
    }

    func addHairCareRecord(careType: String, note: String) {
        let trimmed = careType.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.hairCareRecords.insert(
            HairCareRecord(id: UUID(), date: Date(), careType: trimmed, note: note),
            at: 0
        )
        save()
    }

    func deleteHairCareRecord(_ record: HairCareRecord) {
        state.hairCareRecords.removeAll { $0.id == record.id }
        save()
    }

    func addBodySkinRecord(area: String, concern: String, note: String) {
        let trimmedArea = area.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedArea.isEmpty else { return }

        state.bodySkinRecords.insert(
            BodySkinRecord(id: UUID(), date: Date(), area: trimmedArea, concern: concern, note: note),
            at: 0
        )
        save()
    }

    func deleteBodySkinRecord(_ record: BodySkinRecord) {
        state.bodySkinRecords.removeAll { $0.id == record.id }
        save()
    }

    func addBodyProduct(name: String, brand: String, category: String, notes: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.bodyProducts.append(Product(id: UUID(), name: trimmed, brand: brand, category: category, notes: notes))
        save()
    }

    func deleteBodyProduct(_ product: Product) {
        state.bodyProducts.removeAll { $0.id == product.id }
        save()
    }

    func addHairProduct(name: String, brand: String, category: String, notes: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.hairProducts.append(Product(id: UUID(), name: trimmed, brand: brand, category: category, notes: notes))
        save()
    }

    func deleteHairProduct(_ product: Product) {
        state.hairProducts.removeAll { $0.id == product.id }
        save()
    }

    func addHairAppointment(title: String, storeName: String, date: Date, note: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.hairAppointments.insert(
            Appointment(id: UUID(), title: trimmed, storeName: storeName, date: date, note: note),
            at: 0
        )
        save()
    }

    func deleteHairAppointment(_ appointment: Appointment) {
        state.hairAppointments.removeAll { $0.id == appointment.id }
        save()
    }

    func adjustWashFrequency(by delta: Int) {
        state.washFrequencyDays = max(1, state.washFrequencyDays + delta)
        save()
    }

    func adjustCareFrequency(by delta: Int) {
        state.careFrequencyDays = max(1, state.careFrequencyDays + delta)
        save()
    }

    func addWhiteningProductUsage(productName: String, note: String) {
        let trimmed = productName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.whiteningProductUsages.insert(
            WhiteningProductUsage(id: UUID(), date: Date(), productName: trimmed, note: note),
            at: 0
        )
        save()
    }

    func deleteWhiteningProductUsage(_ record: WhiteningProductUsage) {
        state.whiteningProductUsages.removeAll { $0.id == record.id }
        save()
    }

    func addShadeTrackingRecord(shadeName: String, note: String) {
        let trimmed = shadeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.shadeTrackingRecords.insert(
            ShadeTrackingRecord(id: UUID(), date: Date(), shadeName: trimmed, note: note),
            at: 0
        )
        save()
    }

    func deleteShadeTrackingRecord(_ record: ShadeTrackingRecord) {
        state.shadeTrackingRecords.removeAll { $0.id == record.id }
        save()
    }

    func addBeforeAfterPhoto(beforeImageData: Data?, afterImageData: Data?, note: String) {
        guard beforeImageData != nil || afterImageData != nil else { return }

        state.beforeAfterPhotos.insert(
            BeforeAfterPhotoPair(id: UUID(), date: Date(), beforeImageData: beforeImageData, afterImageData: afterImageData, note: note),
            at: 0
        )
        save()
    }

    func deleteBeforeAfterPhoto(_ pair: BeforeAfterPhotoPair) {
        state.beforeAfterPhotos.removeAll { $0.id == pair.id }
        save()
    }

    func addFavoriteRecipe(title: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.favoriteRecipes.append(TutorialLink(id: UUID(), title: trimmed, url: url))
        save()
    }

    func deleteFavoriteRecipe(_ recipe: TutorialLink) {
        state.favoriteRecipes.removeAll { $0.id == recipe.id }
        save()
    }

    func setFaceShape(_ shape: String) {
        state.faceShape = shape
        save()
    }

    func addSavedHairstyle(title: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.savedHairstyles.append(TutorialLink(id: UUID(), title: trimmed, url: url))
        save()
    }

    func deleteSavedHairstyle(_ hairstyle: TutorialLink) {
        state.savedHairstyles.removeAll { $0.id == hairstyle.id }
        save()
    }

    func addMakeupInspiration(title: String, url: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.makeupInspirations.append(TutorialLink(id: UUID(), title: trimmed, url: url))
        save()
    }

    func deleteMakeupInspiration(_ inspiration: TutorialLink) {
        state.makeupInspirations.removeAll { $0.id == inspiration.id }
        save()
    }

}

extension BeautyDiaryStore {
    func addFaceLiftAction(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        state.faceLiftActions.append(FaceLiftAction(id: UUID(), name: trimmed))
        save()
    }

    func deleteFaceLiftAction(_ action: FaceLiftAction) {
        state.faceLiftActions.removeAll { $0.id == action.id }
        save()
    }

    func addFaceLiftPunch() {
        let calendar = Calendar.current
        let alreadyPunchedToday = state.faceLiftPunches.contains { calendar.isDateInToday($0.date) }
        guard !alreadyPunchedToday else { return }

        state.faceLiftPunches.insert(FaceLiftPunchRecord(id: UUID(), date: Date()), at: 0)
        save()
    }

    var faceLiftPunchDaysThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        let punchedDays = state.faceLiftPunches
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .compactMap { calendar.dateComponents([.day], from: $0.date).day }
        return Set(punchedDays).count
    }

    func addFaceLiftRating(score: Int, note: String) {
        state.faceLiftRatings.insert(
            FaceLiftRatingRecord(id: UUID(), date: Date(), score: score, note: note),
            at: 0
        )
        save()
    }

    func deleteFaceLiftRating(_ record: FaceLiftRatingRecord) {
        state.faceLiftRatings.removeAll { $0.id == record.id }
        save()
    }

    /// Keyed by topic so independent "type your concern -> AI suggestions"
    /// screens (skincare/hair/face-lift/body-skin/diet/makeup) don't clobber
    /// each other's results when the user switches between them.
}

