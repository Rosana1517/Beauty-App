import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

extension WellnessView {
    var nourishmentContent: some View {
        VStack(spacing: 18) {
            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("AI 內調養生方案")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text("基於你的健康狀況，生成個人化養生內調方案")
                        .font(.caption)
                        .foregroundStyle(AppTheme.subtext)

                    if store.state.symptomRecords.isEmpty {
                        Text("尚無症狀記錄，請先在「健康狀況」Tab中記錄")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    } else {
                        ThemedTextField(title: "想要改善的方向，如：調理體質、養顏美容…", text: $improvementDirection)

                        PrimaryButton(title: store.isLoadingAdvice(for: .nourishment) ? "正在生成…" : "生成養生內調方案") {
                            let symptoms = store.state.symptomRecords.map(\.symptom)
                            let concerns = improvementDirection.isEmpty ? symptoms : symptoms + [improvementDirection]
                            Task { await store.requestAIAdvice(topic: .nourishment, concerns: concerns) }
                        }
                        .disabled(store.isLoadingAdvice(for: .nourishment))

                        if let errorMessage = store.errorMessage(for: .nourishment) {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        ForEach(store.suggestions(for: .nourishment), id: \.self) { suggestion in
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

            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("茶飲配方庫")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    HStack(spacing: 10) {
                        ForEach(teaCategories, id: \.self) { category in
                            Button {
                                selectedTeaCategory = selectedTeaCategory == category ? nil : category
                            } label: {
                                Text(category)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selectedTeaCategory == category ? Color.white : AppTheme.text)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedTeaCategory == category ? AppTheme.primary : AppTheme.primarySoft)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    if let category = selectedTeaCategory, let recipes = teaRecipeLibrary[category] {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(recipes, id: \.self) { recipe in
                                Text("· \(recipe)")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                            }
                        }
                    }
                }
            }

            CardView {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("滋補食譜庫")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text("調理食譜收藏與管理")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    Spacer()
                    Button("添加") { showAddNourishmentRecipe = true }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }

            if !store.state.nourishmentRecipes.isEmpty {
                CardView {
                    VStack(spacing: 10) {
                        ForEach(store.state.nourishmentRecipes) { link in
                            HStack {
                                Text(link.title)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.text)
                                Spacer()
                            }
                            .padding(12)
                            .background(AppTheme.primarySoft)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .recordActions(onEdit: { editingNourishmentRecipe = link }, onDelete: {
                                store.deleteNourishmentRecipe(link)
                            })
                        }
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("經期記錄")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Button("+記錄") { showAddMenstrual = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    if store.state.menstrualRecords.isEmpty {
                        EmptyStateView(title: "暫無經期記錄", subtitle: "")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.state.menstrualRecords) { record in
                                HStack {
                                    Text(record.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                    Spacer()
                                    Text(record.note)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .recordActions(onEdit: { editingMenstrualRecord = record }, onDelete: {
                                    store.deleteMenstrualRecord(record)
                                })
                            }
                        }
                    }
                }
            }

            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("體質追蹤")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(constitutions, id: \.0) { constitution in
                            let selected = store.state.bodyConstitution == constitution.0
                            Button {
                                store.setBodyConstitution(constitution.0)
                            } label: {
                                VStack(spacing: 4) {
                                    Text(constitution.0)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(selected ? Color.white : AppTheme.text)
                                    Text(constitution.1)
                                        .font(.caption2)
                                        .foregroundStyle(selected ? Color.white.opacity(0.85) : AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(selected ? AppTheme.primary : AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }
        }
    }

    var statusContent: some View {
        VStack(spacing: 18) {
            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("症狀記錄")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Button("+記錄") { showAddSymptom = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.primary)
                    }

                    if store.state.symptomRecords.isEmpty {
                        EmptyStateView(title: "暫無症狀記錄", subtitle: "")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.state.symptomRecords) { record in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.symptom)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(AppTheme.text)
                                    Text(record.note.isEmpty ? record.date.formatted(date: .abbreviated, time: .omitted) : record.note)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .recordActions(onEdit: { editingSymptomRecord = record }, onDelete: {
                                    store.deleteSymptomRecord(record)
                                })
                            }
                        }
                    }
                }
            }

            AIAdviceSection(
                topic: .wellness,
                title: "AI 健康建議",
                subtitle: "基於當前症狀，輸入想要改善的方向，獲取個人化養生建議",
                commonConcerns: [],
                buttonTitle: "獲取 AI 養生建議",
                additionalContext: symptomHistoryContext,
                onAddRecipe: { text in
                    store.addNourishmentRecipe(title: text, url: "")
                }
            )

            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("症狀頻率統計")
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)

                    if store.symptomFrequency.isEmpty {
                        EmptyStateView(title: "暫無統計數據", subtitle: "")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(store.symptomFrequency, id: \.symptom) { entry in
                                HStack {
                                    Text(entry.symptom)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                    Spacer()
                                    Text("\(entry.count) 次")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                }
                                .padding(12)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }
        }
    }
}
