import SwiftUI
import WebKit

/// Duty Log View - Opens Roompact duty log form in a WKWebView
struct DutyLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var webView = DutyLogWebView()

    private let roompactFormURL: URL? = URL(string: "https://roompact.com/forms/#/form/b0llDq")

    var body: some View {
        NavigationStack {
            ZStack {
                if let url = roompactFormURL {
                    DutyLogWebViewWrapper(webView: webView, url: url, isLoading: $isLoading)
                        .edgesIgnoringSafeArea(.bottom)
                } else {
                    Text("Unable to load duty log form")
                        .foregroundColor(.secondary)
                }

                if isLoading && roompactFormURL != nil {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                        Text("Loading Duty Log...")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                if let error = webView.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Failed to load form")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(error.localizedDescription)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button {
                            webView.error = nil
                            webView.reload()
                        } label: {
                            Text("Retry")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(24)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
            }
            .navigationTitle("Duty Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !isLoading {
                        Button {
                            webView.reload()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Duty Log WebView

class DutyLogWebView: WKWebView {
    var error: Error?

    override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        self.init(frame: .zero, configuration: config)
    }
}

// MARK: - WebView Wrapper

struct DutyLogWebViewWrapper: UIViewRepresentable {
    let webView: DutyLogWebView
    let url: URL
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.error = nil

        // Enable pull to refresh
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url == nil {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: DutyLogWebViewWrapper

        init(_ parent: DutyLogWebViewWrapper) {
            self.parent = parent
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            parent.webView.reload()
            sender.endRefreshing()
        }

        // MARK: - Navigation Delegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                self.parent.webView.error = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleError(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleError(error)
        }

        private func handleError(_ error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.webView.error = error
            }
        }

        // MARK: - UI Delegate (Handle popups/new windows)

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Force open in the same web view if trying to open new window
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

#Preview {
    DutyLogView()
}
