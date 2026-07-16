import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts


struct GenericSummaryView: View {
    let title: String
    let subtitle: String

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: title) {}

                CardView {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtext)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}

private struct AddStepSheet: View {
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

private struct AddProductSheet: View {
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

private struct AddSkinRecordSheet: View {
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
private struct AddLinkSheet: View {
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

private struct AddWhiteningProductUsageSheet: View {
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

private struct AddShadeTrackingSheet: View {
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

private struct AddBeforeAfterPhotoSheet: View {
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

private struct CustomizeChecklistSheet: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var newTitle = ""
    @State private var newCategory = "變美"

    private let categories = ["變美", "體態", "成長"]

    var body: some View {
        FormSheet(title: "自訂打卡項目") {
            HStack(spacing: 10) {
                ThemedTextField(title: "添加打卡項目", text: $newTitle)
                Picker("分類", selection: $newCategory) {
                    ForEach(categories, id: \.self) { Text($0).tag($0) }
                }
                Button("添加") {
                    store.addCustomChecklistItem(title: newTitle, category: newCategory)
                    newTitle = ""
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            }

            VStack(spacing: 10) {
                ForEach(store.state.checklistItems) { item in
                    HStack {
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(item.category)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                        Button {
                            store.deleteChecklistItem(item)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(10)
                    .background(AppTheme.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

private struct AddTransactionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var type: TransactionType = .expense
    @State private var amountText = ""
    @State private var category = "餐飲"
    @State private var account = "現金"
    @State private var note = ""

    private let categories = ["餐飲", "交通", "購物", "娛樂", "醫療", "固定支出", "其他"]
    private let accounts = ["現金", "銀行卡"]

    var body: some View {
        FormSheet(title: "記帳") {
            Picker("類型", selection: $type) {
                Text("支出").tag(TransactionType.expense)
                Text("收入").tag(TransactionType.income)
            }
            .pickerStyle(.segmented)

            ThemedTextField(title: "金額", text: $amountText)
                .keyboardType(.decimalPad)

            Picker("分類", selection: $category) {
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }

            Picker("帳戶", selection: $account) {
                ForEach(accounts, id: \.self) { Text($0).tag($0) }
            }

            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                guard let amount = Double(amountText) else { return }
                store.addTransaction(type: type, amount: amount, category: category, account: account, note: note)
                dismiss()
            }
        }
    }
}

private struct SetBudgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var category = "餐飲"
    @State private var amountText = ""

    private let categories = ["餐飲", "交通", "購物", "娛樂", "醫療", "固定支出", "其他"]

    var body: some View {
        FormSheet(title: "設定預算") {
            Picker("分類", selection: $category) {
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }

            ThemedTextField(title: "預算金額", text: $amountText)
                .keyboardType(.decimalPad)

            PrimaryButton(title: "保存") {
                guard let amount = Double(amountText) else { return }
                store.setBudget(category: category, amount: amount)
                dismiss()
            }
        }
    }
}

private struct AddWishSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var name = ""
    @State private var targetAmountText = ""

    var body: some View {
        FormSheet(title: "添加心願") {
            ThemedTextField(title: "心願名稱", text: $name)
            ThemedTextField(title: "目標金額", text: $targetAmountText)
                .keyboardType(.decimalPad)

            PrimaryButton(title: "保存") {
                store.addWish(name: name, targetAmount: Double(targetAmountText) ?? 0)
                dismiss()
            }
        }
    }
}

private struct AddShoppingItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var name = ""
    @State private var priceText = ""

    var body: some View {
        FormSheet(title: "添加購物項") {
            ThemedTextField(title: "商品名稱", text: $name)
            ThemedTextField(title: "預估價格", text: $priceText)
                .keyboardType(.decimalPad)

            PrimaryButton(title: "保存") {
                store.addShoppingItem(name: name, estimatedPrice: Double(priceText) ?? 0)
                dismiss()
            }
        }
    }
}

private struct AddCourseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var platform = ""
    @State private var url = ""

    var body: some View {
        FormSheet(title: "添加課程") {
            ThemedTextField(title: "課程名稱", text: $title)
            ThemedTextField(title: "平台", text: $platform)
            ThemedTextField(title: "連結URL (選填)", text: $url)

            PrimaryButton(title: "保存") {
                store.addCourse(title: title, platform: platform, url: url)
                dismiss()
            }
        }
    }
}

private struct AddKnowledgeNoteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var content = ""
    @State private var tagsText = ""

    var body: some View {
        FormSheet(title: "新建筆記") {
            ThemedTextField(title: "標題", text: $title)
            ThemedTextField(title: "重點摘錄…", text: $content)
            ThemedTextField(title: "標籤（逗號分隔）", text: $tagsText)

            PrimaryButton(title: "保存") {
                let tags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                store.addKnowledgeNote(title: title, content: content, tags: tags)
                dismiss()
            }
        }
    }
}

private struct AddVideoLearningSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var contentType = "影片"
    @State private var platform = ""
    @State private var url = ""

    var body: some View {
        FormSheet(title: "添加影音") {
            ThemedTextField(title: "標題", text: $title)
            Picker("類型", selection: $contentType) {
                Text("影片").tag("影片")
                Text("Podcast").tag("Podcast")
            }
            .pickerStyle(.segmented)
            ThemedTextField(title: "平台", text: $platform)
            ThemedTextField(title: "連結URL (選填)", text: $url)

            PrimaryButton(title: "保存") {
                store.addVideoLearningRecord(title: title, contentType: contentType, platform: platform, url: url)
                dismiss()
            }
        }
    }
}

private struct AddSymptomSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var symptom = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增症狀記錄") {
            ThemedTextField(title: "症狀", text: $symptom)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addSymptomRecord(symptom: symptom, note: note)
                dismiss()
            }
        }
    }
}

private struct AddMenstrualRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增經期記錄") {
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addMenstrualRecord(note: note)
                dismiss()
            }
        }
    }
}

