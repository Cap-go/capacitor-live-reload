import Capacitor
import Foundation
import UIKit

@objc(LiveReloadPlugin)
public class LiveReloadPlugin: CAPPlugin, CAPBridgedPlugin {
    private let PLUGIN_VERSION: String = "7.0.0"
    public let identifier = "LiveReloadPlugin"
    public let jsName = "LiveReload"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "configureServer", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "connect", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "disconnect", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getStatus", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reload", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "reloadFile", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getPluginVersion", returnType: CAPPluginReturnPromise)
    ]

    private var configuration = LiveReloadConfiguration()
    private var status = LiveReloadStatus(connected: false, url: nil)
    private var webSocketTask: URLSessionWebSocketTask?
    private lazy var session: URLSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var reconnectWorkItem: DispatchWorkItem?
    private var manualDisconnect = false
    private var initialURL: URL?
    private var usingLiveReload = false
    private var disconnectAlert: UIAlertController?

    // MARK: - Plugin Methods

    @objc func configureServer(_ call: CAPPluginCall) {
        guard let urlString = call.options["url"] as? String, let url = URL(string: urlString) else {
            call.reject("Missing 'url'")
            return
        }
        configuration.url = url
        if let path = call.options["websocketPath"] as? String, !path.isEmpty {
            configuration.websocketPath = path
        } else {
            configuration.websocketPath = "/ws"
        }
        if let reconnectFlag = call.options["autoReconnect"] as? Bool {
            configuration.autoReconnect = reconnectFlag
        } else {
            configuration.autoReconnect = true
        }
        if let intervalValue = call.options["reconnectInterval"] as? NSNumber {
            configuration.reconnectInterval = intervalValue.doubleValue / 1000.0
        }
        if let headersObject = call.options["headers"] as? [String: Any] {
            var headers: [String: String] = [:]
            for (key, value) in headersObject {
                if let text = value as? String {
                    headers[key] = text
                }
            }
            configuration.headers = headers
        }
        captureInitialURL()
        status.url = url.absoluteString
        notifyStatus()
        call.resolve(status.toResult())
    }

    @objc func connect(_ call: CAPPluginCall) {
        guard configuration.url != nil else {
            call.reject("Server URL is not configured")
            return
        }
        manualDisconnect = false
        dismissDisconnectedAlert()
        openSocket()
        call.resolve(status.toResult())
    }

    @objc func disconnect(_ call: CAPPluginCall) {
        manualDisconnect = true
        dismissDisconnectedAlert()
        closeSocket()
        restoreOriginalContent()
        call.resolve(status.toResult())
    }

    @objc func getStatus(_ call: CAPPluginCall) {
        call.resolve(status.toResult())
    }

    @objc func reload(_ call: CAPPluginCall) {
        reloadWebView()
        call.resolve()
    }

    @objc func reloadFile(_ call: CAPPluginCall) {
        reloadWebView()
        call.resolve()
    }

    // MARK: - WebSocket Lifecycle

    private func openSocket() {
        guard let request = buildRequest() else {
            notifyEvent(type: "error", message: "Unable to build WebSocket request")
            return
        }
        manualDisconnect = false
        dismissDisconnectedAlert()
        closeSocket()
        let task = session.webSocketTask(with: request)
        webSocketTask = task
        task.resume()
        receiveNextMessage()
    }

    private func closeSocket() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        setConnected(false)
    }

    private func buildRequest() -> URLRequest? {
        guard let wsURL = configuration.websocketURL else {
            return nil
        }
        var request = URLRequest(url: wsURL)
        configuration.headers.forEach { key, value in
            request.addValue(value, forHTTPHeaderField: key)
        }
        return request
    }

    private func receiveNextMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.handleFailure(error)
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveNextMessage()
            }
        }
    }

    private func handleMessage(_ text: String) {
        let defaultType = "full-reload"
        if let payload = text.jsonObject {
            let type = payload["type"] as? String ?? defaultType
            switch type {
            case "file-update":
                var filePayload: [String: Any] = [:]
                if let nested = payload["file"] as? [String: Any] {
                    filePayload = nested
                } else {
                    if let path = payload["path"] as? String { filePayload["path"] = path }
                    if let hash = payload["hash"] as? String { filePayload["hash"] = hash }
                }
                notifyEvent(type: "file-update", payload: filePayload)
                reloadWebView()
            case "full-reload":
                fallthrough
            default:
                notifyEvent(type: "full-reload")
                reloadWebView()
            }
        } else {
            notifyEvent(type: defaultType, message: text)
            reloadWebView()
        }
    }

    private func handleFailure(_ error: Error) {
        setConnected(false)
        notifyEvent(type: "error", message: error.localizedDescription)
        if !manualDisconnect {
            presentDisconnectedAlert(reason: error.localizedDescription)
            scheduleReconnect()
        }
    }

    // MARK: - UI Helpers

    private func reloadWebView() {
        guard let webView = bridge?.webView else { return }
        DispatchQueue.main.async {
            if self.usingLiveReload, let remote = self.configuration.url {
                webView.load(URLRequest(url: remote))
            } else {
                webView.reload()
            }
        }
    }

    private func switchToLiveReloadContent() {
        guard let remote = configuration.url, let webView = bridge?.webView else { return }
        DispatchQueue.main.async {
            if self.initialURL == nil {
                self.initialURL = webView.url
            }
            if self.usingLiveReload {
                webView.reload()
            } else {
                self.usingLiveReload = true
                webView.load(URLRequest(url: remote))
            }
        }
    }

    private func restoreOriginalContent() {
        guard let webView = bridge?.webView else { return }
        DispatchQueue.main.async {
            self.usingLiveReload = false
            if let original = self.initialURL {
                webView.load(URLRequest(url: original))
            } else {
                webView.reload()
            }
        }
    }

    private func captureInitialURL() {
        guard initialURL == nil else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.initialURL == nil else { return }
            self.initialURL = self.bridge?.webView?.url
        }
    }

    private func presentDisconnectedAlert(reason: String?) {
        guard !manualDisconnect, disconnectAlert == nil, let controller = bridge?.viewController else { return }
        let message: String = {
            var lines = ["The connection to the live reload server was lost."]
            if let reason = reason, !reason.isEmpty {
                lines.append("\nDetails: \(reason)")
            }
            lines.append("\nChoose Close to restore the original bundle or Reload to retry the connection.")
            return lines.joined()
        }()

        DispatchQueue.main.async {
            if self.disconnectAlert != nil { return }
            let alert = UIAlertController(title: "Live Reload Disconnected", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Close", style: .destructive, handler: { _ in
                self.manualDisconnect = true
                self.dismissDisconnectedAlert()
                self.closeSocket()
                self.restoreOriginalContent()
            }))
            alert.addAction(UIAlertAction(title: "Reload", style: .default, handler: { _ in
                self.manualDisconnect = false
                self.dismissDisconnectedAlert()
                self.reloadWebView()
                self.openSocket()
            }))
            alert.preferredAction = alert.actions.last
            controller.present(alert, animated: true)
            self.disconnectAlert = alert
        }
    }

    private func dismissDisconnectedAlert() {
        DispatchQueue.main.async {
            if let alert = self.disconnectAlert {
                alert.dismiss(animated: true)
                self.disconnectAlert = nil
            }
        }
    }

    private func scheduleReconnect() {
        guard configuration.autoReconnect, !manualDisconnect, reconnectWorkItem == nil else { return }
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.reconnectWorkItem = nil
            if !self.status.connected && !self.manualDisconnect {
                self.openSocket()
            }
        }
        reconnectWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + configuration.reconnectInterval, execute: workItem)
    }

    private func setConnected(_ value: Bool) {
        guard status.connected != value else { return }
        status.connected = value
        if value {
            dismissDisconnectedAlert()
            switchToLiveReloadContent()
        }
        notifyStatus()
    }

    private func notifyStatus() {
        notifyListeners("statusChange", data: status.toResult())
    }

    private func notifyEvent(type: String, payload: [String: Any]? = nil, message: String? = nil) {
        var event: [String: Any] = ["type": type]
        if let payload { event["file"] = payload }
        if let message { event["message"] = message }
        notifyListeners("reloadEvent", data: event)
    }

    @objc func getPluginVersion(_ call: CAPPluginCall) {
        call.resolve(["version": self.PLUGIN_VERSION])
    }
}

