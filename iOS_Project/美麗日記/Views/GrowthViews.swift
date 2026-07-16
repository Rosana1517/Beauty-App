import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts


struct GrowthRootView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header(title: "成長", subtitle: "閱讀、輸入與每週整理放在同一個節奏裡")

                GoalAdviceCard(area: "成長", topic: .wellness)

                ForEach(GrowthRoute.allCases) { route in
                    NavigationLink(value: route) {
                        HubCard(title: route.rawValue, subtitle: growthSubtitle(for: route), icon: growthIcon(for: route))
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationDestination(for: GrowthRoute.self) { route in
            switch route {
            case .reading:
                ReadingTrackerView()
            case .courses:
                CourseTrackerView()
            case .notes:
                KnowledgeNotesView()
            case .videos:
                VideoLearningView()
            case .dailyQuote:
                DailyQuoteView()
            case .moodTracking:
                MoodTrackingView()
            case .finance:
                FinanceRootView()
            case .goals:
                GoalManagementView()
            }
        }
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
    }

    private func growthIcon(for route: GrowthRoute) -> String {
        switch route {
        case .reading:
            return "book.pages"
        case .courses:
            return "graduationcap"
        case .notes:
            return "doc.text"
        case .videos:
            return "play.rectangle"
        case .dailyQuote:
            return "text.bubble"
        case .moodTracking:
            return "heart"
        case .finance:
            return "wallet.pass"
        case .goals:
            return "scope"
        }
    }

    private func growthSubtitle(for route: GrowthRoute) -> String {
        switch route {
        case .reading:
            return "書單、進度、筆記、時長統計"
        case .courses:
            return "課程庫、進度看板、技能樹、證書存檔"
        case .notes:
            return "文章收藏、標籤、搜尋、知識圖譜"
        case .videos:
            return "追蹤、時間戳筆記、頻道訂閱"
        case .dailyQuote:
            return "語錄庫、自我肯定、願景板、感恩日記"
        case .moodTracking:
            return "情緒日記、週期分析、心情曲線"
        case .finance:
            return "記帳、預算、消費分析、變美基金、購物清單"
        case .goals:
            return "主題模板、里程碑、產品推薦、資源整合"
        }
    }
}

struct ReadingTrackerView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var editingBookRecord: BookRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "閱讀追蹤", action: "添加") {
                    showAdd = true
                }

                CardView {
                    if store.state.bookRecords.isEmpty {
                        EmptyStateView(title: "暫無書籍，開始添加吧", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.bookRecords) { book in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(book.author.isEmpty ? "未填寫作者" : book.author)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    if !book.link.isEmpty {
                                        Text(book.link)
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                            .lineLimit(1)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingBookRecord = book }) {
                                    store.deleteBook(book)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingBookRecord) { record in
            FieldsEditSheet(
                title: "編輯書籍",
                fieldLabels: ["書名", "作者", "連結", "筆記"],
                values: [record.title, record.author, record.link, record.note],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.title = values[0]
                updated.author = values[1]
                updated.link = values[2]
                updated.note = values[3]

                store.replaceRecord(updated, in: \.bookRecords)
            }
        }
        .sheet(isPresented: $showAdd) { AddBookSheet() }
    }
}

struct CourseTrackerView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var playingCourse: Course?
    @State private var editingCourse: Course?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "課程學習", action: "添加") {
                    showAdd = true
                }

                CardView {
                    if store.state.courses.isEmpty {
                        EmptyStateView(title: "暫無課程", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.courses) { course in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(course.title)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(AppTheme.text)
                                        Spacer()
                                        Text("\(course.progressPercent)%")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                    Text(course.platform.isEmpty ? "未填寫平台" : course.platform)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    ProgressView(value: Double(course.progressPercent), total: 100)
                                        .tint(AppTheme.primary)
                                    HStack(spacing: 14) {
                                        Button("+10%") {
                                            store.updateCourseProgress(course, progressPercent: course.progressPercent + 10)
                                        }
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppTheme.primary)

                                        if CourseVideoLink.youtubeID(from: course.url) != nil {
                                            Button {
                                                playingCourse = course
                                            } label: {
                                                Label("觀看", systemImage: "play.circle.fill")
                                            }
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.primary)
                                        } else if let external = CourseVideoLink.externalURL(from: course.url) {
                                            Link(destination: external) {
                                                Label("開啟連結", systemImage: "safari")
                                            }
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(AppTheme.primary)
                                        }
                                    }
                                }
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingCourse = course }) {
                                    store.deleteCourse(course)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showAdd) { AddCourseSheet() }
        .sheet(item: $playingCourse) { course in
            CoursePlayerSheet(course: course)
        }
        .sheet(item: $editingCourse) { course in
            FieldsEditSheet(
                title: "編輯課程",
                fieldLabels: ["課程名稱", "平台", "連結URL"],
                values: [course.title, course.platform, course.url],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = course
                updated.title = values[0]
                updated.platform = values[1]
                updated.url = values[2]
                store.replaceRecord(updated, in: \.courses)
            }
        }
    }
}

