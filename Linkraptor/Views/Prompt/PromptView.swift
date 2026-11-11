//
//  PromptView.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import AppKit
import SwiftUI

struct PromptView: View {
    @AppStorage("browsers") private var browsers: [URL] = []
    @AppStorage("hiddenBrowsers") private var hiddenBrowsers: [URL] = []
    @AppStorage("apps") private var apps: [App] = []
    @AppStorage("shortcuts") private var shortcuts: [String: String] = [:]

    @AppStorage("copy_closeAfterCopy") private var closeAfterCopy: Bool = false
    @AppStorage("copy_alternativeShortcut") private var alternativeShortcut: Bool = false
    @AppStorage("apps_atTop") private var appsAtTop: Bool = true
    @AppStorage("chromeProfiles") private var chromeProfiles: [String: String] = [:]
    @AppStorage("primaryChromeProfile") private var primaryChromeProfile: String = ""

    let urls: [URL]

    @State private var selected = 0
    @FocusState private var focused: Bool

    init(urls: [URL]) {
        self.urls = urls
        _selected = State(initialValue: initialSelection)
    }

    private static let padding: CGFloat = 6
    private static let headerHeight: CGFloat = 28
    private static let separatorHeight: CGFloat = 11
    private static let maxVisibleRows = 12

    /// One row in the picker: an app matched by the link's host, a browser,
    /// or a Chrome profile listed under Chrome.
    private enum Choice {
        case app(App)
        case browser(URL)
        case profile(browser: URL, profile: ChromeProfile, label: String)

        var bundleURL: URL {
            switch self {
            case .app(let app): app.app
            case .browser(let browser): browser
            case .profile(let browser, _, _): browser
            }
        }
    }

    var appsForUrls: [App] {
        urls.flatMap { url in
            return apps.filter { app in
                url.matchesHost(app.host)
            }
        }
        .filter {
            !browsers.contains($0.app)
        }
    }

    var visibleBrowsers: [URL] {
        browsers.filter { !hiddenBrowsers.contains($0) }
    }

    /// Browsers in order, with the profiles ticked in Preferences right under Chrome.
    private var browserChoices: [Choice] {
        visibleBrowsers.flatMap { browser -> [Choice] in
            guard ChromeProfiles.isChrome(browser) else { return [.browser(browser)] }
            let profiles = ChromeProfiles.shown(chromeProfiles).map {
                Choice.profile(browser: browser, profile: $0.profile, label: $0.label)
            }
            return [.browser(browser)] + profiles
        }
    }

    private var choices: [Choice] {
        let appChoices = appsForUrls.map(Choice.app)
        let browserChoices = self.browserChoices
        return appsAtTop ? appChoices + browserChoices : browserChoices + appChoices
    }

    /// Row index the divider between apps and browsers sits above, if both are shown.
    private var dividerIndex: Int? {
        guard !appsForUrls.isEmpty, !visibleBrowsers.isEmpty else { return nil }
        return appsAtTop ? appsForUrls.count : browserChoices.count
    }

    /// The row highlighted when the picker opens. Normally the first one, but
    /// when a Chrome profile is the primary browser (set from the Rex menu)
    /// and Chrome is on top, it's that profile, so Return opens it.
    private var initialSelection: Int {
        guard !primaryChromeProfile.isEmpty else { return 0 }
        let choices = self.choices
        guard case .browser(let first)? = choices.first, ChromeProfiles.isChrome(first) else { return 0 }
        return choices.firstIndex { choice in
            guard case .profile(_, let profile, _) = choice else { return false }
            return profile.directory == primaryChromeProfile
        } ?? 0
    }

    private var listHeight: CGFloat {
        let rows = CGFloat(min(choices.count, Self.maxVisibleRows)) * PromptItem.height
        return rows + (dividerIndex == nil ? 0 : Self.separatorHeight)
    }

    func openUrlsInApp(app: App) {
        let urls =
            if app.schemeOverride.isEmpty {
                urls
            } else {
                urls.map {
                    let url = NSURLComponents.init(
                        url: $0,
                        resolvingAgainstBaseURL: true
                    )
                    url!.scheme = app.schemeOverride

                    return url!.url!
                }
            }

        BrowserUtil.openURL(
            urls,
            app: app.app,
            isIncognito: false
        )
    }