private struct AddNourishmentRecipeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var url = ""

    var body: some View {
        FormSheet(title: "添加滋補食譜") {
            ThemedTextField(title: "食譜名稱", text: $title)
            ThemedTextField(title: "連結（選填）", text: $url)

            PrimaryButton(title: "保存") {
                store.addNourishmentRecipe(title: title, url: url)
                dismiss()
            }
        }
    }
}

private struct AddFaceLiftActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var name = ""

    var body: some View {
        FormSheet(title: "新增動作") {
            ThemedTextField(title: "動作名稱", text: $name)

            PrimaryButton(title: "保存") {
                store.addFaceLiftAction(name: name)
                dismiss()
            }
        }
    }
}

private struct AddFaceLiftRatingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var score: Double = 7
    @State private var note = ""

    var body: some View {
        FormSheet(title: "緊緻度評分") {
            VStack(alignment: .leading, spacing: 8) {
                Text("評分：\(Int(score)) 分")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.text)
                Slider(value: $score, in: 1...10, step: 1)
                    .tint(AppTheme.primary)
            }

            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addFaceLiftRating(score: Int(score), note: note)
                dismiss()
            }
        }
    }
}

private struct AddHairCareSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var careType = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增護髮紀錄") {
            ThemedTextField(title: "保養類型（洗髮、護髮療程…）", text: $careType)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addHairCareRecord(careType: careType, note: note)
                dismiss()
            }
        }
    }
}

private struct AddBodySkinRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var area = ""
    @State private var concern = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "新增身體保養紀錄") {
            ThemedTextField(title: "部位", text: $area)
            ThemedTextField(title: "膚況問題", text: $concern)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addBodySkinRecord(area: area, concern: concern, note: note)
                dismiss()
            }
        }
    }
}

private struct AddPunchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var summary = ""

    var body: some View {
        FormSheet(title: "新增打卡") {
            ThemedTextField(title: "今日心得", text: $summary)

            PrimaryButton(title: "保存") {
                store.addPunchRecord(summary: summary)
                dismiss()
            }
        }
    }
}

/// 區域目標 + 記錄彙整建議卡：輸入預期目標，依累積記錄生成後續建議
struct GoalAdviceCard: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    let area: String
    let topic: AIAdviceTopic
    @State private var goalText = ""
    @State private var goalSaved = false

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text("\(area)目標與建議")
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                HStack(spacing: 10) {
                    ThemedTextField(title: "輸入預期目標（例：三個月瘦 3kg）", text: $goalText)
                    Button(goalSaved ? "已保存" : "保存") {
                        store.setAreaGoal(area, goal: goalText)
                        goalSaved = true
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("記錄彙整")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.subtext)
                    ForEach(store.areaRecordsDigest(area), id: \.self) { line in
                        Text("・\(line)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.text)
                    }
                }

                Button {
                    let goal = store.areaGoal(area)
                    let concerns = (goal.isEmpty ? [] : ["我的目標：\(goal)"]) + store.areaRecordsDigest(area)
                    Task {
                        await store.requestAIAdvice(topic: topic, concerns: concerns)
                    }
                } label: {
                    HStack {
                        if store.isLoadingAdvice(for: topic) {
                            ProgressView().tint(.white)
                        }
                        Text("依記錄生成後續建議")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppTheme.primary)
                    .foregroundStyle(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(store.isLoadingAdvice(for: topic))

                if let error = store.errorMessage(for: topic) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                let suggestions = store.suggestions(for: topic)
                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("後續建議")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.subtext)
                        ForEach(suggestions, id: \.self) { suggestion in
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
            }
        }
        .onAppear {
            if goalText.isEmpty {
                goalText = store.areaGoal(area)
            }
        }
        .onChange(of: goalText) { _ in
            goalSaved = false
        }
    }
}

/// 通用編輯 sheet：單行文字 + 日期（心得、備註類記錄）
struct TextDateEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let fieldLabel: String
    @State var text: String
    @State var date: Date
    let onSave: (String, Date) -> Void

    var body: some View {
        FormSheet(title: title) {
            ThemedTextField(title: fieldLabel, text: $text)
            DatePicker("日期", selection: $date, displayedComponents: .date)
                .font(.subheadline)

            PrimaryButton(title: "保存修改") {
                onSave(text.trimmingCharacters(in: .whitespacesAndNewlines), date)
                dismiss()
            }
        }
    }
}

/// 通用編輯 sheet：標題 + 連結（教學連結、食譜、髮型靈感等）
struct TitleURLEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State var itemTitle: String
    @State var url: String
    let onSave: (String, String) -> Void

    var body: some View {
        FormSheet(title: title) {
            ThemedTextField(title: "標題", text: $itemTitle)
            ThemedTextField(title: "連結URL", text: $url)

            PrimaryButton(title: "保存修改") {
                onSave(
                    itemTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                    url.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                dismiss()
            }
        }
    }
}

/// 通用編輯 sheet：類型（可選項）+ 備註（膚況、症狀、心情等記錄）
struct TypeNoteEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let typeLabel: String
    let typeOptions: [String]
    @State var typeValue: String
    @State var note: String
    let onSave: (String, String) -> Void

    var body: some View {
        FormSheet(title: title) {
            if typeOptions.isEmpty {
                ThemedTextField(title: typeLabel, text: $typeValue)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(typeLabel)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(typeOptions, id: \.self) { option in
                                chip(option, selected: option == typeValue) {
                                    typeValue = option
                                }
                            }
                        }
                    }
                }
            }
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存修改") {
                onSave(typeValue, note.trimmingCharacters(in: .whitespacesAndNewlines))
                dismiss()
            }
        }
    }
}

