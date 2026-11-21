import Cocoa
import WebKit

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKUIDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var store: [String: String] = [:]

    // Notes, shorthands and settings live in ~/Library/Application Support/Termnotes/store.json
    let storeURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Termnotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("store.json")
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        if let data = try? Data(contentsOf: storeURL),
           let saved = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
            store = saved
        }
        let storeJSON = String(data: (try? JSONSerialization.data(withJSONObject: store)) ?? Data("{}".utf8), encoding: .utf8) ?? "{}"

        let config = WKWebViewConfiguration()
        config.userContentController.addUserScript(WKUserScript(
            source: "window.nativeStore = \(storeJSON);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true))
        config.userContentController.add(self, name: "store")

        webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webView.setValue(false, forKey: "drawsBackground")

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        window.title = "Termnotes"
        window.backgroundColor = NSColor(red: 0.118, green: 0.122, blue: 0.133, alpha: 1)
        window.appearance = NSAppearance(named: .darkAqua)
        window.contentView = webView
        window.center()
        window.setFrameAutosaveName("TermnotesMain")
        window.makeKeyAndOrderFront(nil)

        let page = Bundle.main.url(forResource: "index", withExtension: "html")!
        webView.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    // Page calls window.webkit.messageHandlers.store.postMessage({key, value})
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let key = body["key"] as? String,
              let value = body["value"] as? String else { return }
        store[key] = value
        if let data = try? JSONSerialization.data(withJSONObject: store) {
            try? data.write(to: storeURL, options: .atomic)
        }
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

    // Without an Edit menu, ⌘C / ⌘V / ⌘Z don't reach the web view
    func buildMenu() {
        let main = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
