import AppKit
import CoreGraphics
import Foundation
import Observation
import os

/// Applies `NativeRule`s through Chromium's native UI inspector, without modifying Aside.
/// Aside can undo a change when it lays out its window, so rules are re-applied every 1.5 seconds, and straight away
/// when a quick check sees a hidden view change.
private let log = Logger(subsystem: "local.aside-tweak", category: "native")

@MainActor
@Observable
final class NativeBridge {
    /// The inspector checks nothing about who connects and takes one client at a time, so staying connected
    /// keeps others out. A random port also means a web page can't simply try a well-known one.
    static let port: Int = {
        let key = "inspectorPort"
        let saved = UserDefaults.standard.integer(forKey: key)
        if saved != 0 { return saved }
        let chosen = Int.random(in: 20000...60000)
        UserDefaults.standard.set(chosen, forKey: key)
        return chosen
    }()
    static let asideBundleID = "at.studio.AsideBrowser"
    private static let asideURL = URL(fileURLWithPath: "/Applications/Aside.app")

    private(set) var isConnected = false
    private(set) var isRelaunching = false
    private(set) var lastError: String?

    private var rules: [NativeRule] = []
    private var socket: URLSessionWebSocketTask?
    private var nextID = 0
    private var pending: [Int: CheckedContinuation<JSONBox?, Never>] = [:]
    /// Rules in effect in Aside. View ids aren't kept for undoing, because the inspector renumbers views when the sidebar
    /// is revealed by hovering, and an old id can then belong to a different view.
    private var appliedRuleIDs: Set<String> = []
    private var watches: [Watch] = []
    private let shouldWatch: @MainActor () -> Bool
    private var isSyncing = false
    private var knownWindowCount = 0
    private var needsSync = false
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    init(shouldWatch: @escaping @MainActor () -> Bool = {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier == NativeBridge.asideBundleID
    }) {
        self.shouldWatch = shouldWatch
        Task { await keepConnected() }
        Task { await watchForChanges() }
    }

    func setRules(_ rules: [NativeRule]) {
        self.rules = rules
        Task { await sync() }
    }

    /// Quits Aside and reopens it behind the current app, with the inspector on and the last session restored.
    func relaunchAside(arguments: [String] = [], whileClosed: () async -> Void = {}) async {
        isRelaunching = true
        defer { isRelaunching = false }
        lastError = nil
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: Self.asideBundleID)
        running.forEach { $0.terminate() }
        for _ in 0..<80 where running.contains(where: { !$0.isTerminated }) {
            try? await Task.sleep(for: .milliseconds(250))
        }
        guard running.allSatisfy(\.isTerminated) else {
            lastError = "Aside didn't quit. Close any open dialogs in Aside and try again."
            return
        }
        await whileClosed()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["--enable-ui-devtools=\(Self.port)", "--restore-last-session"] + arguments
        configuration.createsNewApplicationInstance = false
        configuration.activates = false
        // macOS can refuse to open an app for a moment after it has quit.
        for attempt in 1...8 {
            do {
                _ = try await NSWorkspace.shared.openApplication(at: Self.asideURL, configuration: configuration)
                lastError = nil
                return
            } catch {
                lastError = error.localizedDescription
                log.notice("open attempt \(attempt) failed: \(error.localizedDescription, privacy: .public)")
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    // MARK: - Connection

    private func keepConnected() async {
        while !Task.isCancelled {
            if isConnected {
                // Reading the tree makes the inspector send DOM events, so reacting to those would loop forever.
                await sync()
            } else {
                await connect()
            }
            try? await Task.sleep(for: .seconds(isConnected ? 1.5 : 2))
        }
    }

    /// Reading a few properties takes under a millisecond, against about 40 for the whole tree. Nothing is written from
    /// here, because an id may have moved to another view: any difference just asks for a full sync.
    private func watchForChanges() async {
        var earliestSync = ContinuousClock.now
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(80))
            guard isConnected, !isSyncing, !watches.isEmpty, shouldWatch(), ContinuousClock.now >= earliestSync else { continue }
            for watch in watches {
                let current = await readProperties(nodeID: watch.nodeID)[watch.property]
                guard current.map({ same($0, watch.expected) }) != true else { continue }
                log.debug("watch #\(watch.nodeID) \(watch.property, privacy: .public) changed")
                earliestSync = ContinuousClock.now + .milliseconds(200)
                await sync()
                break
            }
        }
    }

