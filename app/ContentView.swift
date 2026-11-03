import AppKit
import SwiftUI

struct ContentView: View {
    @Bindable var store: TweakStore
    @State private var selection: TweakPage? = .general
    @State private var query = ""
    /// The setting under the pointer, shown in the page's preview.
    @State private var highlight: String?

    init(store: TweakStore, page: TweakPage = .general) {
        self.store = store
        _selection = State(initialValue: page)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            let page = selection ?? .general
            detail(for: page)
                .formStyle(.grouped)
                .navigationTitle(page.title)
                .id(page)
        }
        .searchable(text: $query, placement: .sidebar, prompt: "Search")
        .onChange(of: selection) { highlight = nil }
        .onChange(of: store.settings) { store.settingsChanged() }
        .onChange(of: store.customCSS) { store.settingsChanged() }
        .onChange(of: store.websitesCSS) { store.settingsChanged() }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(TweakPage.Group.allCases, id: \.self) { group in
                let pages = TweakPage.allCases.filter { $0.group == group && $0.matches(query) }
                if !pages.isEmpty {
                    Section(group.rawValue) {
                        ForEach(pages) { page in
                            Label {
                                Text(page.title)
                            } icon: {
                                IconTile(symbol: page.symbol, color: page.color, size: 20)
                            }
                            .tag(page)
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) { connectionStatus }
    }

    private var connectionStatus: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(store.bridge.isConnected ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)
            Text(store.bridge.isConnected ? "Connected" : "Not connected")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button(store.bridge.isRelaunching ? "Relaunching…" : "Relaunch") {
                Task { await store.relaunchAside() }
            }
            .controlSize(.small)
            .disabled(store.bridge.isRelaunching)
            .help("Relaunch Aside with native tweaks. Its tabs are restored.")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: Pages

    @ViewBuilder
    private func detail(for page: TweakPage) -> some View {
        Form {
            PageHero(page: page, highlight: highlight)
            notices(for: page)
            switch page {
            case .general: generalPage
            case .toolbar: toolbarPage
            case .sidebar: sidebarPage
            case .appearance: appearancePage
            case .newTab: newTabPage
            case .customCSS: customCSSPage
            case .files: filesPage
            case .websites: websitesPage
            }
        }
    }

    @ViewBuilder
    private func notices(for page: TweakPage) -> some View {
        if let errorMessage = store.errorMessage {
            Section {
                RowLabel(title: "Something went wrong", subtitle: errorMessage,
                         symbol: "exclamationmark.triangle.fill", color: .red)
                    .textSelection(.enabled)
            }
        }
        if page != .general && !store.isEnabled {
            Section {
                NoticeRow(title: "Tweaks are off", subtitle: "Turn them on to apply these settings to Aside.",
                          symbol: "power", color: .gray, actionTitle: "Turn On") {
                    Task { await store.setEnabled(true) }
                }
            }
        } else if page.group == .window && !store.bridge.isConnected {
            Section {
                NoticeRow(title: "Aside's window isn't connected",
                          subtitle: "These only work when Aside is opened from this app. Its tabs are restored.",
                          actionTitle: store.bridge.isRelaunching ? "Relaunching…" : "Relaunch Aside") {
                    Task { await store.relaunchAside() }
                }
                .disabled(store.bridge.isRelaunching)
            }
        }
    }

    @ViewBuilder
    private var generalPage: some View {
        Section {
            Toggle(isOn: enabledBinding) {
                RowLabel(title: "Tweaks on", subtitle: statusText, symbol: "power", color: .green)
            }
            .previews(Feature.enabled, in: $highlight)
            Toggle(isOn: autoApplyBinding) {
                RowLabel(title: "Keep after Aside updates",
                         subtitle: "Aside updates its UI often. This puts your tweaks back each time.",
                         symbol: "arrow.triangle.2.circlepath", color: .blue)
            }
            .disabled(!store.isEnabled)
        }

        Section {
            LabeledContent {
                Button(store.bridge.isRelaunching ? "Relaunching…" : "Relaunch Aside") {
                    Task { await store.relaunchAside() }
                }
                .disabled(store.bridge.isRelaunching)
            } label: {
                RowLabel(
                    title: store.bridge.isConnected ? "Native tweaks connected" : "Native tweaks not connected",
                    subtitle: store.bridge.isConnected
                        ? "Toolbar and sidebar changes apply to every Aside window. Keep this app running, including in the menu bar."
                        : "Toolbar and sidebar tweaks only work when Aside is opened from here. Its tabs are restored.",
                    symbol: "bolt.horizontal.fill",
                    color: store.bridge.isConnected ? .green : .gray
                )
            }
            if let error = store.bridge.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Aside Window")
        } footer: {
            Text("Relaunching turns on Chromium's native UI inspector. While Aside runs that way without this app connected, a website or app could connect to it and read tab titles and addresses. Quit Aside before quitting this app.")
        }

        Section {
            LabeledContent {
                Button("Reset") { store.resetSettings() }
            } label: {
                RowLabel(title: "Reset controls to default",
                         subtitle: "Resets the sliders and switches. Your CSS and tweak files stay as they are.",
                         symbol: "arrow.counterclockwise", color: .gray)
            }
        }
    }

    @ViewBuilder
    private var toolbarPage: some View {
        Section("Hide") {
            nativeToggles(group: .toolbar, experimental: false)
        }
    }

    @ViewBuilder
    private var sidebarPage: some View {
        Section("Hide") {
            nativeToggles(group: .sidebar, experimental: false)
        }

        Section {
            Picker(selection: $store.settings.sidebarAnimation) {
                ForEach(SidebarAnimation.allCases) { animation in
                    Text(animation.label).tag(animation)
                }
            } label: {
                RowLabel(title: "Sidebar animation", subtitle: sidebarAnimationNote,
                         symbol: "wand.and.stars", color: .purple)
            }
            .previews(Feature.sidebarAnimation, in: $highlight)
            if store.sidebarAnimationNeedsRelaunch {
                NoticeRow(title: "Relaunch to apply", subtitle: "Aside reads this setting when it opens.",
                          symbol: "arrow.clockwise", color: .blue,
                          actionTitle: store.bridge.isRelaunching ? "Relaunching…" : "Relaunch Aside") {
                    Task { await store.relaunchAside() }
                }
                .disabled(store.bridge.isRelaunching)
            }
        } header: {
            Text("Animation")
        }

        Section {
            nativeToggles(group: .sidebar, experimental: true)
        } header: {
            Text("Experimental")
        } footer: {
            Text("Aside can put these back when it lays out the window, so the edge may flicker.")
        }
    }

    @ViewBuilder
    private var appearancePage: some View {
        Section {
            SettingSlider(title: "Corner roundness", symbol: "square.on.square.dashed", color: .pink,
                          value: $store.settings.roundness, range: 0...3, step: 0.1) {
                $0 == TweakSettings.defaultRoundness ? "Default" : $0.formatted(.number.precision(.fractionLength(1)))
            }
            .previews(Feature.roundness, in: $highlight)
            SettingSlider(title: "Text size", symbol: "textformat.size", color: .orange,
                          value: $store.settings.textSize, range: 80...130, step: 5) {
                "\(Int($0))%"
            }
            .previews(Feature.textSize, in: $highlight)
            SettingSlider(title: "Background opacity", symbol: "circle.lefthalf.filled", color: .indigo,
                          value: $store.settings.backgroundOpacity, range: 0...100, step: 5) {
                "\(Int($0))%"
            }
            .previews(Feature.backgroundOpacity, in: $highlight)
        }

        Section {
            Picker(selection: $store.settings.font) {
                ForEach(TweakFont.allCases) { font in
                    Text(font.label).tag(font)
                }
            } label: {
                RowLabel(title: "Font", symbol: "textformat", color: .blue)
            }
            .previews(Feature.font, in: $highlight)
            Picker(selection: $store.settings.animationMode) {
                ForEach(TweakAnimation.allCases) { animation in
                    Text(animation.label).tag(animation)
                }
            } label: {
                RowLabel(title: "Animations", subtitle: "On Aside's pages only. Native window animations aren't affected.",
                         symbol: "hare", color: .green)
            }
            .previews(Feature.animationMode, in: $highlight)
        }
    }

    @ViewBuilder
    private var newTabPage: some View {
        Section {
            Toggle(isOn: $store.settings.hideNewTabContent) {
                RowLabel(title: "Hide chats and suggestions",
                         subtitle: "Leaves just the greeting and the chat box.",
                         symbol: "eye.slash", color: .orange)
            }
            .previews(Feature.hideNewTabContent, in: $highlight)
        }
    }

    @ViewBuilder
    private var customCSSPage: some View {
        Section {
            cssEditor($store.customCSS, label: "Custom CSS")
        } header: {
            Text("CSS")
        } footer: {
            Text("To find selectors, open chrome-extension://fjdhphbdlfjogobdofoaagnlnkoibdge/newtab.html in Aside and press Command-Option-I. The other pages are sidepanel.html and main.html.")
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var websitesPage: some View {
        Section {
            cssEditor($store.websitesCSS, label: "CSS for all websites")
        } header: {
            Text("CSS")
        } footer: {
            Text("The first time you add CSS here, relaunch Aside. After that, reload a page to see changes.")
        }
    }

    @ViewBuilder
    private var filesPage: some View {
        Section {
            if store.files.isEmpty {
                Text("No tweak files yet. Add .css files to the tweaks folder.")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.files) { file in
                Toggle(isOn: fileBinding(file)) {
                    RowLabel(title: file.name, subtitle: file.url.lastPathComponent, symbol: "doc.text.fill", color: .brown)
                }
            }
        } header: {
            Text("Files")
        } footer: {
            Text("A file is turned off by renaming it to end in .off.")
        }

        Section {
            LabeledContent {
                Button("Open") { NSWorkspace.shared.open(store.tweaksFolder) }
            } label: {
                RowLabel(title: "Tweaks folder", subtitle: store.tweaksFolder.path(percentEncoded: false),
                         symbol: "folder", color: .blue)
            }
        }
    }

    // MARK: Pieces

    private func cssEditor(_ text: Binding<String>, label: String) -> some View {
        TextEditor(text: text)
            .font(.system(.body, design: .monospaced))
            .autocorrectionDisabled()
            .scrollContentBackground(.hidden)
            .frame(minHeight: 240)
            .accessibilityLabel(label)
    }

    private func nativeToggles(group: NativeRule.Group, experimental: Bool) -> some View {
        ForEach(NativeRule.all.filter { $0.group == group && $0.isExperimental == experimental }) { rule in
            Toggle(isOn: nativeBinding(rule)) {
                RowLabel(title: rule.title, subtitle: rule.note, symbol: rule.symbol,
                         color: experimental ? .orange : (group == .toolbar ? .blue : .indigo))
            }
            // Only the switch is disabled, so the preview still works before Aside is connected.
            .disabled(nativeDisabled)
            .previews(rule.id, in: $highlight)
        }
    }

    private var nativeDisabled: Bool {
        !store.bridge.isConnected || !store.isEnabled
    }

    private var sidebarAnimationNote: String {
        switch store.settings.sidebarAnimation {
        case .standard: "Aside's own slide. The page resizes on every frame."
        case .off: "Removes the slide for Cmd+S, the button and hover, and Aside's other native window animations. Only when Aside is opened from here."
        default: "Slides the sidebar over the page, which resizes once. Stays on however you open Aside."
        }
    }

    private func nativeBinding(_ rule: NativeRule) -> Binding<Bool> {
        Binding {
            store.settings.nativeHidden.contains(rule.id)
        } set: { isOn in
            if isOn {
                store.settings.nativeHidden.insert(rule.id)
            } else {
                store.settings.nativeHidden.remove(rule.id)
            }
        }
    }

    private var statusText: String {
        guard let version = store.version else { return "Aside's UI wasn't found" }
        return store.isEnabled ? "Applied to Aside UI \(version)" : "Aside UI \(version) is unchanged"
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { store.isEnabled }, set: { isOn in Task { await store.setEnabled(isOn) } })
    }

    private var autoApplyBinding: Binding<Bool> {
        Binding(get: { store.autoApply }, set: { isOn in Task { await store.setAutoApply(isOn) } })
    }

    private func fileBinding(_ file: TweakFile) -> Binding<Bool> {
        Binding(get: { file.isEnabled }, set: { isOn in Task { await store.setFile(file, enabled: isOn) } })
    }
}