    private func open(_ choice: Choice, isIncognito: Bool) {
        switch choice {
        case .app(let app):
            openUrlsInApp(app: app)
        case .browser(let browser):
            BrowserUtil.openURL(urls, app: browser, isIncognito: isIncognito)
        case .profile(let browser, let profile, _):
            BrowserUtil.openURL(
                urls,
                app: browser,
                isIncognito: isIncognito,
                profileDirectory: profile.directory
            )
        }
    }

    private func openSelected(isIncognito: Bool) {
        let choices = self.choices
        guard choices.indices.contains(selected) else { return }
        open(choices[selected], isIncognito: isIncognito)
    }

    private func profileRow(_ choice: Choice) -> (label: String, avatar: NSImage)? {
        guard case .profile(_, let profile, let label) = choice else { return nil }
        return (label, profile.avatar)
    }

    /// Letter shortcuts belong to the browser, so profile rows only get a number.
    private func shortcut(for choice: Choice) -> String? {
        if case .profile = choice { return nil }
        guard let id = Bundle(url: choice.bundleURL)?.bundleIdentifier else { return nil }
        return shortcuts[id]
    }

    private func copyLink() {
        let pasteboard = NSPasteboard.general
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(urls.first?.absoluteString ?? "", forType: .string)

        if closeAfterCopy {
            NSApplication.shared.keyWindow?.close()
        }
    }

    private var separator: some View {
        Divider()
            .padding(.horizontal, 5)
            .frame(height: Self.separatorHeight)
    }

    var body: some View {
        let choices = self.choices

        VStack(spacing: 0) {
            if let host = urls.first?.host() {
                HStack(spacing: 6) {
                    Text(host)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer(minLength: 6)

                    Button(action: copyLink) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(
                        KeyEquivalent("c"),
                        modifiers: alternativeShortcut ? [.command] : [.command, .option]
                    )
                    .toolTip(urls.first?.absoluteString ?? "")
                }
                .padding(.horizontal, 12)
                .frame(height: Self.headerHeight)

                separator
            }

            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                            if index == dividerIndex {
                                separator
                            }

                            let custom = shortcut(for: choice)

                            PromptItem(
                                app: choice.bundleURL,
                                profile: profileRow(choice),
                                shortcut: custom,
                                keyHint: custom?.uppercased() ?? (index < 9 ? "\(index + 1)" : nil),
                                selected: selected == index
                            ) {
                                open(choice, isIncognito: NSEvent.modifierFlags.contains(.shift))
                            }
                            .id(index)
                            .onHover { hovering in
                                if hovering {
                                    selected = index
                                }
                            }
                        }
                    }
                }
                .frame(height: listHeight)
                .scrollBounceBehavior(.basedOnSize)
                .focusable()
                .focusEffectDisabledCompat()
                .focused($focused)
                .onMoveCommand { command in
                    if command == .up {
                        selected = max(0, selected - 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                    } else if command == .down {
                        selected = min(choices.count - 1, selected + 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                    }
                }
                .background {
                    Button(action: { openSelected(isIncognito: false) }) {}
                        .opacity(0)
                        .keyboardShortcut(.defaultAction)

                    Button(action: { openSelected(isIncognito: true) }) {}
                        .opacity(0)
                        .keyboardShortcut(.return, modifiers: [.shift])

                    Button(action: {
                        NSApplication.shared.keyWindow?.close()
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.cancelAction)

                    // Number keys 1–9 open the matching row.
                    ForEach(0..<min(9, choices.count), id: \.self) { index in
                        Button(action: { open(choices[index], isIncognito: false) }) {}
                            .opacity(0)
                            .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: [])
                    }
                }
                .onAppear {
                    focused.toggle()
                }
                .scrollEdgeEffectDisabledCompat()
            }
        }
        .padding(Self.padding)
        .frame(width: LinkraptorWindow.selectorWidth)
    }
}

#Preview {
    PromptView(urls: [])
}
