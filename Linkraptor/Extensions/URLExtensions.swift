//
//  URLExtensions.swift
//  Browserino
//
//  Created by Claude Code on 05.01.2026.
//

import AppKit
import Foundation

extension URL {
    func matchesHost(_ configuredHost: String) -> Bool {
        if configuredHost.isEmpty {
            return true
        }

        guard let urlHost = self.host()?.lowercased() else { return false }
        let appHost = configuredHost.lowercased()
        return urlHost == appHost || urlHost.hasSuffix("." + appHost)
    }

    /// Finder's name for an app bundle, e.g. "Zoom" for zoom.us.app.
    var appDisplayName: String {
        let name = FileManager.default.displayName(atPath: resolvingSymlinksInPath().path)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }

    /// The app's icon. Symlinks are resolved first so apps like Safari,
    /// which live in a system volume on macOS 26, don't get an alias arrow.
    var appIcon: NSImage {
        NSWorkspace.shared.icon(forFile: resolvingSymlinksInPath().path)
    }

    /// An http(s) link found on the general pasteboard, if any.
    static var fromClipboard: URL? {
        let pasteboard = NSPasteboard.general
        guard let text = (pasteboard.string(forType: .string) ?? pasteboard.string(forType: .URL))?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: text),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host() != nil
        else {
            return nil
        }
        return url
    }
}