/// 萬用多欄位編輯 sheet：以文字欄位陣列驅動，可選日期欄
struct FieldsEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let fieldLabels: [String]
    @State var values: [String]
    var showsDate: Bool = false
    @State var date: Date = .now
    let onSave: ([String], Date) -> Void

    var body: some View {
        FormSheet(title: title) {
            ForEach(Array(fieldLabels.enumerated()), id: \.offset) { index, label in
                ThemedTextField(title: label, text: Binding(
                    get: { index < values.count ? values[index] : "" },
                    set: { newValue in
                        if index < values.count { values[index] = newValue }
                    }
                ))
            }
            if showsDate {
                DatePicker("日期", selection: $date, displayedComponents: .date)
                    .font(.subheadline)
            }

            PrimaryButton(title: "保存修改") {
                onSave(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }, date)
                dismiss()
            }
        }
    }
}

/// 通用列操作選單：附加「編輯 / 刪除」到記錄列（長按顯示）
struct RecordRowActions: ViewModifier {
    let onEdit: (() -> Void)?
    let onDelete: () -> Void

    func body(content: Content) -> some View {
        content.contextMenu {
            if let onEdit {
                Button {
                    onEdit()
                } label: {
                    Label("編輯", systemImage: "pencil")
                }
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("刪除", systemImage: "trash")
            }
        }
    }
}

extension View {
    func recordActions(onEdit: (() -> Void)? = nil, onDelete: @escaping () -> Void) -> some View {
        modifier(RecordRowActions(onEdit: onEdit, onDelete: onDelete))
    }
}

private struct EditPunchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var summary: String
    @State private var date: Date
    private let record: PunchRecord

    init(record: PunchRecord) {
        self.record = record
        _summary = State(initialValue: record.summary)
        _date = State(initialValue: record.date)
    }

    var body: some View {
        FormSheet(title: "編輯打卡") {
            ThemedTextField(title: "心得", text: $summary)
            DatePicker("日期", selection: $date, displayedComponents: .date)
                .font(.subheadline)

            PrimaryButton(title: "保存修改") {
                var updated = record
                updated.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                updated.date = date
                store.replaceRecord(updated, in: \.punchRecords)
                dismiss()
            }
        }
    }
}

private struct AddAppointmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var storeName = ""
    @State private var date = Date()
    @State private var note = ""

    /// nil defaults to 美容預約's own list; 護髮療程預約 passes its own
    /// store method so the same form can target a different list.
    var onSave: ((String, String, Date, String) -> Void)?
    var sheetTitle: String = "新增預約"

    var body: some View {
        FormSheet(title: sheetTitle) {
            ThemedTextField(title: "服務名稱", text: $title)
            ThemedTextField(title: "店家名稱", text: $storeName)
            DatePicker("預約時間", selection: $date)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                if let onSave {
                    onSave(title, storeName, date, note)
                } else {
                    store.addAppointment(title: title, storeName: storeName, date: date, note: note)
                }
                dismiss()
            }
        }
    }
}

private struct AddBodyMetricSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var weight = ""
    @State private var bodyFat = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "體重體脂記錄") {
            ThemedTextField(title: "體重 (kg)", text: $weight)
            ThemedTextField(title: "體脂 (%)", text: $bodyFat)
            ThemedTextField(title: "備註", text: $note)

            PrimaryButton(title: "保存") {
                store.addBodyMetric(weight: Double(weight) ?? 0, bodyFat: Double(bodyFat) ?? 0, note: note)
                dismiss()
            }
        }
    }
}

private struct TDEESetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var heightText = ""
    @State private var ageText = ""
    @State private var activityLevel = "輕度活動"
    @State private var goal = "維持體重"

    var body: some View {
        FormSheet(title: "每日熱量目標") {
            Text("依身高、年齡、活動量與目標，用最近一筆體重紀錄自動計算每日建議攝取熱量。")
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)

            ThemedTextField(title: "身高（公分）", text: $heightText)
            ThemedTextField(title: "年齡", text: $ageText)

            VStack(alignment: .leading, spacing: 6) {
                Text("活動量")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TDEEProfile.activityLevels, id: \.name) { level in
                            chip(level.name, selected: level.name == activityLevel) {
                                activityLevel = level.name
                            }
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("目標")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                HStack(spacing: 8) {
                    ForEach(TDEEProfile.goals, id: \.name) { item in
                        chip(item.name, selected: item.name == goal) {
                            goal = item.name
                        }
                    }
                }
            }

            if store.state.bodyMetricRecords.isEmpty {
                Text("尚無體重紀錄——請先到「體重體脂」新增一筆，目標才能計算。")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            PrimaryButton(title: "保存目標") {
                var profile = store.state.tdeeProfile
                profile.heightCM = Double(heightText) ?? profile.heightCM
                profile.age = Int(ageText) ?? profile.age
                profile.activityLevel = activityLevel
                profile.goal = goal
                store.updateTDEEProfile(profile)
                dismiss()
            }
        }
        .onAppear {
            let profile = store.state.tdeeProfile
            if profile.heightCM > 0 { heightText = String(Int(profile.heightCM)) }
            if profile.age > 0 { ageText = String(profile.age) }
            activityLevel = profile.activityLevel
            goal = profile.goal
        }
    }
}

