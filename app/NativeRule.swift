import Foundation

/// One change to Aside's native window, described by the view classes it targets.
struct NativeRule: Identifiable, Hashable {
    enum Group: String, CaseIterable {
        case toolbar = "Toolbar"
        case sidebar = "Sidebar"
    }

    struct Target: Hashable {
        let className: String
        /// Only views whose tooltip contains this text. Needed where one class is used for several buttons.
        var tooltip: String?
        /// How many levels above the match to apply the change. A parent can stay hidden when the view itself can't.
        var levelsUp = 0
        /// Only views directly inside this class. Needed where hidden copies of a class exist elsewhere.
        var parentClass: String?
        /// Apply to the view's direct children instead of the view. Aside shows a section again each time the sidebar is
        /// revealed but leaves what's inside it alone, so hiding only the contents gives Aside nothing to undo.
        var appliesToChildren = false
    }

    let id: String
    let title: String
    let group: Group
    let targets: [Target]
    var property = "Visible"
    var value = "false"
    var restoreValue = "true"
    var note: String?
    var symbol = "eye.slash"
    var isExperimental = false

    static let all: [NativeRule] = [
        NativeRule(id: "toolbar", title: "Hide entire toolbar", group: .toolbar,
                   targets: [Target(className: "ToolbarView", parentClass: "TopContainerView")],
                   note: "Leaves an empty 42 pt strip above the page, and hides the address bar.",
                   symbol: "menubar.rectangle"),
        NativeRule(id: "backForward", title: "Hide Back and Forward", group: .toolbar,
                   targets: [Target(className: "BackForwardButton")],
                   symbol: "arrow.left.arrow.right"),
        NativeRule(id: "reload", title: "Hide Reload", group: .toolbar,
                   targets: [Target(className: "ReloadButton")],
                   symbol: "arrow.clockwise"),
        NativeRule(id: "split", title: "Hide Split View", group: .toolbar,
                   targets: [Target(className: "SplitTabsToolbarButton")],
                   symbol: "rectangle.split.2x1"),
        NativeRule(id: "extensions", title: "Hide extensions", group: .toolbar,
                   targets: [Target(className: "ExtensionsToolbarDesktop"),
                             Target(className: "ToolbarButton", tooltip: "Extensions")],
                   symbol: "puzzlepiece.extension"),
        NativeRule(id: "persistentAction", title: "Hide Ask Aside button", group: .toolbar,
                   targets: [Target(className: "ToolbarPersistentActionContainer")],
                   symbol: "sparkles"),
        NativeRule(id: "collapse", title: "Hide sidebar button", group: .sidebar,
                   targets: [Target(className: "TopContainerButton")],
                   property: "Width", value: "0", restoreValue: "32",
                   symbol: "sidebar.left"),
        NativeRule(id: "newChat", title: "Hide New Chat button", group: .sidebar,
                   targets: [Target(className: "AsideNewChatTabButtonContainer")],
                   symbol: "square.and.pencil"),
        NativeRule(id: "chats", title: "Hide Chats section", group: .sidebar,
                   targets: [Target(className: "AsideSectionHeaderButton", tooltip: "Chats", levelsUp: 1, appliesToChildren: true)],
                   note: "Leaves a 12 pt gap above your tabs.",
                   symbol: "bubble.left.and.bubble.right"),
        NativeRule(id: "pinned", title: "Hide pinned tabs", group: .sidebar,
                   targets: [Target(className: "VerticalPinnedTabEntriesView")],
                   symbol: "pin.fill"),
        NativeRule(id: "profile", title: "Hide profile button", group: .sidebar,
                   targets: [Target(className: "VerticalTabSidebarProfileButton")],
                   symbol: "person.crop.circle"),
        NativeRule(id: "squareEdge", title: "Remove sidebar edge decoration", group: .sidebar,
                   targets: [Target(className: "VerticalTabStripAdjacentPaneDecorationView")],
                   property: "opacity", value: "0", restoreValue: "1",
                   note: "Fades the view drawn where the sidebar meets the page.",
                   symbol: "square.dashed", isExperimental: true),
        NativeRule(id: "squarePage", title: "Square bottom page corner", group: .sidebar,
                   targets: [Target(className: "ContentsWebView")],
                   property: "rounded_corner_radii", value: "0,0,0,0", restoreValue: "0,0,0,16",
                   note: "Aside can round it again, so it may flicker. Turning it off may need Relaunch Aside.",
                   symbol: "square", isExperimental: true),
    ]
}
