import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct AddStepSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var period: RoutinePeriod = .morning
    @State private var name = ""

    var body: some View {
        FormSheet(title: "新增步驟") {
            Picker("時段", selection: $period) {
                ForEach(RoutinePeriod.allCases) { item in
                    Text(item.rawValue).tag(item)
                }
            }
            .pickerStyle(.segmented)

            ThemedTextField(title: "新增步驟", text: $name)

            PrimaryButton(title: "保存") {
                store.addRoutineStep(period: period, name: name)
                dismiss()
            }
        }
    }
}

struct AddProductSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var name = ""
    @State private var brand = ""
    @State private var category = ""
    @State private var notes = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    /// nil defaults to the skincare product list (the original use of this
    /// sheet); 身體保養品/洗護產品 pass their own store method so the same
    /// form can add to a different list without duplicating the sheet.
    var onSave: ((String, String, String, String) -> Void)?
    var title: String = "新增保養品"

    var body: some View {
        FormSheet(title: title) {
            VStack(alignment: .leading, spacing: 10) {
                Text("AI 自動辨識（選填）")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text("拍照或輸入名稱，AI 幫你自動填入品牌、分類與備註。")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)

                if let photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                HStack(spacing: 10) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Text("拍照辨識")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.primarySoft)
                            .clipShape(Capsule())
                    }

                    Button {
                        Task { await runLookup(usePhoto: false) }
                    } label: {
                        Text("依名稱查詢")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.primarySoft)
                            .clipShape(Capsule())
                    }
                }

                if store.isLookingUpProduct {
                    Text("AI 辨識中…")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }

                if let error = store.productLookupError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .onChange(of: photoItem) { newItem in
                Task {
                    guard let newItem, let data = try? await newItem.loadTransferable(type: Data.self) else { return }
                    photoData = data
                    await runLookup(usePhoto: true)
                }
            }

            ThemedTextField(title: "產品名稱", text: $name)
            ThemedTextField(title: "品牌", text: $brand)
            ThemedTextField(title: "分類", text: $category)
            ThemedTextField(title: "備註", text: $notes)

            PrimaryButton(title: "保存") {
                if let onSave {
                    onSave(name, brand, category, notes)
                } else {
                    store.addProduct(name: name, brand: brand, category: category, notes: notes)
                }
                dismiss()
            }
        }
    }

    private func runLookup(usePhoto: Bool) async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard usePhoto || !trimmedName.isEmpty else { return }

        let result = await store.requestProductLookup(
            name: trimmedName.isEmpty ? nil : trimmedName,
            imageData: usePhoto ? photoData : nil
        )
        guard let result else { return }

        if name.isEmpty { name = result.name }
        if brand.isEmpty { brand = result.brand }
        if category.isEmpty { category = result.category }
        if notes.isEmpty { notes = result.notes }
    }
}

struct AddSkinRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    let concerns: [String]

    @State private var type = "混合肌"
    @State private var selected: Set<String> = []
    @State private var note = ""

    var body: some View {
        FormSheet(title: "膚況記錄") {
            ThemedTextField(title: "膚質類型", text: $type)
            WrapToggleChips(items: concerns, selection: $selected)
            ThemedTextField(title: "補充說明", text: $note)

            PrimaryButton(title: "保存") {
                store.addSkinRecord(type: type, concerns: Array(selected), note: note)
                dismiss()
            }
        }
    }
}

/// Generic title+url add form, shared by 收藏食譜/髮型收藏/妝容靈感 (and
/// anything else that's just "save a link with a title").
struct AddLinkSheet: View {
    @Environment(\.dismiss) private var dismiss
    let sheetTitle: String
    let titleFieldLabel: String
    let onSave: (String, String) -> Void

    @State private var title = ""
    @State private var url = ""

    var body: some View {
        FormSheet(title: sheetTitle) {
            ThemedTextField(title: titleFieldLabel, text: $title)
            ThemedTextField(title: "連結（選填）", text: $url)

            PrimaryButton(title: "保存") {
                onSave(title, url)
                dismiss()
            }
        }
    }
}

struct AddWhiteningProductUsageSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var productName = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增產品使用記錄") {
            ThemedTextField(title: "產品名稱", text: $productName)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addWhiteningProductUsage(productName: productName, note: note)
                dismiss()
            }
        }
    }
}

struct AddShadeTrackingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var shadeName = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增色號記錄") {
            ThemedTextField(title: "色號", text: $shadeName)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addShadeTrackingRecord(shadeName: shadeName, note: note)
                dismiss()
            }
        }
    }
}

struct AddBeforeAfterPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var beforeItem: PhotosPickerItem?
    @State private var afterItem: PhotosPickerItem?
    @State private var beforeData: Data?
    @State private var afterData: Data?
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增前後對比照") {
            HStack(spacing: 16) {
                photoPickerSlot(label: "前", item: $beforeItem, data: $beforeData)
                photoPickerSlot(label: "後", item: $afterItem, data: $afterData)
            }

            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addBeforeAfterPhoto(beforeImageData: beforeData, afterImageData: afterData, note: note)
                dismiss()
            }
        }
    }

    private func photoPickerSlot(label: String, item: Binding<PhotosPickerItem?>, data: Binding<Data?>) -> some View {
        VStack(spacing: 6) {
            PhotosPicker(selection: item, matching: .images) {
                if let value = data.wrappedValue, let uiImage = UIImage(data: value) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 90, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.primarySoft)
                        .frame(width: 90, height: 90)
                        .overlay(Image(systemName: "camera").foregroundStyle(AppTheme.primary))
                }
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
        }
        .onChange(of: item.wrappedValue) { newItem in
            Task {
                if let newItem, let loaded = try? await newItem.loadTransferable(type: Data.self) {
                    data.wrappedValue = loaded
                }
            }
        }
    }
}