private struct AddMealSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var type = "早餐"
    @State private var summary = ""
    @State private var note = ""
    @State private var caloriesText = ""
    @State private var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var validationMessage: String?

    private let mealTypes = ["早餐", "午餐", "晚餐", "點心", "飲料"]

    var body: some View {
        FormSheet(title: "飲食記錄") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(mealTypes, id: \.self) { meal in
                        chip(meal, selected: meal == type) { type = meal }
                    }
                }
            }

            ThemedTextField(title: "餐點內容（例：雞腿便當+無糖豆漿）", text: $summary)
            ThemedTextField(title: "備註", text: $note)

            HStack(spacing: 10) {
                ThemedTextField(title: "熱量（大卡，可留空自動估算）", text: $caloriesText)
                Button("估算") {
                    Task { await runAIAnalysis() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
                .disabled(store.isAnalyzingFood)
            }

            HStack(spacing: 10) {
                Button {
                    showCamera = true
                } label: {
                    Label("拍食物照", systemImage: "camera.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.primarySoft)
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                PhotosPicker(selection: $photoItem, matching: .images) {
                    Label("相簿選照", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.primarySoft)
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if store.isAnalyzingFood {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("AI 正在辨識餐點與估算熱量…")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }
            } else if let error = store.foodAnalysisError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            PrimaryButton(title: "保存") {
                let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    validationMessage = "請輸入餐點內容，或先用拍照/選照讓 AI 辨識。"
                    return
                }
                store.addMealRecord(
                    type: type,
                    summary: summary,
                    note: note,
                    calories: Int(caloriesText),
                    photoData: photoData
                )
                dismiss()
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                if let data = image?.jpegData(compressionQuality: 0.6) {
                    photoData = data
                    Task { await runAIAnalysis() }
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    photoData = image.jpegData(compressionQuality: 0.6)
                    await runAIAnalysis()
                }
                photoItem = nil
            }
        }
    }

    private func runAIAnalysis() async {
        validationMessage = nil
        let textHint = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard photoData != nil || !textHint.isEmpty else {
            validationMessage = "請先輸入餐點內容或提供照片，AI 才能估算。"
            return
        }
        guard let result = await store.analyzeFood(text: textHint.isEmpty ? nil : textHint, imageData: photoData) else {
            // AI 失敗時退回本地關鍵字估算，至少熱量欄不會空著
            if let estimated = CalorieEstimator.estimate(from: summary) {
                caloriesText = String(estimated)
            }
            return
        }
        if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            summary = result.foodName
        }
        caloriesText = String(result.estimatedCalories)
        if !result.notes.isEmpty, note.isEmpty {
            note = result.notes
        }
    }
}

private struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var title = ""
    @State private var author = ""
    @State private var link = ""
    @State private var note = ""

    var body: some View {
        FormSheet(title: "添加書籍") {
            ThemedTextField(title: "書名", text: $title)
            ThemedTextField(title: "作者", text: $author)
            ThemedTextField(title: "外部連結", text: $link)
            ThemedTextField(title: "筆記", text: $note)

            PrimaryButton(title: "保存") {
                store.addBook(title: title, author: author, link: link, note: note)
                dismiss()
            }
        }
    }
}

private struct ImportWizardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var url = ""
    @State private var isLoading = false
    @State private var draft = ResourceImportDraft.empty(url: "")
    @State private var parseMessage = ""
    @State private var currentStep: ImportWizardStep = .input

    private enum ImportWizardStep {
        case input
        case preview
        case manual
    }

    var body: some View {
        FormSheet(title: "匯入精靈") {
            if currentStep == .input {
                VStack(alignment: .leading, spacing: 12) {
                    Text("貼上來源連結後，系統會先嘗試抓取標題、作者、縮圖、時間與內容型別。")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.subtext)

                    ThemedTextField(title: "來源連結", text: $url)

                    if !parseMessage.isEmpty {
                        InfoCallout(title: "解析提醒", detail: parseMessage)
                    }

                    PrimaryButton(title: isLoading ? "解析中..." : "開始解析") {
                        guard !isLoading else { return }
                        Task {
                            await parseURL()
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("支援來源")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)

                            ForEach(ImportSourceType.allCases) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.systemImage)
                                        .foregroundStyle(AppTheme.primary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.rawValue)
                                            .foregroundStyle(AppTheme.text)
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            } else if currentStep == .preview {
                ImportPreviewView(draft: draft) {
                    store.saveImportedResource(draft)
                    dismiss()
                } manualAction: {
                    currentStep = .manual
                }
            } else {
                ManualCompleteView(draft: $draft) {
                    store.updateImportDraft(draft)
                    store.saveImportedResource(draft)
                    dismiss()
                }
            }
        }
        .onAppear {
            if let pending = store.state.pendingImportDraft {
                draft = pending
                url = pending.originalURL
                currentStep = pending.requiresManualCompletion ? .manual : .preview
            }
        }
    }

    private func parseURL() async {
        isLoading = true
        let parsed = await store.importResource(from: url)
        draft = parsed
        parseMessage = parsed.lastErrorMessage ?? ""
        currentStep = .preview
        isLoading = false
    }
}

