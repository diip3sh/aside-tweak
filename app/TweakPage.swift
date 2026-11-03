import SwiftUI

/// A category in the window's sidebar.
enum TweakPage: String, CaseIterable, Identifiable, Hashable {
    case general, toolbar, sidebar, appearance, newTab, customCSS, files, websites

    enum Group: String, CaseIterable {
        case main = ""
        case window = "Aside Window"
        case pages = "Aside Pages"
        case web = "Every Website"
    }

    var id: String { rawValue }

    var group: Group {
        switch self {
        case .general: .main
        case .toolbar, .sidebar: .window
        case .appearance, .newTab, .customCSS, .files: .pages
        case .websites: .web
        }
    }

    var title: String {
        switch self {
        case .general: "General"
        case .toolbar: "Toolbar"
        case .sidebar: "Sidebar"
        case .appearance: "Appearance"
        case .newTab: "New Tab Page"
        case .customCSS: "Custom CSS"
        case .files: "Tweak Files"
        case .websites: "All Websites"
        }
    }

    var symbol: String {
        switch self {
        case .general: "switch.2"
        case .toolbar: "menubar.rectangle"
        case .sidebar: "sidebar.left"
        case .appearance: "paintpalette.fill"
        case .newTab: "square.grid.2x2.fill"
        case .customCSS: "curlybraces"
        case .files: "doc.text.fill"
        case .websites: "globe"
        }
    }

    var color: Color {
        switch self {
        case .general: .gray
        case .toolbar: .blue
        case .sidebar: .indigo
        case .appearance: .pink
        case .newTab: .orange
        case .customCSS: .teal
        case .files: .brown
        case .websites: .green
        }
    }

    var summary: String {
        switch self {
        case .general: "Turn tweaks on, connect to Aside's window, and keep your changes after Aside updates."
        case .toolbar: "Hide buttons above the page. Applies to every Aside window."
        case .sidebar: "Hide parts of the sidebar and change how it slides in and out."
        case .appearance: "Corners, text, background and font on Aside's new tab page, side panel and chat."
        case .newTab: "Choose what Aside's new tab page shows."
        case .customCSS: "Your own CSS for Aside's new tab page, side panel and chat."
        case .files: "Stylesheets in the tweaks folder. Turn each one on or off."
        case .websites: "CSS added to every website you open in Aside."
        }
    }

    /// The screenshot shown when no setting is pointed at.
    var overview: String {
        switch self {
        case .general: "page-general"
        case .toolbar: "page-toolbar"
        case .sidebar: "page-sidebar"
        case .appearance, .newTab, .customCSS, .files: "page-asidePages"
        case .websites: "page-websites"
        }
    }

    private var rowTitles: [String] {
        switch self {
        case .general: ["Tweaks on", "Keep after Aside updates", "Relaunch Aside", "Reset"]
        case .toolbar: NativeRule.all.filter { $0.group == .toolbar }.map(\.title)
        case .sidebar: NativeRule.all.filter { $0.group == .sidebar }.map(\.title) + ["Sidebar animation"]
        case .appearance: ["Corner roundness", "Text size", "Background opacity", "Font", "Animations"]
        case .newTab: ["Hide chats and suggestions"]
        case .customCSS: ["CSS", "selectors"]
        case .files: ["Open Tweaks Folder", "stylesheet"]
        case .websites: ["CSS", "sites"]
        }
    }

    func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return ([title, summary] + rowTitles).contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

/// Ids for previewable settings that aren't native rules.
enum Feature {
    static let enabled = "enabled"
    static let sidebarAnimation = "sidebarAnimation"
    static let roundness = "roundness"
    static let textSize = "textSize"
    static let backgroundOpacity = "backgroundOpacity"
    static let font = "font"
    static let animationMode = "animationMode"
    static let hideNewTabContent = "hideNewTabContent"

    static func title(_ id: String) -> String? {
        if let rule = NativeRule.all.first(where: { $0.id == id }) { return rule.title }
        return [
            enabled: "Tweaks on",
            sidebarAnimation: "Sidebar animation",
            roundness: "Corner roundness",
            textSize: "Text size",
            backgroundOpacity: "Background opacity",
            font: "Font",
            animationMode: "Animations",
            hideNewTabContent: "Hide chats and suggestions",
        ][id]
    }
}
