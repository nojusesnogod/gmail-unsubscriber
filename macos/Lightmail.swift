import AppKit
import Foundation
import WebKit

private struct RunningInstance: Decodable {
    let origin: String
    let instance_id: String
    let pid: Int
}

final class LightmailApp: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKUIDelegate {
    private var window: NSWindow!
    private var webView: WKWebView!
    private var projectRoot: URL!
    private var activeOrigin: URL?
    private var ownedProcess: Process?
    private var outputPipe: Pipe?
    private var outputBuffer = Data()
    private var oldInstanceDetected = false
    private var quitting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let appMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "Quit Lightmail", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let menu = NSMenu()
        menu.addItem(appItem)
        NSApp.mainMenu = menu

        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1120, height: 780),
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered, defer: false)
        window.title = "Lightmail"
        window.minSize = NSSize(width: 720, height: 540)
        window.contentView = webView
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        showStatus("Starting Lightmail…")

        // The generated app stays inside this project; it is not a portable installer.
        projectRoot = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("app.py").path) else {
            showStatus("Project files are missing. Keep Lightmail.app in this project's dist folder.")
            return
        }
        reuseOrStart()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        quitting = true
        guard let process = ownedProcess, process.isRunning else { return .terminateNow }
        showStatus("Stopping Lightmail safely…")
        process.terminate()
        return .terminateLater
    }

    private func showStatus(_ message: String) {
        let safe = message.replacingOccurrences(of: "&", with: "&amp;")
                          .replacingOccurrences(of: "<", with: "&lt;")
                          .replacingOccurrences(of: ">", with: "&gt;")
        webView.loadHTMLString("<html><meta name='viewport' content='width=device-width'><body style='font:18px -apple-system;padding:44px;color:#263434'>\(safe)</body></html>", baseURL: nil)
    }

    private func storedInstance() -> (RunningInstance, URL)? {
        let lockFile = projectRoot.appendingPathComponent(".local/v2-live/app.lock")
        guard let data = try? Data(contentsOf: lockFile),
              let instance = try? JSONDecoder().decode(RunningInstance.self, from: data),
              instance.instance_id.range(of: "^[0-9a-f]{32}$", options: .regularExpression) != nil,
              let url = URL(string: instance.origin),
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "http", parts.host == "127.0.0.1",
              let port = parts.port, port > 0 && port < 65536,
              parts.path.isEmpty, parts.query == nil, parts.fragment == nil else { return nil }
        return (instance, url)
    }

    private func probe(_ instance: RunningInstance, url: URL, completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: .ephemeral)
        session.dataTask(with: request) { _, response, _ in
            let http = response as? HTTPURLResponse
            let matches = http?.statusCode == 200 &&
                http?.value(forHTTPHeaderField: "X-Lightmail-Instance") == instance.instance_id &&
                http?.value(forHTTPHeaderField: "Server")?.hasPrefix("Lightmail/2") == true
            session.invalidateAndCancel()
            DispatchQueue.main.async { completion(matches) }
        }.resume()
    }

    private func reuseOrStart() {
        if let (instance, url) = storedInstance() {
            probe(instance, url: url) { [weak self] valid in
                if valid { self?.openLocal(url) } else { self?.startServer() }
            }
        } else {
            startServer()
        }
    }

    private func startServer() {
        let launcher = projectRoot.appendingPathComponent("scripts/launch-v2.sh")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [launcher.path, "live", "--no-browser"]
        process.currentDirectoryURL = projectRoot
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        outputPipe = pipe
        outputBuffer = Data()
        oldInstanceDetected = false
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async { self?.consumeOutput(data) }
        }
        process.terminationHandler = { [weak self] task in
            DispatchQueue.main.async { self?.processEnded(task) }
        }
        do {
            try process.run()
            ownedProcess = process
        } catch {
            showStatus("Could not start Lightmail. Check the project environment and try again.")
        }
    }

    private func consumeOutput(_ data: Data) {
        outputBuffer.append(data)
        while let newline = outputBuffer.firstIndex(of: 10) {
            let line = String(decoding: outputBuffer[..<newline], as: UTF8.self)
            outputBuffer.removeSubrange(...newline)
            if line.contains("已有轻邮在运行") { oldInstanceDetected = true }
            if line.hasPrefix("打开 http://127.0.0.1:"),
               let url = URL(string: String(line.dropFirst("打开 ".count))),
               let (instance, storedURL) = storedInstance(), storedURL == url {
                probe(instance, url: url) { [weak self] valid in
                    if valid { self?.openLocal(url) }
                }
            }
        }
        if outputBuffer.count > 8192 { outputBuffer = Data(outputBuffer.suffix(4096)) }
    }

    private func openLocal(_ url: URL) {
        activeOrigin = url
        webView.load(URLRequest(url: url))
        window.makeKeyAndOrderFront(nil)
    }

    private func processEnded(_ process: Process) {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil
        if quitting {
            NSApp.reply(toApplicationShouldTerminate: true)
            return
        }
        if activeOrigin == nil, let (instance, url) = storedInstance() {
            probe(instance, url: url) { [weak self] valid in
                if valid { self?.openLocal(url) } else { self?.showStoppedAlert() }
            }
        } else {
            showStoppedAlert()
        }
    }

    private func showStoppedAlert() {
        activeOrigin = nil
        if oldInstanceDetected {
            showStatus("An older Lightmail service is running. Close its terminal normally, then reopen this app.")
            return
        }
        showStatus("Lightmail stopped. You can restart it without repeating a scan.")
        let alert = NSAlert()
        alert.messageText = "Lightmail stopped"
        alert.informativeText = "The local service is no longer available. Restarting will restore saved data; it will not scan or resubmit a request."
        alert.addButton(withTitle: "Restart")
        alert.addButton(withTitle: "Close")
        alert.beginSheetModal(for: window) { [weak self] result in
            if result == .alertFirstButtonReturn { self?.reuseOrStart() }
        }
    }

    private func isOwnAddress(_ url: URL) -> Bool {
        guard let active = activeOrigin else { return false }
        return url.scheme == "http" && url.host == "127.0.0.1" && url.port == active.port
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.scheme == "about" || isOwnAddress(url) {
            decisionHandler(.allow)
        } else {
            if url.scheme == "https" || url.scheme == "mailto" { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        }
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, url.scheme == "https" {
            NSWorkspace.shared.open(url)
        }
        return nil
    }
}

let app = NSApplication.shared
let delegate = LightmailApp()
app.delegate = delegate
app.run()