private struct ImportPreviewView: View {
    let draft: ResourceImportDraft
    let saveAction: () -> Void
    let manualAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("匯入預覽")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        StatusBadge(status: draft.importStatus)
                    }

                    MetadataHero(draft: draft)

                    if !draft.missingFields.isEmpty {
                        InfoCallout(title: "待補欄位", detail: draft.missingFields.joined(separator: "、"))
                    }

                    if let lastErrorMessage = draft.lastErrorMessage, !lastErrorMessage.isEmpty {
                        InfoCallout(title: "解析提醒", detail: lastErrorMessage)
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("來源資訊")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    MetadataRow(title: "平台", value: draft.source.rawValue)
                    MetadataRow(title: "內容型別", value: draft.platformContentType.rawValue)
                    MetadataRow(title: "分類建議", value: draft.category == .all ? "待確認" : draft.category.rawValue)
                    MetadataRow(title: "作者", value: draft.authorName.isEmpty ? "待補齊" : draft.authorName)
                    MetadataRow(title: "時間", value: draft.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "未解析")
                    MetadataRow(title: "信心分數", value: "\(Int(draft.metadataConfidence * 100))%")
                }
            }

            if !draft.mediaAssets.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("媒體資產")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            MediaRetentionBadge(policy: draft.mediaRetentionPolicy)
                        }
                        Text("已識別 \(draft.mediaAssets.count) 筆媒體，預設只保存 metadata。")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                        MediaAssetListView(assets: draft.mediaAssets)
                    }
                }
            }

            if let payload = draft.sourcePayloadSummary, !payload.commentsPreview.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("評論預覽")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        ForEach(payload.commentsPreview, id: \.self) { comment in
                            Text(comment)
                                .font(.caption)
                                .foregroundStyle(AppTheme.subtext)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }

            PrimaryButton(title: "保存到資源庫") {
                saveAction()
            }

            if draft.requiresManualCompletion {
                PrimaryButton(title: "手動補齊後再保存") {
                    manualAction()
                }
            }
        }
    }
}

private struct ManualCompleteView: View {
    @Binding var draft: ResourceImportDraft
    let saveAction: () -> Void
    @State private var tagsText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("手動補齊")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    Picker("來源平台", selection: $draft.source) {
                        ForEach(ImportSourceType.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    Picker("分類", selection: $draft.category) {
                        ForEach(ResourceCategory.allCases.filter { $0 != .all }) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    Picker("內容型別", selection: $draft.platformContentType) {
                        ForEach(ImportedContentType.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    Picker("媒體保存策略", selection: $draft.mediaRetentionPolicy) {
                        ForEach(MediaRetentionPolicy.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }

                    ThemedTextField(title: "標題", text: $draft.title)
                    ThemedTextField(title: "作者", text: $draft.authorName)
                    ThemedTextField(title: "縮圖 URL", text: $draft.thumbnailURL)
                    ThemedTextField(title: "描述", text: $draft.descriptionText)
                    ThemedTextField(title: "標籤（以逗號分隔）", text: $tagsText)
                }
            }

            if !draft.mediaAssets.isEmpty {
                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("媒體選擇")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        MediaAssetSelectionList(assets: $draft.mediaAssets)
                    }
                }
            }

            if !draft.resolvedURL.isEmpty {
                CardView {
                    MetadataRow(title: "來源連結", value: draft.resolvedURL)
                }
            }

            PrimaryButton(title: "完成並保存") {
                draft.tags = tagsText
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                draft.importStatus = draft.metadataConfidence < 0.2 ? .failedFallbackSaved : .manualCompleted
                saveAction()
            }
        }
        .onAppear {
            tagsText = draft.tags.joined(separator: ", ")
        }
    }
}

private struct ResourceListCard: View {
    let item: ResourceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                    Text("\(item.source.rawValue) · \(item.platformContentType.rawValue) · \(item.category.rawValue)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }
                Spacer()
                StatusBadge(status: item.importStatus)
            }

            Text(item.displaySummary)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
                .lineLimit(2)

