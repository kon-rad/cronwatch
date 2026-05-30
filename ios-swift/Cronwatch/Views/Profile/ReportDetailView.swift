import SwiftUI
import UniformTypeIdentifiers
@preconcurrency import WebKit

struct ReportDetailView: View {
    let report: ProfileReport
    let onClose: () -> Void

    /// Owns the live WKWebView so the toolbar can render it to PDF on demand and
    /// observe when content has finished loading.
    @StateObject private var controller = ReportWebController()
    @State private var exporting = false
    @State private var shareItem: PDFShareItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.bg.ignoresSafeArea()
                ReportWebView(html: ReportDetailView.wrap(report.html), controller: controller)
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
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await exportPDF() } }) {
                        if exporting {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(controller.isReady ? Palette.ink : Palette.muted)
                        }
                    }
                    .disabled(!controller.isReady || exporting)
                }
            }
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    private func exportPDF() async {
        guard !exporting else { return }
        exporting = true
        defer { exporting = false }
        do {
            let data = try await controller.renderPDF()
            let url = try Self.writeTempPDF(data: data, title: report.title)
            shareItem = PDFShareItem(url: url)
        } catch {
            print("[ReportDetail] PDF export failed: \(error)")
            ToastCenter.shared.show(message: "Couldn’t export PDF.", kind: .error)
        }
    }

    /// Writes the PDF to a temp file named from the (sanitized) report title so
    /// the share sheet and Files surface a meaningful filename.
    private static func writeTempPDF(data: Data, title: String) throws -> URL {
        let name = sanitizeFilename(title)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(name)
            .appendingPathExtension("pdf")
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func sanitizeFilename(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let cleaned = trimmed.components(separatedBy: illegal).joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Cronwatch Report" : String(cleaned.prefix(80))
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

private struct PDFShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// Holds the live WKWebView and bridges load-completion + PDF rendering to SwiftUI.
@MainActor
final class ReportWebController: ObservableObject {
    @Published var isReady = false
    fileprivate weak var webView: WKWebView?

    enum ExportError: Error { case noWebView }

    func renderPDF() async throws -> Data {
        guard let webView else { throw ExportError.noWebView }
        let config = WKPDFConfiguration()
        return try await webView.pdf(configuration: config)
    }
}

private struct ReportWebView: UIViewRepresentable {
    let html: String
    let controller: ReportWebController

    func makeCoordinator() -> Coordinator { Coordinator(controller: controller) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Reports are user-generated content; isolate from cookies and storage.
        let dataStore = WKWebsiteDataStore.nonPersistent()
        config.websiteDataStore = dataStore
        config.defaultWebpagePreferences.allowsContentJavaScript = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.backgroundColor = UIColor(named: "ReportBackground") ?? UIColor(red: 0.98, green: 0.98, blue: 0.97, alpha: 1)
        webView.backgroundColor = webView.scrollView.backgroundColor
        webView.isOpaque = false
        controller.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: nil)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let controller: ReportWebController

        init(controller: ReportWebController) {
            self.controller = controller
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in controller.isReady = true }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
