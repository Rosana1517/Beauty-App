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

}