            HStack {
                MediaRetentionBadge(policy: item.mediaRetentionPolicy)
                if !item.selectedMediaAssets.isEmpty {
                    Text("媒體 \(item.selectedMediaAssets.count) 筆")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.subtext)
                }
                Spacer()
                if !item.temporaryMediaLeases.isEmpty {
                    Text("暫存 \(item.temporaryMediaLeases.count)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            if !item.authorName.isEmpty || !item.tags.isEmpty {
                HStack {
                    if !item.authorName.isEmpty {
                        Text("作者：\(item.authorName)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    Spacer()
                    if !item.tags.isEmpty {
                        Text(item.tags.prefix(2).joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// 解析描述欄位裡「📋 教學步驟：\n1. xxx\n2. xxx」這段條列文字，
/// 讓詳情頁能把每一步跟對應的畫面截圖（若有）配對顯示。
enum TeachingStepParser {
    static let marker = "📋 教學步驟"

    static func parse(_ description: String) -> [(index: Int, text: String)] {
        guard let range = description.range(of: marker) else { return [] }
        let after = description[range.upperBound...]
        var results: [(Int, String)] = []
        for line in after.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let dotIndex = trimmed.firstIndex(where: { $0 == "." || $0 == "、" }) else { continue }
            let numberPart = trimmed[trimmed.startIndex..<dotIndex]
            guard let number = Int(numberPart) else { continue }
            let text = trimmed[trimmed.index(after: dotIndex)...].trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { continue }
            results.append((number, text))
        }
        return results
    }

    static func stripSteps(from description: String) -> String {
        guard let range = description.range(of: marker) else { return description }
        return String(description[description.startIndex..<range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ResourceDetailView: View {
    let item: ResourceItem

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "資源詳情") {}

                let stepShots = Dictionary(uniqueKeysWithValues: item.mediaAssets
                    .filter { $0.assetID.hasPrefix("step-") && !$0.displayURL.isEmpty }
                    .map { ($0.index, $0.displayURL) })
                let parsedSteps = TeachingStepParser.parse(item.descriptionText)

                let carouselAssets = item.mediaAssets
                    .filter { ($0.type == .image || $0.type == .cover) && !$0.assetID.hasPrefix("step-") && !$0.displayURL.isEmpty }
                    .sorted { $0.index < $1.index }
                if !carouselAssets.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("圖片（\(carouselAssets.count) 張，左右滑動）")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            TabView {
                                ForEach(carouselAssets) { asset in
                                    AsyncImage(url: URL(string: asset.displayURL)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .scaledToFit()
                                        case .failure:
                                            VStack(spacing: 6) {
                                                Image(systemName: "photo")
                                                    .font(.title)
                                                Text("圖片載入失敗")
                                                    .font(.caption)
                                            }
                                            .foregroundStyle(AppTheme.subtext)
                                        default:
                                            ProgressView()
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .tabViewStyle(.page(indexDisplayMode: .always))
                            .indexViewStyle(.page(backgroundDisplayMode: .always))
                            .frame(height: 360)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                }

                if !parsedSteps.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("📋 教學步驟")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)

                            ForEach(parsedSteps, id: \.index) { step in
                                HStack(alignment: .top, spacing: 12) {
                                    if let shotURL = stepShots[step.index] {
                                        AsyncImage(url: URL(string: shotURL)) { phase in
                                            if case .success(let image) = phase {
                                                image.resizable().scaledToFill()
                                            } else {
                                                AppTheme.primarySoft
                                            }
                                        }
                                        .frame(width: 72, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    Text("\(step.index). \(step.text)")
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(10)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 12) {
                        MetadataHero(item: item)
                        let descriptionWithoutSteps = TeachingStepParser.stripSteps(from: item.descriptionText)
                        if !descriptionWithoutSteps.isEmpty {
                            Text(descriptionWithoutSteps)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // 小紅書在台灣被網路封鎖，開原文只會看到錯誤頁，故不提供按鈕
                        if item.source != .xiaohongshu,
                           let originalLink = URL(string: item.originalURL.isEmpty ? item.canonicalURL : item.originalURL) {
                            Link(destination: originalLink) {
                                HStack(spacing: 6) {
                                    Image(systemName: "safari")
                                    Text("查看原文")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("詳細欄位")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        MetadataRow(title: "平台", value: item.source.rawValue)
                        MetadataRow(title: "內容型別", value: item.platformContentType.rawValue)
                        MetadataRow(title: "解析狀態", value: item.importStatus.rawValue)
                        MetadataRow(title: "分類", value: item.category.rawValue)
                        MetadataRow(title: "作者", value: item.authorName.isEmpty ? "未提供" : item.authorName)
                        MetadataRow(title: "發佈時間", value: item.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "未解析")
                        MetadataRow(title: "原始連結", value: item.originalURL)
                        MetadataRow(title: "標準連結", value: item.canonicalURL.isEmpty ? "未提供" : item.canonicalURL)
                        MetadataRow(title: "外部 ID", value: item.externalID.isEmpty ? "未提供" : item.externalID)
                        MetadataRow(title: "媒體策略", value: item.mediaRetentionPolicy.rawValue)
                        MetadataRow(title: "媒體數量", value: "\(item.selectedMediaAssets.count)")
                        MetadataRow(title: "匯入時間", value: item.importedAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }

                if !item.selectedMediaAssets.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("媒體清單")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            MediaAssetListView(assets: item.selectedMediaAssets)
                        }
                    }
                }

                if !item.temporaryMediaLeases.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("暫存清理狀態")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            ForEach(item.temporaryMediaLeases) { lease in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(lease.storagePath)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.text)
                                            .lineLimit(1)
                                        Text("到期：\(lease.expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    Spacer()
                                    Text(lease.cleanupStatus.rawValue)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)
                                }
                                .padding(10)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }
}

private struct FormSheet<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    content
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct HubCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        CardView {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.primarySoft)
                    .frame(width: 48, height: 48)
                    .overlay(Image(systemName: icon).foregroundStyle(AppTheme.primary))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.subtext)
            }
        }
    }
}

/// Reusable "type your concern -> get AI suggestions" card, shared by every
/// screen with this pattern (護膚/頭髮/面部拉提/身體皮膚/飲食/妝容) so each
/// one doesn't duplicate the chip-selector + custom-input + button + result
/// list wiring.
struct AIAdviceSection: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    let topic: AIAdviceTopic
    let title: String
    let subtitle: String
    let commonConcerns: [String]
    let buttonTitle: String
    /// 靜默併入 AI 請求的背景資訊（例如症狀歷史、目標），不會顯示成使用者的問題 chip
    var additionalContext: [String] = []
    var onAddRoutineStep: ((String) -> Void)? = nil
    var onAddProduct: ((String) -> Void)? = nil
    var onAddExercise: ((AIAdviceRelatedResource) -> Void)? = nil
    var onAddRecipe: ((String) -> Void)? = nil

    @State private var selectedConcerns: Set<String> = []
    @State private var customConcern = ""
    @State private var selectedCustomConcerns: Set<String> = []
    @State private var addedRoutineSteps: Set<String> = []
    @State private var addedProducts: Set<String> = []
    @State private var addedRecipeSuggestions: Set<String> = []
    @State private var addedExerciseResourceIDs: Set<String> = []
    @State private var viewingTutorial: ResourceItem?
    @State private var tutorialMissingMessage: String?

    private var allConcerns: [String] {
        Array(selectedConcerns) + Array(selectedCustomConcerns) + additionalContext
    }

    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)

                if !commonConcerns.isEmpty {
                    WrapToggleChips(items: commonConcerns, selection: $selectedConcerns)
                }

                HStack(spacing: 10) {
                    ThemedTextField(title: "自訂問題…", text: $customConcern)
                    Button("加入") {
                        let trimmed = customConcern.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        store.addCustomConcern(trimmed, for: topic)
                        selectedCustomConcerns.insert(trimmed)
                        customConcern = ""
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.primary)
                }

                let savedCustomConcerns = store.customConcerns(for: topic)
                if !savedCustomConcerns.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("我的常用問題（點選使用，長按刪除）")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                        WrapToggleChips(items: savedCustomConcerns, selection: $selectedCustomConcerns)
                            .contextMenu {
                                ForEach(savedCustomConcerns, id: \.self) { concern in
                                    Button(role: .destructive) {
                                        store.removeCustomConcern(concern, for: topic)
                                        selectedCustomConcerns.remove(concern)
                                    } label: {
                                        Label("刪除「\(concern)」", systemImage: "trash")
                                    }
                                }
                            }
                    }
                }

                PrimaryButton(title: store.isLoadingAdvice(for: topic) ? "正在取得建議…" : buttonTitle) {
                    Task { await store.requestAIAdvice(topic: topic, concerns: allConcerns) }
                }
                .disabled(store.isLoadingAdvice(for: topic))

                if let errorMessage = store.errorMessage(for: topic) {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if !store.suggestions(for: topic).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(store.suggestions(for: topic), id: \.self) { suggestion in
                            if let onAddRecipe {
                                recommendationRow(
                                    text: suggestion,
                                    added: addedRecipeSuggestions.contains(suggestion),
                                    actionTitle: "加入收藏食譜"
                                ) {
                                    onAddRecipe(suggestion)
                                    addedRecipeSuggestions.insert(suggestion)
                                }
                            } else {
                                Text("• \(suggestion)")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }

                if let onAddRoutineStep, !store.recommendedRoutineSteps(for: topic).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("建議加入護膚流程")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)

                        ForEach(store.recommendedRoutineSteps(for: topic), id: \.self) { step in
                            recommendationRow(
                                text: step,
                                added: addedRoutineSteps.contains(step),
                                actionTitle: "加入護膚流程"
                            ) {
                                onAddRoutineStep(step)
                                addedRoutineSteps.insert(step)
                            }
                        }
                    }
                }

                if let onAddProduct, !store.recommendedProducts(for: topic).isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("建議加入保養品清單")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)

                        ForEach(store.recommendedProducts(for: topic), id: \.self) { product in
                            recommendationRow(
                                text: product,
                                added: addedProducts.contains(product),
                                actionTitle: "加入保養品"
                            ) {
                                onAddProduct(product)
                                addedProducts.insert(product)
                            }
                        }
                    }
                }

                let related = store.relatedResources(for: topic)
                if !related.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("資料庫相關教學")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.text)

