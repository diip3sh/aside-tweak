# aside-tweak

Personal tweaks for the Aside browser. Unofficial. It doesn't modify or re-sign `Aside.app`, so keychain access, passkeys and sign-in are unaffected.

## The app

Open **Aside Tweak.app** in this folder and switch on **Tweaks on** in General. It has to stay in this folder, because it uses the `aside-tweak` script and `tweaks/` folder beside it. To rebuild it, run `./build-app.sh`. macOS may ask for access to Documents after a rebuild.

The window is laid out like System Settings, with pages in a sidebar:

- **General:** Tweaks on, Keep after Aside updates, the window connection, and Reset.
- **Aside Window:** Toolbar and Sidebar.
- **Aside Pages:** Appearance, New Tab Page, Custom CSS and Tweak Files.
- **Every Website:** All Websites.

Search at the top of the sidebar finds a page by any setting on it. The bottom of the sidebar shows whether Aside's window is connected, with a **Relaunch** button.

Each page starts with a screenshot of Aside. Point at a setting, and the screenshot switches between Aside with it off and with it on. Pinned tabs, Sidebar animation, Background opacity and Animations have no screenshot: a fresh profile has no pinned tabs, opacity made no difference on the new tab page, and the other two are motion.

The screenshots are in `previews/`, and `build-app.sh` bundles them into the app. They were taken from Aside UI 1.26.1101, so an Aside update can make them out of date. They were captured in a second Aside profile, which the last section warns against. Retaking them needs another approach.

There are three kinds of tweak.

### Native window: toolbar and sidebar

Click **Relaunch Aside** first. These apply to every Aside window, and new windows are picked up within about 1.5 seconds. They only work when Aside was opened from this app, and the app has to keep running. Closing its window leaves it in the menu bar.

- **Toolbar:** hide the whole toolbar, Back and Forward, Reload, Split View, extensions, or Ask Aside.
- **Sidebar:** hide the sidebar button, New Chat, the Chats section, pinned tabs, or the profile button. Two experimental toggles try to straighten the edge beside the page: **Remove sidebar edge decoration** and **Square bottom page corner**.

**Sidebar animation** switches on Chromium's Side Panel Flyover flag, which exists to reduce this animation's jank: the sidebar slides over the page, and the page resizes once instead of on every frame. Pick Smooth or a fixed speed, then click **Relaunch Aside**. Unlike the other native tweaks, it's stored in Aside's own settings, so it stays on however you open Aside. Choosing Aside default and relaunching removes it.

**No animation**, in the same list, removes the slide for Cmd+S, the button and hover using Chromium's `animation-duration-scale` switch. There's no version for the sidebar alone, so it also removes Aside's other native window animations. Unlike the other choices, it only applies when Aside is opened from this app.

Aside can undo some of these when it lays out a window, or when you reveal the sidebar by hovering. The app puts them back. While Aside is the frontmost app, it checks hidden views about 12 times a second, so a view can flash back for a moment. Hide Chats section is the exception: Aside shows that section again on every hover, so the app hides only what's inside it. Nothing flashes, but the empty section leaves a 12 pt gap above your tabs. When another app is frontmost, that flash can last up to 1.5 seconds.

### Aside's web pages: new tab, side panel, chat

- **Appearance:** corner roundness, text size, background opacity, font and animation speed.
- **New tab page:** hide chats and suggestions.
- **Custom CSS** and **Tweak files:** your own rules. Files live in `tweaks/`.

Visible pages update within about a second. **Keep after Aside updates** puts these back after each Aside UI update.

### Every website

**CSS for All Websites** adds your rules to every site. The first time you add some, relaunch Aside. After that, reload a page to see changes.

## What it can't do

These are decided by Aside's C++ code, and the native inspector can't change them:

