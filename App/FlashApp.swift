// Minimal WebView wrapper for the Flash prototype.
// No analytics, no tracking, no author/team metadata.
// The only network traffic is the prototype's live bitcoin price feed
// (Coinbase public websocket + candles endpoint). It runs fine offline.

import SwiftUI
import WebKit
import WidgetKit

@main
struct FlashApp: App {
    // A plain shared object: nothing observes it for view updates, so it needs no
    // ObservableObject conformance (which would also require importing Combine).
    private let router = DeepLinkRouter.shared

    var body: some Scene {
        WindowGroup {
            PrototypeView(router: router)
                .ignoresSafeArea()
                .statusBarHidden(false)
                .preferredColorScheme(.dark)
                // flash://nfc, flash://send, flash://receive, flash://home, flash://settings
                .onOpenURL { router.open($0) }
        }
    }
}

/// Turns a widget's `flash://<target>` into the `#flash=<target>` hash the page listens for.
/// index.html applies it on load and on hashchange, then clears it.
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    static let targets: Set<String> = ["nfc", "send", "receive", "home", "settings"]

    /// Set when a link arrives before the WebView is ready; consumed on first load.
    private(set) var pending: String?
    weak var webView: WKWebView?

    func open(_ url: URL) {
        // flash://nfc gives host == "nfc"; flash:///nfc gives it in the path
        let raw = url.host ?? url.path.replacingOccurrences(of: "/", with: "")
        let target = raw.lowercased()
        guard Self.targets.contains(target) else { return }

        // Not loaded yet (cold start from a widget tap): hold it for didFinish.
        guard let web = webView, !web.isLoading, web.url != nil else {
            pending = target
            return
        }
        apply(target, to: web)
    }

    /// Applies the hash and nudges the page, which listens on hashchange.
    func apply(_ target: String, to web: WKWebView) {
        web.evaluateJavaScript("location.hash = 'flash=\(target)'")
    }

    func consumePending() -> String? {
        defer { pending = nil }
        return pending
    }
}

struct PrototypeView: UIViewRepresentable {
    let router: DeepLinkRouter

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .nonPersistent()

        // Prototype-only: the page is loaded from file://, so let it reach the
        // public price feed without tripping cross-origin checks.
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

        // the page posts accent / currency / LN address here whenever they change
        config.userContentController.add(context.coordinator, name: "flash")

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.backgroundColor = .black
        web.scrollView.bounces = false
        web.scrollView.isScrollEnabled = false
        web.allowsBackForwardNavigationGestures = false
        router.webView = web
        web.navigationDelegate = context.coordinator

        // Always load the bare file URL. loadFileURL does not reliably carry a fragment,
        // so a cold-start deep link is applied in didFinish instead.
        if let url = indexURL() {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(router: router) }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let router: DeepLinkRouter
        init(router: DeepLinkRouter) { self.router = router }

        /// window.webkit.messageHandlers.flash.postMessage({...}) from the page.
        func userContentController(_ controller: WKUserContentController,
                                   didReceive message: WKScriptMessage) {
            guard let d = message.body as? [String: Any] else { return }

            // { haptic: "success" | "warning" | "tap" } — a confirmation landed
            if let kind = d["haptic"] as? String {
                Haptics.play(kind)
                return
            }

            FlashSharedState.write(
                accentId: d["accentId"] as? String,
                accentHex: d["accentHex"] as? String,
                accentLtHex: d["accentLtHex"] as? String,
                currencySymbol: d["currencySymbol"] as? String,
                currencyCode: d["currencyCode"] as? String,
                lightningAddress: d["lightningAddress"] as? String,
                username: d["username"] as? String
            )
            // repaint the home screen with the new accent
            WidgetCenter.shared.reloadAllTimelines()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // the page is up: if a widget tap arrived before this, act on it now
            if let target = router.consumePending() {
                router.apply(target, to: webView)
            }
        }
    }

    private func indexURL() -> URL? {
        Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Web")
            ?? Bundle.main.url(forResource: "index", withExtension: "html")
    }
}

/// Native haptics for the WebView. iOS ignores navigator.vibrate, so the page posts a
/// message and this plays the matching Taptic pattern.
enum Haptics {
    /// Kept alive between calls: a generator created and released per tap has to warm the
    /// engine up each time, which delays the first buzz noticeably.
    private static let notification = UINotificationFeedbackGenerator()
    private static let impact = UIImpactFeedbackGenerator(style: .medium)

    static func play(_ kind: String) {
        DispatchQueue.main.async {
            switch kind {
            case "success":
                notification.prepare()
                notification.notificationOccurred(.success)
            case "warning":
                notification.prepare()
                notification.notificationOccurred(.warning)
            case "error":
                notification.prepare()
                notification.notificationOccurred(.error)
            default:
                impact.prepare()
                impact.impactOccurred()
            }
        }
    }
}
