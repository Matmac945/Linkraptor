//
//  BrowserinoApp.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import SwiftUI
import Foundation
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var selectorWindow: LinkraptorWindow?
    private var preferencesWindow: NSWindow?

    @AppStorage("rules") private var rules: [Rule] = []
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true
    @AppStorage("browsers") private var browsers: [URL] = []
    @AppStorage("hiddenBrowsers") private var hiddenBrowsers: [URL] = []
    @AppStorage("chromeProfiles") private var chromeProfiles: [String: String] = [:]
    @AppStorage("primaryChromeProfile") private var primaryChromeProfile: String = ""

    // Checks GitHub Releases for new versions (feed URL and public key live
    // in Info.plist) and installs them; also checks daily in the background.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var statusMenu: NSMenu!
    var statusBarItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusBar()
        
        UserDefaults.standard.addObserver(self, forKeyPath: "showInMenuBar", options: [.new], context: nil)
        
        if UserDefaults.standard.object(forKey: "browsers") == nil {
            openPreferences()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        self.openPreferences()
        return true
    }
    
    func setupStatusBar() {
        if showInMenuBar {
            if statusBarItem == nil {
                statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                let statusButton = statusBarItem!.button
                statusButton!.image = NSImage.menuIcon

                statusMenu = NSMenu()
                statusMenu.delegate = self
                menuNeedsUpdate(statusMenu)

                statusBarItem!.menu = statusMenu!
            }
        } else {
            if statusBarItem != nil {
                NSStatusBar.system.removeStatusItem(statusBarItem!)
                statusBarItem = nil
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "showInMenuBar" {
            setupStatusBar()
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    deinit {
        UserDefaults.standard.removeObserver(self, forKeyPath: "showInMenuBar")
    }
    
    func application(_ application: NSApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        if userActivityType == NSUserActivityTypeBrowsingWeb {
            return true
        }
        
        return false
    }
    
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        if let url = userActivity.webpageURL {
            self.application(application, open: [url])
            return true
        }
        
        return false
    }
    
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // Rebuilt every time the menu opens so the clipboard state and
    // browser list are always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let openClipboard = NSMenuItem(
            title: "Open URL from Clipboard",
            action: URL.fromClipboard == nil ? nil : #selector(openClipboardURL),
            keyEquivalent: ""
        )
        openClipboard.target = self
        menu.addItem(openClipboard)
        menu.addItem(.separator())

        let visibleBrowsers = browsers.filter { !hiddenBrowsers.contains($0) }
        if !visibleBrowsers.isEmpty {
            menu.addItem(.sectionHeader(title: "Primary Browser"))

            for (index, browser) in visibleBrowsers.enumerated() {
                // Chrome's ticked profiles sit indented under it, like in the picker.
                let profiles = ChromeProfiles.isChrome(browser)
                    ? ChromeProfiles.shown(chromeProfiles) : []
                let primaryProfile = index == 0
                    ? profiles.first { $0.profile.directory == primaryChromeProfile } : nil

                let item = NSMenuItem(
                    title: browser.appDisplayName,
                    action: #selector(setPrimaryBrowser(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = browser
                item.state = index == 0 && primaryProfile == nil ? .on : .off

                let icon = browser.appIcon.copy() as! NSImage
                icon.size = NSSize(width: 18, height: 18)
                item.image = icon

                menu.addItem(item)

                for (profile, label) in profiles {
                    let profileItem = NSMenuItem(
                        title: label,
                        action: #selector(setPrimaryProfile(_:)),
                        keyEquivalent: ""
                    )
                    profileItem.target = self
                    profileItem.representedObject = profile.directory
                    profileItem.indentationLevel = 1
                    profileItem.state = profile.directory == primaryProfile?.profile.directory ? .on : .off

                    let avatar = profile.avatar.copy() as! NSImage
                    avatar.size = NSSize(width: 16, height: 16)
                    profileItem.image = avatar

                    menu.addItem(profileItem)
                }
            }

            menu.addItem(.separator())
        }

        let checkForUpdates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        checkForUpdates.target = updaterController
        menu.addItem(checkForUpdates)

        let preferences = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Linkraptor", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc func openClipboardURL() {
        guard let url = URL.fromClipboard else { return }
        application(NSApplication.shared, open: [url])
    }

    // The primary browser is simply the first one in the list: it shows first
    // in the picker and is highlighted, so Return opens it.
    @objc func setPrimaryBrowser(_ sender: NSMenuItem) {
        guard let browser = sender.representedObject as? URL else { return }
        primaryChromeProfile = ""
        moveToTop(browser)
    }

    // A profile as primary browser: Chrome moves to the top, and the picker
    // opens with that profile highlighted instead of plain Chrome.
    @objc func setPrimaryProfile(_ sender: NSMenuItem) {
        guard let directory = sender.representedObject as? String,
              let chrome = browsers.first(where: ChromeProfiles.isChrome)
        else { return }
        primaryChromeProfile = directory
        moveToTop(chrome)
    }

    private func moveToTop(_ browser: URL) {
        guard let index = browsers.firstIndex(of: browser) else { return }

        var reordered = browsers
        reordered.remove(at: index)
        reordered.insert(browser, at: 0)
        browsers = reordered
    }
    
    @objc func openPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
                styleMask: [.miniaturizable, .closable, .resizable, .titled],
                backing: .buffered,
                defer: false
            )
        }
        
        preferencesWindow!.center()
        preferencesWindow!.title = "Preferences"
        preferencesWindow!.contentView = NSHostingView(rootView: PreferencesView())
        
        preferencesWindow!.isReleasedWhenClosed = false
        preferencesWindow!.titlebarAppearsTransparent = true
        
        preferencesWindow!.contentMinSize = NSSize(width: 700, height: 500)
        
        preferencesWindow!.collectionBehavior = [.moveToActiveSpace, .fullScreenNone]
        
        NSApplication.shared.activate(ignoringOtherApps: true)
        
        preferencesWindow!.makeKeyAndOrderFront(nil)
        preferencesWindow!.orderFrontRegardless()
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        var processedUrls = urls
        
        if urls.count == 1 {
            let url = urls.first!
            
            if url.scheme == "linkraptor" && url.host == "open" {
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                   let queryItems = components.queryItems,
                   let encodedUrl = queryItems.first(where: { $0.name == "url" })?.value,
                   let decodedData = Data(base64Encoded: encodedUrl),
                   let decodedUrlString = String(data: decodedData, encoding: .utf8),
                   let decodedUrl = URL(string: decodedUrlString) {
                    processedUrls = [decodedUrl]
                } else {
                    return
                }
            }
            
            let urlString = processedUrls.first!.absoluteString

            for rule in rules {
                let regex = try? Regex(rule.regex).ignoresCase()
                
                if let regex, urlString.firstMatch(of: regex) != nil {
                    BrowserUtil.openURL(
                        processedUrls,
                        app: rule.app,
                        isIncognito: false
                    )
                    return
                }
            }
        }
        
        if selectorWindow == nil {
            selectorWindow = LinkraptorWindow()
        }

        // Liquid Glass panel that sizes itself to the list, like a native menu.
        let hostingView = NSHostingView(
            rootView: PromptView(
                urls: processedUrls
            )
        )
        let glass = NSGlassEffectView()
        glass.cornerRadius = LinkraptorWindow.cornerRadius
        glass.contentView = hostingView
        glass.autoresizingMask = [.width, .height]

        // The glass blur fills its whole rectangle and softens past the rounded
        // edge, which showed as a faint square. Clip it to the rounded shape.
        let clip = NSView()
        clip.wantsLayer = true
        clip.layer?.cornerRadius = LinkraptorWindow.cornerRadius
        clip.layer?.cornerCurve = .continuous
        clip.layer?.masksToBounds = true
        clip.addSubview(glass)

        selectorWindow!.contentView = clip
        selectorWindow!.setContentSize(hostingView.fittingSize)
        glass.frame = clip.bounds

        let screen = getScreenWithMouse()!.visibleFrame
        
        selectorWindow?.setFrameOrigin(
            NSPoint(
                x: clamp(
                    min: screen.minX + 20,
                    max: screen.maxX - selectorWindow!.frame.width - 20,
                    value: NSEvent.mouseLocation.x - selectorWindow!.frame.width / 2
                ),
                y: clamp(
                    min: screen.minY + 20,
                    max: screen.maxY - selectorWindow!.frame.height - 20,
                    value: NSEvent.mouseLocation.y - (selectorWindow!.frame.height - 30)
                )
            )
        )
        
        NSApplication.shared.activate(ignoringOtherApps: true)
        selectorWindow!.deactivateDelay()

        selectorWindow!.makeKeyAndOrderFront(nil)
        selectorWindow!.isReleasedWhenClosed = false
        selectorWindow!.delegate = self
    }
    
    func clamp(min: CGFloat, max: CGFloat, value: CGFloat) -> CGFloat {
        CGFloat.minimum(CGFloat.maximum(min, value), max)
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if selectorWindow!.hidesOnDeactivate {
            selectorWindow!.contentView = nil
            selectorWindow!.close()
        }
    }
    
    func getScreenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })
        
        return screenWithMouse
    }
}
