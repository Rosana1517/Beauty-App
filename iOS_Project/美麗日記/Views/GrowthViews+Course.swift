import SwiftUI
import PhotosUI
import UIKit
import WebKit
import Charts

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
                                .recordActions(onEdit: { editingCourse = course }, onDelete: {
                                    store.deleteCourse(course)
                                })
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