- **Removing the toolbar's space:** hiding the toolbar leaves an empty 42 pt strip above the page.
- **Hiding the whole sidebar:** Aside forces it back on. Aside's own Collapse Tabs (Command-S) still works.
- **Fully square corners (see the two experimental Sidebar toggles) and edge-to-edge content:** the page's `rounded_corner_radii` layer value can be written, but Aside put it back about 3.5 times a second in testing, so holding a new value would flicker. `RoundedCorners` rejects writes, and the corner views are forced back on.
- **Other native animations:** apart from the sidebar animation above, their timing isn't exposed, and curves can't be changed. The Animations control only affects Aside's web pages.
- **Sidebar width from this app:** the sidebar changes but the page doesn't move, so resize it by dragging in Aside.
- **Sidebar opacity and blur:** those properties exist only some of the time, so they aren't offered.

Getting these would take the DiaTweaks approach of a patched, re-signed app with C++ hooks. That loses the keychain groups and passkey entitlement tied to Aside's developer team, and the hooks would need redoing for each Aside build.

## Security

**Relaunch Aside** turns on Chromium's native UI inspector, on a random local port. The inspector doesn't check who connects, and a test connection claiming to come from a website was accepted. Anything that finds the port while it's free could read tab titles and addresses from the window, or change the window.

It takes one client at a time, so while this app is connected everyone else gets no reply. **Quit Aside before quitting this app.** To turn the inspector off, quit Aside and open it normally.

## The command line

The app runs this same script for web page and website tweaks. Native tweaks need the app.

| Command | What it does |
| --- | --- |
| `./aside-tweak apply` | Apply the controls and everything in `tweaks/*.css` |
| `./aside-tweak restore` | Remove all web page and website tweaks |
| `./aside-tweak status` | Show what's applied |
| `./aside-tweak sidebar-animation default\|smooth\|250\|300\|350` | Set the sidebar animation while Aside is closed |
| `./aside-tweak autoapply on` | Re-apply automatically when Aside updates its UI |
| `./aside-tweak autoapply off` | Stop doing that |

Auto-apply runs from a copy in `~/Library/Application Support/aside-tweak`, because macOS blocks background jobs from reading `~/Documents`. Running `apply` updates that copy.

## Known issues

- **Turning off a hide setting can show a view Aside had hidden.** Switching a native tweak off sets the view back to visible, even if Aside had hidden it itself. Turning off **Hide Split View** made the Split View button appear where Aside normally hides it.
- **Square bottom page corner barely changes anything** in Aside UI 1.26.1101. The corner stays almost as round.

## Finding what to style

Open `chrome-extension://fjdhphbdlfjogobdofoaagnlnkoibdge/newtab.html` in a tab and press Cmd+Option+I to inspect it. The other pages are `sidepanel.html` and `main.html`. Much of the styling uses Tailwind classes, and an update can rename them, so a selector may need fixing after an update.

To add a native tweak, add a rule to `app/NativeRule.swift` and rebuild. Rules target Chromium view class names such as `ReloadButton`, and an Aside update can rename those too.

If you script the inspector yourself, never call `CSS.getMatchedStylesForNode` on the root element, the unnamed top node of `DOM.getDocument`. It crashed Aside both times it was tried.

## How it works

- **Web pages:** `apply` writes `assets/aside-tweak.css` and `assets/aside-tweak-live.js` into each version in `~/Library/Application Support/Aside/AsideAgentManager/`, then adds two lines marked `data-aside-tweak` to its HTML pages.
- **Websites:** `apply` also adds one stylesheet entry to that version's `manifest.json`, keeping the original beside it as `manifest.json.aside-tweak-orig`.
- **Native window:** the app connects to the inspector and sets properties like `Visible` on Chromium's views. It reads the whole view tree every 1.5 seconds, and sooner when its quick check sees a change. Nothing is saved inside Aside, so a normal relaunch resets the window.
- **Sidebar animation:** with Aside closed, the script edits `browser.enabled_labs_experiments` in Aside's `Local State`, the same setting `chrome://flags` uses.
- **Removing tweaks:** `restore` removes the web page and website changes. Switching a native tweak off puts the old value back.
- **Password manager:** `AsidePasswordManager` is never touched.

## Don't run a second Aside profile for testing

Launching Aside with `--user-data-dir` isn't isolated. Aside runs one daemon on port 21420, so a second instance takes it over from your main browser and registers itself as an extra account in `~/.aside/accounts.json`.

The idea comes from [DiaTweaks](https://github.com/JaceThings/DiaTweaks), but no code is copied from it. That repo has no license file.