enum CourseVideoLink {
    static func youtubeID(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let host = url.host?.lowercased() else { return nil }

        if host.contains("youtu.be") {
            let id = url.pathComponents.dropFirst().first ?? ""
            return id.isEmpty ? nil : id
        }
        guard host.contains("youtube.com") else { return nil }

        if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
           let value = queryItems.first(where: { $0.name == "v" })?.value,
           !value.isEmpty {
            return value
        }
        let path = url.pathComponents
        if let index = path.firstIndex(where: { $0 == "shorts" || $0 == "embed" || $0 == "live" }),
           index + 1 < path.count {
            return path[index + 1]
        }
        return nil
    }

    static func externalURL(from urlString: String) -> URL? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let host = url.host?.lowercased(),
              url.scheme == "https" || url.scheme == "http" else { return nil }
        // 小紅書在台灣被封鎖，開了只會看到錯誤頁
        if host.contains("xiaohongshu.com") || host.contains("xhslink.com") { return nil }
        return url
    }
}

private struct CoursePlayerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: BeautyDiaryStore
    let course: Course

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let videoID = CourseVideoLink.youtubeID(from: course.url) {
                    YouTubeEmbedView(videoID: videoID)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .background(Color.black)
                } else {
                    EmptyStateView(title: "無法解析影片連結", subtitle: course.url)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text(course.title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    ProgressView(value: Double(course.progressPercent), total: 100)
                        .tint(AppTheme.primary)
                    HStack {
                        Text("進度 \(course.progressPercent)%")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                        Spacer()
                        Button("+10%") {
                            store.updateCourseProgress(course, progressPercent: course.progressPercent + 10)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                    }
                }
                .padding(20)

                Spacer()
            }
            .background(AppTheme.background)
            .navigationTitle("課程觀看")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private struct YouTubeEmbedView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url = URL(string: "https://www.youtube.com/embed/\(videoID)?playsinline=1&rel=0") else { return }
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

struct KnowledgeNotesView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var editingNote: KnowledgeNote?
    @State private var tagFilter = "全部"

    private var allTags: [String] {
        let set = Set(store.state.knowledgeNotes.flatMap(\.tags)).filter { !$0.isEmpty }
        return ["全部"] + set.sorted()
    }

    private var filteredNotes: [KnowledgeNote] {
        guard tagFilter != "全部" else { return store.state.knowledgeNotes }
        return store.state.knowledgeNotes.filter { $0.tags.contains(tagFilter) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "知識筆記", action: "新建") {
                    showAdd = true
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(allTags, id: \.self) { tag in
                            Button {
                                tagFilter = tag
                            } label: {
                                Text(tag)
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(tagFilter == tag ? AppTheme.primary : AppTheme.card)
                                    .foregroundStyle(tagFilter == tag ? Color.white : AppTheme.text)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                CardView {
                    if filteredNotes.isEmpty {
                        EmptyStateView(title: "暫無筆記", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(filteredNotes) { note in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(AppTheme.text)
                                    Text(note.content)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.subtext)
                                    if !note.tags.isEmpty {
                                        Text(note.tags.joined(separator: "、"))
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.primary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingNote = note }) {
                                    store.deleteKnowledgeNote(note)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(isPresented: $showAdd) { AddKnowledgeNoteSheet() }
        .sheet(item: $editingNote) { note in
            FieldsEditSheet(
                title: "編輯筆記",
                fieldLabels: ["標題", "重點摘錄", "標籤（逗號分隔）"],
                values: [note.title, note.content, note.tags.joined(separator: ",")],
                showsDate: false,
                date: .now
            ) { values, _ in
                var updated = note
                updated.title = values[0]
                updated.content = values[1]
                updated.tags = values[2].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                store.replaceRecord(updated, in: \.knowledgeNotes)
            }
        }
    }
}

struct VideoLearningView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var showAdd = false
    @State private var editingVideoRecord: VideoLearningRecord?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "影音學習追蹤", action: "添加") {
                    showAdd = true
                }

                CardView {
                    if store.state.videoLearningRecords.isEmpty {
                        EmptyStateView(title: "暫無影音記錄", subtitle: "")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(store.state.videoLearningRecords) { record in
                                Button {
                                    store.toggleVideoLearningWatched(record)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: record.watched ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(record.watched ? AppTheme.primary : AppTheme.subtext)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(record.title)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(AppTheme.text)
                                            Text("\(record.contentType) · \(record.platform.isEmpty ? "未填寫平台" : record.platform)")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.subtext)
                                        }
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(14)
                                .background(AppTheme.primarySoft)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .recordActions(onEdit: { editingVideoRecord = record }) {
                                    store.deleteVideoLearningRecord(record)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingVideoRecord) { record in
            FieldsEditSheet(
                title: "編輯影片學習",
                fieldLabels: ["標題", "平台", "連結URL"],
                values: [record.title, record.platform, record.url],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.title = values[0]
                updated.platform = values[1]
                updated.url = values[2]

                store.replaceRecord(updated, in: \.videoLearningRecords)
            }
        }
        .sheet(isPresented: $showAdd) { AddVideoLearningSheet() }
    }
}

struct DailyQuoteView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var quoteIndex = Int.random(in: 0..<DailyQuoteView.quotes.count)
    @State private var showAddAffirmation = false
    @State private var showAddVision = false
    @State private var showAddGratitude = false
    @State private var editingAffirmation: SelfAffirmation?
    @State private var editingVisionItem: VisionBoardItem?
    @State private var editingGratitude: GratitudeEntry?

    static let quotes = [
        "成為自己的太陽，無需借誰的光",
        "每一天都是新的開始",
        "你比自己想像的更堅強",
        "慢慢來，比較快",
        "先愛自己，再愛別人"
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "每日金句") {}

                CardView {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("「\(DailyQuoteView.quotes[quoteIndex])」")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(AppTheme.text)
                        Text("—— 今日金句")
                            .font(.caption)
                            .foregroundStyle(AppTheme.subtext)
                        Button("換一句") {
                            quoteIndex = Int.random(in: 0..<DailyQuoteView.quotes.count)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.primary)
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("自我肯定")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+添加") { showAddAffirmation = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.selfAffirmations.isEmpty {
                            EmptyStateView(title: "寫下你的肯定語", subtitle: "")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.state.selfAffirmations) { item in
                                    Text(item.text)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(AppTheme.primarySoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .recordActions(onEdit: { editingAffirmation = item }) {
                                            store.deleteSelfAffirmation(item)
                                        }
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("願景板")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+添加") { showAddVision = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.visionBoardItems.isEmpty {
                            EmptyStateView(title: "創建你的願景板", subtitle: "")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.state.visionBoardItems) { item in
                                    Text(item.text)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(12)
                                        .background(AppTheme.primarySoft)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .recordActions(onEdit: { editingVisionItem = item }) {
                                            store.deleteVisionBoardItem(item)
                                        }
                                }
                            }
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("感恩日記")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Spacer()
                            Button("+記錄") { showAddGratitude = true }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.primary)
                        }

                        if store.state.gratitudeEntries.isEmpty {
                            EmptyStateView(title: "暫無記錄", subtitle: "")
                        } else {
                            VStack(spacing: 8) {
                                ForEach(store.state.gratitudeEntries) { entry in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.text)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.text)
                                        Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption2)
                                            .foregroundStyle(AppTheme.subtext)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .recordActions(onEdit: { editingGratitude = entry }) {
                                        store.deleteGratitudeEntry(entry)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingAffirmation) { record in
            FieldsEditSheet(
                title: "編輯自我肯定",
                fieldLabels: ["內容"],
                values: [record.text],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.text = values[0]

                store.replaceRecord(updated, in: \.selfAffirmations)
            }
        }
        .sheet(item: $editingVisionItem) { record in
            FieldsEditSheet(
                title: "編輯願景板",
                fieldLabels: ["內容"],
                values: [record.text],
                showsDate: false,
                date: .now
            ) { values, newDate in
                var updated = record
                updated.text = values[0]

                store.replaceRecord(updated, in: \.visionBoardItems)
            }
        }
        .sheet(item: $editingGratitude) { record in
            FieldsEditSheet(
                title: "編輯感恩記錄",
                fieldLabels: ["內容"],
                values: [record.text],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.text = values[0]
                updated.date = newDate
                store.replaceRecord(updated, in: \.gratitudeEntries)
            }
        }
        .sheet(isPresented: $showAddAffirmation) {
            AddLinkSheet(sheetTitle: "添加自我肯定", titleFieldLabel: "我值得被愛…") { text, _ in
                store.addSelfAffirmation(text: text)
            }
        }
        .sheet(isPresented: $showAddVision) {
            AddLinkSheet(sheetTitle: "添加願景板項目", titleFieldLabel: "願景內容") { text, _ in
                store.addVisionBoardItem(text: text)
            }
        }
        .sheet(isPresented: $showAddGratitude) {
            AddLinkSheet(sheetTitle: "添加感恩日記", titleFieldLabel: "今天感謝的事") { text, _ in
                store.addGratitudeEntry(text: text)
            }
        }
    }
}

struct MoodTrackingView: View {
    @EnvironmentObject private var store: BeautyDiaryStore
    @State private var selectedMood: String?
    @State private var note = ""
    @State private var editingMoodEntry: MoodEntry?

    private let moods = [("😊", "開心"), ("😌", "平靜"), ("😔", "低落"), ("😫", "煩躁"), ("🥺", "疲憊")]

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                titleRow(title: "每日金句·情緒追蹤") {}

                CardView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("「\(DailyQuoteView.quotes.first ?? "")」")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.text)
                        Text("—— 今日金句")
                            .font(.caption2)
                            .foregroundStyle(AppTheme.subtext)
                    }
                }

                if let firstAffirmation = store.state.selfAffirmations.first {
                    CardView {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(firstAffirmation.text)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppTheme.text)
                            Text("—— 今日自我肯定")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.subtext)
                        }
                    }
                }

                CardView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("今日情緒")
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)

                        HStack(spacing: 14) {
                            ForEach(moods, id: \.1) { mood in
                                Button {
                                    selectedMood = mood.1
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(mood.0)
                                            .font(.title2)
                                        Text(mood.1)
                                            .font(.caption2)
                                            .foregroundStyle(selectedMood == mood.1 ? AppTheme.primary : AppTheme.subtext)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(selectedMood == mood.1 ? AppTheme.primarySoft : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        }

                        ThemedTextField(title: "記錄此刻的感受…", text: $note)

                        PrimaryButton(title: "保存") {
                            guard let selectedMood else { return }
                            store.addMoodEntry(mood: selectedMood, note: note)
                            note = ""
                        }
                    }
                }

                if !store.state.moodEntries.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("情緒紀錄")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            VStack(spacing: 8) {
                                ForEach(store.state.moodEntries) { entry in
                                    HStack {
                                        Text(entry.mood)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(entry.note.isEmpty ? entry.date.formatted(date: .abbreviated, time: .omitted) : entry.note)
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.text)
                                        }
                                        Spacer()
                                    }
                                    .padding(10)
                                    .background(AppTheme.primarySoft)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .recordActions(onEdit: { editingMoodEntry = entry }) {
                                        store.deleteMoodEntry(entry)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .sheet(item: $editingMoodEntry) { record in
            FieldsEditSheet(
                title: "編輯心情記錄",
                fieldLabels: ["心情", "備註"],
                values: [record.mood, record.note],
                showsDate: true,
                date: record.date
            ) { values, newDate in
                var updated = record
                updated.mood = values[0]
                updated.note = values[1]
                updated.date = newDate
                store.replaceRecord(updated, in: \.moodEntries)
            }
        }
    }
}