                        ForEach(related) { resource in
                            HStack(spacing: 10) {
                                AsyncImage(url: URL(string: resource.thumbnailURL)) { phase in
                                    if case .success(let image) = phase {
                                        image.resizable().scaledToFill()
                                    } else {
                                        AppTheme.primarySoft
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(resource.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                        .lineLimit(2)
                                    if !resource.author.isEmpty {
                                        Text(resource.author)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    HStack(spacing: 12) {
                                        Button("查看教學") {
                                            if let item = store.resourceItem(remoteID: resource.id) {
                                                viewingTutorial = item
                                            } else {
                                                tutorialMissingMessage = "教學內容還沒同步到本機，請先登入並到「資源庫」下拉更新後再試。"
                                            }
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)

                                        if let onAddExercise {
                                            Button(addedExerciseResourceIDs.contains(resource.id) ? "已加入" : "加入運動管理") {
                                                onAddExercise(resource)
                                                addedExerciseResourceIDs.insert(resource.id)
                                            }
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(addedExerciseResourceIDs.contains(resource.id) ? AppTheme.subtext : AppTheme.primary)
                                            .disabled(addedExerciseResourceIDs.contains(resource.id))
                                        }
                                    }
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        if let tutorialMissingMessage {
                            Text(tutorialMissingMessage)
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .sheet(item: $viewingTutorial) { item in
            NavigationStack {
                ResourceDetailView(item: item)
                    .background(AppTheme.background)
            }
        }
    }

    private func recommendationRow(text: String, added: Bool, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("• \(text)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(added ? "已加入" : actionTitle, action: action)
                .font(.caption.weight(.semibold))
                .foregroundStyle(added ? AppTheme.subtext : AppTheme.primary)
                .disabled(added)
        }
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: AppTheme.shadow, radius: 16, y: 8)
    }
}

private struct StatusBadge: View {
    let status: ResourceImportStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .parsed:
            return AppTheme.primary
        case .partial:
            return .orange
        case .manualCompleted:
            return .blue
        case .failedFallbackSaved:
            return .pink
        }
    }
}

private struct RuntimeStatusChip: View {
    let title: String
    let active: Bool
    let activeDetail: String
    let inactiveDetail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(active ? AppTheme.success : AppTheme.subtext)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
            }

            Text(active ? activeDetail : inactiveDetail)
                .font(.caption2)
                .foregroundStyle(AppTheme.subtext)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MetadataRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.subtext)
                .frame(width: 72, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct InfoCallout: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.primary)
            Text(detail)
                .font(.caption)
                .foregroundStyle(AppTheme.text)
                .accessibilityIdentifier("infoCallout.detail")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.primarySoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MediaRetentionBadge: View {
    let policy: MediaRetentionPolicy

    var body: some View {
        Text(policy.rawValue)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(policyColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(policyColor.opacity(0.12))
            .clipShape(Capsule())
    }

    private var policyColor: Color {
        switch policy {
        case .metadataOnly:
            return AppTheme.primary
        case .temporaryCache:
            return .orange
        case .explicitKeep:
            return .blue
        }
    }
}

private struct MediaAssetListView: View {
    let assets: [XHSMediaAsset]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(assets) { asset in
                HStack(spacing: 12) {
                    ThumbnailPreview(thumbnailURL: asset.displayURL, size: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assetTypeLabel(asset.type))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.text)
                        Text(asset.displayURL)
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                            .lineLimit(1)
                        if let expiresAt = asset.expiresAt {
                            Text("到期：\(expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    MediaRetentionBadge(policy: asset.retentionPolicy)
                }
            }
        }
    }

    private func assetTypeLabel(_ type: XHSMediaAssetType) -> String {
        switch type {
        case .image:
            return "圖片"
        case .video:
            return "影片"
        case .cover:
            return "封面"
        case .livePhoto:
            return "LivePhoto"
        case .unknown:
            return "未知"
        }
    }
}

private struct MediaAssetSelectionList: View {
    @Binding var assets: [XHSMediaAsset]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(assets.indices), id: \.self) { index in
                Button {
                    assets[index].isSelectedForImport.toggle()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: assets[index].isSelectedForImport ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(assets[index].isSelectedForImport ? AppTheme.primary : AppTheme.subtext)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(assets[index].type.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(assets[index].displayURL)
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtext)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("#\(max(assets[index].index, 0) + 1)")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    .padding(12)
                    .background(AppTheme.primarySoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MetadataHero: View {
    let title: String
    let subtitle: String
    let sourceLabel: String
    let thumbnailURL: String
    let mediaAssets: [XHSMediaAsset]

    init(draft: ResourceImportDraft) {
        self.title = draft.title.isEmpty ? "尚未解析出標題" : draft.title
        self.subtitle = draft.descriptionText.isEmpty ? draft.resolvedURL : draft.descriptionText
        self.sourceLabel = "\(draft.source.rawValue) · \(draft.platformContentType.rawValue)"
        self.thumbnailURL = draft.thumbnailURL
        self.mediaAssets = draft.selectedMediaAssets.isEmpty ? draft.mediaAssets : draft.selectedMediaAssets
    }

    init(item: ResourceItem) {
        self.title = item.title
        self.subtitle = item.displaySummary
        self.sourceLabel = "\(item.source.rawValue) · \(item.platformContentType.rawValue)"
        self.thumbnailURL = item.thumbnailURL
        self.mediaAssets = item.selectedMediaAssets
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ThumbnailPreview(thumbnailURL: mediaAssets.first?.displayURL ?? thumbnailURL)

            VStack(alignment: .leading, spacing: 6) {
                Text(sourceLabel)
                    .font(.caption)
                    .foregroundStyle(AppTheme.primary)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                    .accessibilityIdentifier("metadataHero.title")
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                    .lineLimit(4)
            }
        }
    }
}

private struct ThumbnailPreview: View {
    let thumbnailURL: String
    var size: CGFloat = 92

    var body: some View {
        Group {
            if let url = URL(string: thumbnailURL), !thumbnailURL.isEmpty {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.primarySoft)
                        .overlay(ProgressView().tint(AppTheme.primary))
                }
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppTheme.primarySoft)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundStyle(AppTheme.primary)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .foregroundStyle(AppTheme.subtext)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.subtext)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110)
    }
}

private struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
    }
}

