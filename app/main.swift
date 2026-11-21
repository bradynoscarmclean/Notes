import Cocoa
import WebKit
import UniformTypeIdentifiers

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKScriptMessageHandlerWithReply,
                         WKUIDelegate, WKNavigationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var store: [String: String] = [:]

    // Notes, shorthands and settings live in ~/Library/Application Support/Termnotes/store.json,
    // pasted images in the images/ folder next to it
    static let supportDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Termnotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir.appendingPathComponent("images"), withIntermediateDirectories: true)
        return dir
    }()
    let storeURL = AppDelegate.supportDir.appendingPathComponent("store.json")
    let imagesDir = AppDelegate.supportDir.appendingPathComponent("images", isDirectory: true)

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        if let data = try? Data(contentsOf: storeURL),
           let saved = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            store = saved
        }
        let storeJSON = String(data: (try? JSONSerialization.data(withJSONObject: store)) ?? Data("{}".utf8), encoding: .utf8) ?? "{}"

        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(
            source: "window.nativeStore = \(storeJSON); window.hasGitHubApp = \(gitHubClientID != nil);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true))
        config.userContentController.add(self, name: "store")
        config.userContentController.add(self, name: "github")
        config.userContentController.add(self, name: "theme")
        config.userContentController.addScriptMessageHandler(self, contentWorld: .page, name: "images")
        config.setURLSchemeHandler(ImageSchemeHandler(dir: imagesDir), forURLScheme: "tnimg")

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.title = "Termnotes"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        applyTheme(store["termnotes.theme"].map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) })

        // See-through blurred background, like a translucent terminal; the page draws a tint on top
        let blur = NSVisualEffectView()
        blur.material = .underWindowBackground
        blur.blendingMode = .behindWindow
        blur.state = .active
        window.contentView = blur

        webView = WKWebView(frame: blur.bounds, configuration: config)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.autoresizingMask = [.width, .height]
        blur.addSubview(webView)

        // The web view covers the title bar, so this strip keeps the window draggable
        let dragStrip = DragStrip(frame: NSRect(x: 0, y: blur.bounds.height - 28, width: blur.bounds.width, height: 28))
        dragStrip.autoresizingMask = [.width, .minYMargin]
        blur.addSubview(dragStrip)

        window.center()
        window.setFrameAutosaveName("TermnotesMain")
        window.makeKeyAndOrderFront(nil)

        let page = Bundle.main.url(forResource: "index", withExtension: "html")!
        webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // nil follows the system setting
    func applyTheme(_ mode: String?) {
        switch mode {
        case "light": window.appearance = NSAppearance(named: .aqua)
        case "dark": window.appearance = NSAppearance(named: .darkAqua)
        default: window.appearance = nil
        }
    }

    // Page calls window.webkit.messageHandlers.store.postMessage({key, value})
    // and window.webkit.messageHandlers.github.postMessage({action: "login"})
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "github" {
            startGitHubLogin()
            return
        }
        if message.name == "theme" {
            applyTheme(message.body as? String)
            return
        }
        guard let body = message.body as? [String: Any],
              let key = body["key"] as? String,
              let value = body["value"] as? String else { return }
        store[key] = value
        if let data = try? JSONSerialization.data(withJSONObject: store) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    // MARK: Images
    // await window.webkit.messageHandlers.images.postMessage({action: "save", name, data}) or ({action: "read", name})
    // `data` is base64; images are only ever read/written by bare file name inside imagesDir
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String: Any],
              let name = body["name"] as? String,
              name.range(of: #"^[\w.-]+$"#, options: .regularExpression) != nil, !name.hasPrefix(".") else {
            replyHandler(nil, "bad image name")
            return
        }
        let file = imagesDir.appendingPathComponent(name)
        switch body["action"] as? String {
        case "save":
            guard let base64 = body["data"] as? String, let data = Data(base64Encoded: base64) else {
                replyHandler(nil, "bad image data")
                return
            }
            do {
                try data.write(to: file, options: .atomic)
                replyHandler(name, nil)
            } catch {
                replyHandler(nil, error.localizedDescription)
            }
        case "read":
            replyHandler((try? Data(contentsOf: file))?.base64EncodedString(), nil)
        default:
            replyHandler(nil, "unknown action")
        }
    }

    // <input type="file"> needs this to show a file picker
    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.allowedContentTypes = [.image]
        panel.beginSheetModal(for: window) { completionHandler($0 == .OK ? panel.urls : nil) }
    }

    // MARK: Links open in the default browser instead of replacing the app

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, !url.isFileURL, url.scheme != "about" else {
            decisionHandler(.allow)
            return
        }
        if action.targetFrame?.isMainFrame ?? true { NSWorkspace.shared.open(url) }
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    // MARK: GitHub sign-in (OAuth device flow)
    // Runs here rather than in the page because GitHub's login endpoints don't allow browser requests.

    struct GitHubError: Error { let message: String }
    var gitHubLoginRunning = false

    // Without a client ID in Info.plist, the page falls back to asking for a token
    var gitHubClientID: String? {
        (Bundle.main.object(forInfoDictionaryKey: "GitHubClientID") as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    func startGitHubLogin() {
        guard !gitHubLoginRunning else { return }
        guard let clientID = gitHubClientID else {
            sendGitHub(["error": "this copy of Termnotes has no GitHub app set up"])
            return
        }
        gitHubLoginRunning = true
        Task { @MainActor in
            defer { gitHubLoginRunning = false }
            do {
                let start = try await postForm("https://github.com/login/device/code",
                                               ["client_id": clientID, "scope": "repo"])
                guard let deviceCode = start["device_code"] as? String,
                      let userCode = start["user_code"] as? String,
                      let verifyURL = (start["verification_uri"] as? String).flatMap(URL.init(string:)) else {
                    throw GitHubError(message: start["error_description"] as? String ?? "couldn't start sign-in")
                }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(userCode, forType: .string)
                sendGitHub(["code": userCode])
                NSWorkspace.shared.open(verifyURL)

                var interval = start["interval"] as? Int ?? 5
                let deadline = Date().addingTimeInterval(TimeInterval(start["expires_in"] as? Int ?? 900))
                while Date() < deadline {
                    try await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                    let poll = try await postForm("https://github.com/login/oauth/access_token", [
                        "client_id": clientID,
                        "device_code": deviceCode,
                        "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                    ])
                    if let token = poll["access_token"] as? String {
                        sendGitHub(["token": token])
                        NSApp.activate(ignoringOtherApps: true)
                        return
                    }
                    switch poll["error"] as? String {
                    case "authorization_pending": continue
                    case "slow_down": interval += 5
                    default: throw GitHubError(message: poll["error_description"] as? String ?? "sign-in was cancelled")
                    }
                }
                throw GitHubError(message: "the code expired, press ⌘G to try again")
            } catch {
                sendGitHub(["error": (error as? GitHubError)?.message ?? error.localizedDescription])
            }
        }
    }

    func postForm(_ url: String, _ fields: [String: String]) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: url)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = fields.map { URLQueryItem(name: $0.key, value: $0.value) }
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, _) = try await URLSession.shared.data(for: request)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func sendGitHub(_ payload: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else { return }
        webView.evaluateJavaScript("window.githubLogin(\(json))")
    }

    // WKWebView needs these for confirm() and alert() to work
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        completionHandler(alert.runModal() == .alertFirstButtonReturn)
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.runModal()
        completionHandler()
    }

    @objc func openSettings() {
        webView.evaluateJavaScript("openSettings()")
    }

    // Without an Edit menu, ⌘C / ⌘V / ⌘Z don't reach the web view
    func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Termnotes", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Termnotes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        main.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        main.addItem(windowItem)

        NSApp.mainMenu = main
    }
}

// Serves tnimg://local/<name> from the images folder so the page can show pasted images
final class ImageSchemeHandler: NSObject, WKURLSchemeHandler {
    let dir: URL
    init(dir: URL) { self.dir = dir }

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url,
              url.lastPathComponent.range(of: #"^[\w.-]+$"#, options: .regularExpression) != nil,
              let data = try? Data(contentsOf: dir.appendingPathComponent(url.lastPathComponent)) else {
            task.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        task.didReceive(URLResponse(url: url, mimeType: mime, expectedContentLength: data.count, textEncodingName: nil))
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

final class DragStrip: NSView {
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { window?.zoom(nil) } else { window?.performDrag(with: event) }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
