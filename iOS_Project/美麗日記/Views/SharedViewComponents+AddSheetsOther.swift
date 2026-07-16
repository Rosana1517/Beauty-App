import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

struct CustomizeChecklistSheet: View {
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

struct AddTransactionSheet: View {
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

struct SetBudgetSheet: View {
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

struct AddWishSheet: View {
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

struct AddShoppingItemSheet: View {
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

struct AddCourseSheet: View {
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

struct AddKnowledgeNoteSheet: View {
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

struct AddVideoLearningSheet: View {
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

struct AddSymptomSheet: View {
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

struct AddMenstrualRecordSheet: View {
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

struct AddNourishmentRecipeSheet: View {
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

struct AddFaceLiftActionSheet: View {
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

struct AddFaceLiftRatingSheet: View {
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

struct AddHairCareSheet: View {
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

struct AddBodySkinRecordSheet: View {
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

struct AddPunchSheet: View {
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
