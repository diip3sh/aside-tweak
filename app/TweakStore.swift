import Foundation
import Observation

@MainActor
@Observable
final class TweakStore {
    var settings = TweakSettings()
    var customCSS = ""
    var websitesCSS = ""
    let bridge = NativeBridge()
    private(set) var files: [TweakFile] = []
    private(set) var isEnabled = false
    private(set) var autoApply = false
    private(set) var version: String?
    private(set) var errorMessage: String?
    private var appliedSidebarAnimation: SidebarAnimation {
        didSet { UserDefaults.standard.set(appliedSidebarAnimation.rawValue, forKey: "appliedSidebarAnimation") }
    }

    let tweaksFolder: URL
    private let settingsURL: URL
    private let customCSSURL: URL
    private let websitesCSSURL: URL
    private let engine: Engine
    private var isApplying = false
    private var needsApply = false
    private var pendingSave: Task<Void, Never>?

    init() {
        appliedSidebarAnimation = SidebarAnimation(rawValue: UserDefaults.standard.string(forKey: "appliedSidebarAnimation") ?? "") ?? .standard
        let root = Bundle.main.bundleURL.deletingLastPathComponent()
        tweaksFolder = root.appending(path: "tweaks")
        settingsURL = tweaksFolder.appending(path: "settings.json")
        customCSSURL = tweaksFolder.appending(path: "custom.css")
        websitesCSSURL = tweaksFolder.appending(path: "websites.css")
        engine = Engine(script: root.appending(path: "aside-tweak"))
        load()
        Task { await refreshStatus() }
    }

    /// Saves after a short pause, so dragging a slider doesn't start a run for every step.
    func settingsChanged() {
        pendingSave?.cancel()
        pendingSave = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            save()
            syncNative()
            await applyIfEnabled()
        }
    }

    func resetSettings() {
        settings = TweakSettings()
        settingsChanged()
    }

    func setEnabled(_ isOn: Bool) async {
        pendingSave?.cancel()
        save()
        do {
            if isOn {
                try await engine.apply()
            } else {
                // Auto-apply would bring the tweaks back at the next UI update.
                try await engine.setAutoApply(false)
                try await engine.restore()
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshStatus()
        syncNative()
    }

    /// Reopens Aside, saving the sidebar animation while it's closed. Turning tweaks off puts Aside's own back.
    func relaunchAside() async {
        pendingSave?.cancel()
        save()
        let choice = isEnabled ? settings.sidebarAnimation : .standard
        await bridge.relaunchAside(arguments: choice.launchArguments) {
            do {
                try await engine.setSidebarAnimation(choice.flagChoice)
                appliedSidebarAnimation = choice
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    var sidebarAnimationNeedsRelaunch: Bool {
        (isEnabled ? settings.sidebarAnimation : .standard) != appliedSidebarAnimation
    }

    func setAutoApply(_ isOn: Bool) async {
        do {
            try await engine.setAutoApply(isOn)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshStatus()
    }

    func setFile(_ file: TweakFile, enabled: Bool) async {
        let target = enabled ? file.url.deletingPathExtension() : file.url.appendingPathExtension("off")
        do {
            try FileManager.default.moveItem(at: file.url, to: target)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        loadFiles()
        await applyIfEnabled()
    }

    private func applyIfEnabled() async {
        guard isEnabled else { return }
        needsApply = true
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }
        while needsApply {
            needsApply = false
            do {
                try await engine.apply()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func refreshStatus() async {
        do {
            let status = try await engine.status()
            let current = status.versions.last
            version = current?.version
            isEnabled = current?.tweaked ?? false
            autoApply = status.autoApply
            syncNative()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncNative() {
        guard isEnabled else {
            bridge.setRules([])
            return
        }
        bridge.setRules(NativeRule.all.filter { settings.nativeHidden.contains($0.id) })
    }

    private func load() {
        if let data = try? Data(contentsOf: settingsURL),
           let saved = try? JSONDecoder().decode(TweakSettings.self, from: data) {
            settings = saved
        }
        customCSS = (try? String(contentsOf: customCSSURL, encoding: .utf8)) ?? ""
        websitesCSS = (try? String(contentsOf: websitesCSSURL, encoding: .utf8)) ?? ""
        loadFiles()
    }

    private func loadFiles() {
        let urls = (try? FileManager.default.contentsOfDirectory(at: tweaksFolder, includingPropertiesForKeys: nil)) ?? []
        files = urls
            .filter { ($0.pathExtension == "css" || $0.lastPathComponent.hasSuffix(".css.off")) && $0 != customCSSURL && $0 != websitesCSSURL }
            .map(TweakFile.init)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(settings).write(to: settingsURL, options: .atomic)
            try customCSS.write(to: customCSSURL, atomically: true, encoding: .utf8)
            try websitesCSS.write(to: websitesCSSURL, atomically: true, encoding: .utf8)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