private struct ThemedTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        TextField(title, text: $text)
            .padding(14)
            .background(AppTheme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier(title)
    }
}

private struct ThemedSecureField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        SecureField(title, text: $text)
            .padding(14)
            .background(AppTheme.primarySoft)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .accessibilityIdentifier(title)
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.subtext)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.text)
        }
        .font(.subheadline)
    }
}

private struct WrapChips: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.primarySoft)
                    .clipShape(Capsule())
            }
        }
    }
}

private struct WrapToggleChips: View {
    let items: [String]
    @Binding var selection: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                Button {
                    if selection.contains(item) {
                        selection.remove(item)
                    } else {
                        selection.insert(item)
                    }
                } label: {
                    Text(item)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selection.contains(item) ? AppTheme.primary : AppTheme.primarySoft)
                        .foregroundStyle(selection.contains(item) ? Color.white : AppTheme.text)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct WrapSelectableChips: View {
    let items: [ResourceCategory]
    let selected: ResourceCategory
    let action: (ResourceCategory) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 68), spacing: 10)], alignment: .leading, spacing: 10) {
            ForEach(items) { item in
                Button {
                    action(item)
                } label: {
                    Text(item.rawValue)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected == item ? AppTheme.primary : AppTheme.primarySoft)
                        .foregroundStyle(selected == item ? Color.white : AppTheme.text)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private func header(title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(title)
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(AppTheme.text)
        Text(subtitle)
            .font(.subheadline)
            .foregroundStyle(AppTheme.subtext)
    }
}

private func titleRow(title: String, action: String? = nil, onTap: @escaping () -> Void = {}) -> some View {
    HStack {
        Text(title)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(AppTheme.text)
        Spacer()
        if let action {
            Button(action) {
                onTap()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(AppTheme.primary)
            .clipShape(Capsule())
            .accessibilityIdentifier(action)
        }
    }
}

private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(selected ? AppTheme.primary : AppTheme.subtext)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(selected ? AppTheme.card : AppTheme.primarySoft)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? AppTheme.primary.opacity(0.18) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    .buttonStyle(.plain)
}

#Preview {
    NavigationStack {
        HomeView()
            .environmentObject(BeautyDiaryStore.preview)
    }
}
