// Cactus Coffee — cactuscafes.com'u uygulama penceresinde açan ince iOS kabuğu.
// Sitede yapılan her değişiklik uygulama güncellemesi gerektirmeden burada görünür.
import SwiftUI
import WebKit

let SITE_URL = URL(string: "https://cactuscafes.com/menu-podyum.html")!

@main
struct CactusCoffeeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var baglantiHatasi = false

    var body: some View {
        ZStack {
            Color(red: 0.99, green: 0.98, blue: 0.95).ignoresSafeArea()
            if baglantiHatasi {
                VStack(spacing: 14) {
                    Text("🌵").font(.system(size: 56))
                    Text("Bağlantı kurulamadı").font(.headline)
                    Text("İnternet bağlantını kontrol edip tekrar dene.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Tekrar Dene") { baglantiHatasi = false }
                        .padding(.horizontal, 26)
                        .padding(.vertical, 11)
                        .background(Color(red: 0.18, green: 0.35, blue: 0.15))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .padding(30)
            } else {
                SiteView(baglantiHatasi: $baglantiHatasi)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }
}

struct SiteView: UIViewRepresentable {
    @Binding var baglantiHatasi: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.navigationDelegate = context.coordinator
        wv.allowsBackForwardNavigationGestures = true
        wv.isOpaque = false
        wv.backgroundColor = UIColor(red: 0.99, green: 0.98, blue: 0.95, alpha: 1)
        context.coordinator.webView = wv

        let yenile = UIRefreshControl()
        yenile.addTarget(context.coordinator, action: #selector(Coordinator.yenile(_:)), for: .valueChanged)
        wv.scrollView.refreshControl = yenile

        wv.load(URLRequest(url: SITE_URL))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: SiteView
        weak var webView: WKWebView?
        init(_ parent: SiteView) { self.parent = parent }

        @objc func yenile(_ rc: UIRefreshControl) {
            webView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { rc.endRefreshing() }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled {
                DispatchQueue.main.async { self.parent.baglantiHatasi = true }
            }
        }

        // tel:, mailto:, WhatsApp vb. sistemde; Instagram/Maps gibi dış siteler Safari'de açılır.
        func webView(_ webView: WKWebView,
                     decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let url = navigationAction.request.url else { decisionHandler(.allow); return }
            let scheme = url.scheme ?? ""
            if scheme != "http" && scheme != "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }
            let host = url.host ?? ""
            if host.hasSuffix("cactuscafes.com") || host.hasSuffix("workers.dev") {
                decisionHandler(.allow)
            } else if navigationAction.targetFrame == nil || navigationAction.targetFrame?.isMainFrame == true {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