// MARK: - URLSessionWebSocketDelegate

extension LiveReloadPlugin: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        setConnected(true)
        notifyEvent(type: "connected", message: "connected")
    }

    public func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        setConnected(false)
        let message = reason.flatMap { String(data: $0, encoding: .utf8) }
        notifyEvent(type: "disconnected", message: message)
        if !manualDisconnect {
            presentDisconnectedAlert(reason: message)
            scheduleReconnect()
        }
    }
}

// MARK: - Helpers

struct LiveReloadStatus {
    var connected: Bool
    var url: String?

    func toResult() -> [String: Any] {
        var result: [String: Any] = ["connected": connected]
        if let url { result["url"] = url }
        return result
    }
}

struct LiveReloadConfiguration {
    var url: URL?
    var websocketPath: String = "/ws"
    var headers: [String: String] = [:]
    var autoReconnect: Bool = true
    var reconnectInterval: TimeInterval = 2

    var websocketURL: URL? {
        guard let url else { return nil }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        switch components?.scheme?.lowercased() {
        case "https":
            components?.scheme = "wss"
        case "http":
            components?.scheme = "ws"
        default:
            break
        }
        if !websocketPath.isEmpty {
            let encoded = websocketPath.hasPrefix("/") ? websocketPath : "/" + websocketPath
            components?.percentEncodedPath = encoded.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? encoded
        }
        return components?.url
    }
}

private extension String {
    var jsonObject: [String: Any]? {
        guard let data = data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