    private func connect() async {
        guard let url = URL(string: "ws://127.0.0.1:\(Self.port)/0") else { return }
        let task = session.webSocketTask(with: url)
        task.maximumMessageSize = 32 * 1024 * 1024
        socket = task
        task.resume()
        Task { await receive(on: task) }
        guard await call("DOM.getDocument") != nil else {
            disconnect()
            return
        }
        isConnected = true
        knownWindowCount = 0
        appliedRuleIDs = savedAppliedRuleIDs()
        await sync()
    }

    private func disconnect() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        isConnected = false
        watches = []
        pending.values.forEach { $0.resume(returning: nil) }
        pending.removeAll()
    }

    private func receive(on task: URLSessionWebSocketTask) async {
        while task === socket {
            guard let message = try? await task.receive() else {
                if task === socket { disconnect() }
                return
            }
            let data: Data?
            switch message {
            case .string(let text): data = Data(text.utf8)
            case .data(let bytes): data = bytes
            @unknown default: data = nil
            }
            guard let data,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { continue }
            if let id = json["id"] as? Int, let waiting = pending.removeValue(forKey: id) {
                waiting.resume(returning: JSONBox(value: json))
            }
        }
    }

    private func call(_ method: String, _ params: [String: Any] = [:]) async -> [String: Any]? {
        guard let socket else { return nil }
        nextID += 1
        let id = nextID
        guard let body = try? JSONSerialization.data(withJSONObject: ["id": id, "method": method, "params": params]),
              let text = String(data: body, encoding: .utf8) else { return nil }
        let reply = await withCheckedContinuation { (continuation: CheckedContinuation<JSONBox?, Never>) in
            pending[id] = continuation
            socket.send(.string(text)) { _ in }
            Task {
                try? await Task.sleep(for: .seconds(4))
                self.pending.removeValue(forKey: id)?.resume(returning: nil)
            }
        }
        return reply?.value
    }

    // MARK: - Applying

    private func sync() async {
        guard isConnected else { return }
        needsSync = true
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        while needsSync {
            needsSync = false
            await syncOnce()
        }
    }

    /// An open connection isn't told about new windows, and turning the inspector's DOM off and on makes it look again.
    /// Only real browser windows count, because tooltips are windows too and open and close constantly.
    private func refreshIfWindowsChanged() async {
        let count = asideWindowCount
        guard count != knownWindowCount else { return }
        let isFirstLook = knownWindowCount == 0
        knownWindowCount = count
        guard !isFirstLook else { return }
        log.notice("window count changed to \(count), refreshing")
        _ = await call("DOM.disable")
        _ = await call("DOM.enable")
    }

    private var asideWindowCount: Int {
        let pid = asidePID
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        return windows.filter { window in
            guard (window[kCGWindowOwnerPID as String] as? Int) == pid, (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: bounds) else { return false }
            return frame.width >= 400 && frame.height >= 300
        }.count
    }

    private func syncOnce() async {
        await refreshIfWindowsChanged()
        guard let reply = await call("DOM.getDocument"),
              let result = reply["result"] as? [String: Any],
              let rootJSON = result["root"] as? [String: Any] else { return }
        let root = ViewNode(json: rootJSON, parent: nil)
        let nodes = root.flattened()
        log.debug("tick windows=\(self.knownWindowCount) browserViews=\(nodes.filter { $0.name == "BrowserView" }.count) views=\(nodes.count)")

        // Anything no longer wanted goes back to its normal value.
        let active = Set(rules.map(\.id))
        for rule in NativeRule.all where appliedRuleIDs.contains(rule.id) && !active.contains(rule.id) {
            for view in await views(for: rule, in: nodes) {
                guard let current = await readProperties(nodeID: view.id)[rule.property], same(current, rule.value) else { continue }
                let ok = await write(nodeID: view.id, property: rule.property, value: rule.restoreValue)
                log.notice("undo \(rule.id, privacy: .public) on \(view.name, privacy: .public) #\(view.id) ok=\(ok)")
            }
        }
        appliedRuleIDs = active
        rememberApplied()

        // Sidebar size isn't watched: that would add full tree reads during every slide, which could drop frames.
        var found: [Watch] = []
        for rule in rules {
            for view in await views(for: rule, in: nodes) where await apply(rule, to: view) {
                found.append(Watch(nodeID: view.id, property: rule.property, expected: rule.value))
            }
        }
        watches = found
    }

    private func views(for rule: NativeRule, in nodes: [ViewNode]) async -> [ViewNode] {
        var views: [ViewNode] = []
        for target in rule.targets {
            for node in nodes where node.name == target.className {
                guard let view = await resolve(node, for: target) else { continue }
                views += target.appliesToChildren ? view.children : [view]
            }
        }
        return views
    }

    /// If this app quit and reopened while Aside kept running, these rules are still in effect.
    private func savedAppliedRuleIDs() -> Set<String> {
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: "appliedPID") == asidePID else { return [] }
        return Set(defaults.stringArray(forKey: "appliedRules") ?? [])
    }

    private func rememberApplied() {
        let defaults = UserDefaults.standard
        defaults.set(asidePID, forKey: "appliedPID")
        defaults.set(rules.map(\.id), forKey: "appliedRules")
    }

    private var asidePID: Int {
        Int(NSRunningApplication.runningApplications(withBundleIdentifier: Self.asideBundleID).first?.processIdentifier ?? 0)
    }

    private func resolve(_ node: ViewNode, for target: NativeRule.Target) async -> ViewNode? {
        if let parentClass = target.parentClass, node.parent?.name != parentClass { return nil }
        if let tooltip = target.tooltip {
            let properties = await readProperties(nodeID: node.id)
            guard properties["TooltipText"]?.contains(tooltip) == true else { return nil }
        }
        var view: ViewNode? = node
        for _ in 0..<target.levelsUp { view = view?.parent }
        return view
    }

    /// Returns whether the view has this property, so it can be watched.
    private func apply(_ rule: NativeRule, to view: ViewNode) async -> Bool {
        guard let current = await readProperties(nodeID: view.id)[rule.property] else { return false }
        guard !same(current, rule.value) else { return true }
        let ok = await write(nodeID: view.id, property: rule.property, value: rule.value)
        log.notice("apply \(rule.id, privacy: .public) on \(view.name, privacy: .public) #\(view.id): \(current, privacy: .public) -> \(rule.value, privacy: .public) ok=\(ok)")
        return true
    }

    private func same(_ left: String, _ right: String) -> Bool {
        // Lists such as corner radii read back as "0.000000,0.000000,..." whatever format was written.
        let a = left.split(separator: ",").compactMap { Double($0) }
        let b = right.split(separator: ",").compactMap { Double($0) }
        if !a.isEmpty, a.count == b.count { return zip(a, b).allSatisfy { abs($0 - $1) < 0.001 } }
        return left == right
    }

    private func readProperties(nodeID: Int) async -> [String: String] {
        var properties: [String: String] = [:]
        for style in await styles(nodeID: nodeID) {
            for property in style["cssProperties"] as? [[String: Any]] ?? [] {
                if let name = property["name"] as? String, let value = property["value"] as? String {
                    properties[name] = value
                }
            }
        }
        return properties
    }

    private func styles(nodeID: Int) async -> [[String: Any]] {
        let reply = await call("CSS.getMatchedStylesForNode", ["nodeId": nodeID])
        let result = reply?["result"] as? [String: Any]
        let rules = result?["matchedCSSRules"] as? [[String: Any]] ?? []
        return rules.compactMap { ($0["rule"] as? [String: Any])?["style"] as? [String: Any] }
    }

    private func write(nodeID: Int, property: String, value: String) async -> Bool {
        let matching = await styles(nodeID: nodeID).first { style in
            (style["cssProperties"] as? [[String: Any]] ?? []).contains { $0["name"] as? String == property }
        }
        guard let matching, let sheet = matching["styleSheetId"], let range = matching["range"] else { return false }
        let edit: [String: Any] = ["styleSheetId": sheet, "range": range, "text": "\(property): \(value);"]
        let reply = await call("CSS.setStyleTexts", ["edits": [edit]])
        return reply?["error"] == nil
    }
}

private struct JSONBox: @unchecked Sendable {
    let value: [String: Any]
}

private struct Watch {
    let nodeID: Int
    let property: String
    let expected: String
}

@MainActor
private final class ViewNode {
    let id: Int
    let name: String
    private(set) weak var parent: ViewNode?
    private(set) var children: [ViewNode] = []

    init(json: [String: Any], parent: ViewNode?) {
        id = json["nodeId"] as? Int ?? -1
        let attributes = json["attributes"] as? [String] ?? []
        if let index = attributes.firstIndex(of: "name"), index + 1 < attributes.count {
            name = attributes[index + 1]
        } else {
            name = ""
        }
        self.parent = parent
        children = (json["children"] as? [[String: Any]] ?? []).map { ViewNode(json: $0, parent: self) }
    }

    func flattened() -> [ViewNode] {
        [self] + children.flatMap { $0.flattened() }
    }
}
