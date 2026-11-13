//  BrowserUtil.swift
//  Browserino
//
//  Created by byt3m4st3r.
//

import AppKit
import Foundation
import SwiftUI

class BrowserUtil {
    @AppStorage("directories") private static var directories: [Directory] = []
    @AppStorage("privateArgs") private static var privateArgs: [String: String] = [:]

    static func loadBrowsers(
        oldBrowsers: [URL]
    ) -> [URL] {
        if directories.isEmpty {
            let defaultDirectory = Directory(directoryPath: "/Applications")
            directories.append(defaultDirectory)
        }
        
        let validDirectories = directories.map { $0.directoryPath }

        guard let url = URL(string: "https:") else {
            return []
        }

        let urlsForApplications = NSWorkspace.shared.urlsForApplications(toOpen: url)

        var filteredUrlsForApplications = urlsForApplications.filter { urlsForApplication in
            validDirectories.contains { urlsForApplication.path.hasPrefix($0) }
        }
        
        if let linkraptor = NSWorkspace.shared.urlForApplication(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "io.github.matmac945.Linkraptor") {
            filteredUrlsForApplications.removeAll { $0 == linkraptor }
        }

        if let safari = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Safari") {
            if !filteredUrlsForApplications.contains(safari) {
                filteredUrlsForApplications.append(safari)
            }
        }
        
        var oldPositions: [URL: Int] = [:]
        for (index, browser) in oldBrowsers.enumerated() {
            oldPositions[browser] = index
        }
        
        filteredUrlsForApplications.sort { browser1, browser2 in
            if let pos1 = oldPositions[browser1], let pos2 = oldPositions[browser2] {
                return pos1 < pos2
            }
            else if oldPositions[browser1] != nil {
                return true
            }
            else if oldPositions[browser2] != nil {
                return false
            }
            
            return true
        }
        
        return filteredUrlsForApplications
    }
    
    /// `profileDirectory` is a Chrome profile folder such as "Profile 4".
    static func openURL(_ urls: [URL], app: URL, isIncognito: Bool, profileDirectory: String? = nil) {
        guard let bundle = Bundle(url: app) else {
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()

        var arguments: [String] = []
        if let profileDirectory {
            arguments.append("--profile-directory=\(profileDirectory)")
        }
        if isIncognito, let privateArg = privateArgs[bundle.bundleIdentifier!], !privateArg.isEmpty {
            arguments.append(privateArg)
        }

        // Flags only reach the browser on its command line, so the links go
        // there too. A running Chrome hands the whole command line over to
        // its open window, so this works whether or not it's already open.
        //
        // Only pass web and file links: anything else (or text starting with
        // "-") could be read by the browser as a command-line flag.
        if !arguments.isEmpty {
            let safeUrls = urls.filter(isSafeToPassAsArgument)
            guard !safeUrls.isEmpty else {
                return
            }
            configuration.createsNewApplicationInstance = true
            configuration.arguments = arguments + safeUrls.map(\.absoluteString)
        }

        NSWorkspace.shared.open(
            arguments.isEmpty ? urls : [],
            withApplicationAt: app,
            configuration: configuration
        )
    }

    private static func isSafeToPassAsArgument(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "http", "https":
            return url.host() != nil
        case "file":
            return true
        default:
            return false
        }
    }
}
