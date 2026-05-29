import SwiftUI
@preconcurrency import WebKit

struct ReportDetailView: View {
    let report: ProfileReport
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ReportWebView(html: ReportDetailView.wrap(report.html))
                    .ignoresSafeArea(edges: .bottom)
            }
            .navigationTitle(report.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Palette.ink)
                    }
                }
            }
        }
    }

    /// Wraps the HTML fragment returned by the LLM in a minimal document so a
    /// raw fragment renders consistently in WKWebView (correct viewport, etc.).
    private static func wrap(_ fragment: String) -> String {
        return """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
        <style>
          html, body { margin: 0; padding: 0; background: #FAFAF7; color: #111; }
          body { font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; font-size: 15px; line-height: 1.5; padding: 16px; padding-bottom: 48px; -webkit-text-size-adjust: 100%; }
          svg { max-width: 100%; height: auto; }
          * { box-sizing: border-box; }
        </style>
        </head>
        <body>
        \(fragment)
        </body>
        </html>
        """
    }
}

private struct ReportWebView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Reports are user-generated content; isolate from cookies and storage.
        let dataStore = WKWebsiteDataStore.nonPersistent()
        config.websiteDataStore = dataStore
        config.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.backgroundColor = UIColor(named: "ReportBackground") ?? UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)
        webView.backgroundColor = webView.scrollView.backgroundColor
        webView.isOpaque = false
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }
}
