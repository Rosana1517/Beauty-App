import SwiftUI
import WebKit

/// 運動資料庫詳情:GIF/插圖示範 + 繁中教學步驟。
struct ExerciseLibraryDetailView: View {
    let item: ExerciseLibraryItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                mediaSection

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.displayName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    if let secondary = item.secondaryName {
                        Text(secondary)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.subtext)
                    }
                    HStack(spacing: 6) {
                        ForEach(item.badgeTexts, id: \.self) { badge in
                            Text(badge)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AppTheme.primarySoft)
                                .foregroundStyle(AppTheme.primary)
                                .clipShape(Capsule())
                        }
                    }
                }

                if let steps = item.stepsZh, !steps.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("動作步驟")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Color.white)
                                        .frame(width: 22, height: 22)
                                        .background(AppTheme.primary)
                                        .clipShape(Circle())
                                    Text(step)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.text)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                } else if let description = item.resolvedDescription {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("動作說明")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                        }
                    }
                }

                if let benefits = item.benefitsZh, !benefits.isEmpty {
                    CardView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("功效")
                                .font(.headline)
                                .foregroundStyle(AppTheme.text)
                            Text(benefits)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.text)
                        }
                    }
                }

                if let attribution = item.attribution, !attribution.isEmpty {
                    Text("圖片來源:\(attribution)")
                        .font(.caption2)
                        .foregroundStyle(AppTheme.subtext)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
    }

    @ViewBuilder
    private var mediaSection: some View {
        if let gifUrl = item.gifUrl, let url = URL(string: gifUrl) {
            AnimatedGIFView(url: url)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit()
                } else if phase.error != nil {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(AppTheme.subtext)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }
}

/// AsyncImage 只會顯示 GIF 第一幀,改用 WKWebView 內嵌 <img> 播放動畫。
struct AnimatedGIFView: UIViewRepresentable {
    let url: URL

    final class Coordinator {
        var loadedURL: URL?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .white
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url
        let html = """
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
        <body style="margin:0;background:#fff;display:flex;align-items:center;justify-content:center;">
        <img src="\(url.absoluteString)" style="max-width:100%;max-height:100vh;">
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
