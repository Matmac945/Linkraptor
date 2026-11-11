//
//  ChromeProfiles.swift
//  Browserino
//
//  Created by Claude Code on 02.11.2026.
//

import AppKit
import Foundation

/// One profile from Chrome's own list.
struct ChromeProfile: Hashable {
    /// Folder name, e.g. "Default" or "Profile 4". This is what
    /// --profile-directory takes, not the display name.
    let directory: String
    /// Chrome's name for it, e.g. "publicdemocracy.io". Not unique.
    let name: String
    /// Signed-in account, empty when the profile isn't signed in.
    let email: String
    /// The picture Chrome shows for the profile, already cropped to a circle.
    let avatar: NSImage
}

/// Reads Chrome's profiles from its "Local State" file. Browserino isn't
/// sandboxed, so this needs no permission prompt.
enum ChromeProfiles {
    static let bundleIdentifier = "com.google.Chrome"

    static func isChrome(_ app: URL) -> Bool {
        Bundle(url: app)?.bundleIdentifier == bundleIdentifier
    }

    private static var userDataDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Google/Chrome")
    }

    private static var cache: (modified: Date, profiles: [ChromeProfile])?

    /// Every profile, in Chrome's own order. Empty when Chrome's data can't be read.
    static func all() -> [ChromeProfile] {
        let localState = userDataDirectory.appending(path: "Local State")
        guard let modified = try? FileManager.default
            .attributesOfItem(atPath: localState.path)[.modificationDate] as? Date
        else {
            return []
        }
        if let cache, cache.modified == modified {
            return cache.profiles
        }

        guard let data = try? Data(contentsOf: localState),
              let state = try? JSONDecoder().decode(LocalState.self, from: data),
              let info = state.profile?.infoCache
        else {
            return []
        }

        let ordered = (state.profile?.profilesOrder ?? []).filter { info[$0] != nil }
        let unordered = info.keys
            .filter { !ordered.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }

        let profiles = (ordered + unordered).compactMap { directory -> ChromeProfile? in
            guard let entry = info[directory], entry.isEphemeral != true else { return nil }
            let name = entry.name ?? directory
            return ChromeProfile(
                directory: directory,
                name: name,
                email: entry.userName ?? "",
                avatar: circular(avatar(directory: directory, entry: entry))
            )
        }

        cache = (modified, profiles)
        return profiles
    }

    /// The profiles ticked in Preferences, in Chrome's order, each with the
    /// name the picker shows. A blank custom name falls back to Chrome's.
    static func shown(_ selected: [String: String]) -> [(profile: ChromeProfile, label: String)] {
        guard !selected.isEmpty else { return [] }
        return all().compactMap { profile in
            guard let label = selected[profile.directory] else { return nil }
            let trimmed = label.trimmingCharacters(in: .whitespaces)
            return (profile, trimmed.isEmpty ? profile.name : trimmed)
        }
    }

    // MARK: - Avatars

    /// Same choice Chrome makes: the account photo, unless the user picked one
    /// of Chrome's own pictures; a coloured letter when neither is on disk.
    private static func avatar(directory: String, entry: LocalState.Entry) -> NSImage? {
        let usesPhoto = entry.useGaiaPicture == true || entry.isUsingDefaultAvatar != false
        if usesPhoto,
           let file = entry.gaiaPictureFileName, !file.isEmpty,
           let image = NSImage(contentsOf: userDataDirectory.appending(path: directory).appending(path: file)) {
            return image
        }

        if let file = builtInAvatarFile(entry.avatarIcon),
           let image = NSImage(contentsOf: userDataDirectory.appending(path: "Avatars").appending(path: file)) {
            return image
        }

        return letterAvatar(
            entry.name ?? directory,
            fill: entry.defaultAvatarFillColor,
            ink: entry.defaultAvatarStrokeColor
        )
    }

    /// Chrome's newer pictures (origami animals and so on) are downloaded into
    /// "Avatars" on first use. Older ones are compiled into Chrome and aren't
    /// on disk, so they fall through to the letter.
    private static let builtInAvatarFiles: [Int: String] = {
        let names = [
            "origami_cat", "origami_corgi", "origami_dragon", "origami_elephant",
            "origami_fox", "origami_monkey", "origami_panda", "origami_penguin",
            "origami_pinkbutterfly", "origami_rabbit", "origami_unicorn",
            "illustration_basketball", "illustration_bike", "illustration_bird",
            "illustration_cheese", "illustration_football", "illustration_ramen",
            "illustration_sunglasses", "illustration_sushi", "illustration_tamagotchi",
            "illustration_vinyl", "abstract_avocado", "abstract_cappuccino",
            "abstract_icecream", "abstract_icewater", "abstract_melon",
            "abstract_onigiri", "abstract_pizza", "abstract_sandwich",
        ]
        return Dictionary(uniqueKeysWithValues: names.enumerated().map { (27 + $0.offset, "avatar_\($0.element).png") })
    }()

    private static func builtInAvatarFile(_ avatarIcon: String?) -> String? {
        guard let avatarIcon,
              let index = Int(avatarIcon.replacingOccurrences(of: "chrome://theme/IDR_PROFILE_AVATAR_", with: ""))
        else {
            return nil
        }
        return builtInAvatarFiles[index]
    }

    private static func letterAvatar(_ name: String, fill: Int?, ink: Int?) -> NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            color(fill, fallback: .systemGray).setFill()
            rect.fill()

            let letter = String(name.first(where: \.isLetter) ?? "?").uppercased()
            let text = NSAttributedString(string: letter, attributes: [
                .font: NSFont.systemFont(ofSize: 30, weight: .semibold),
                .foregroundColor: color(ink, fallback: .white),
            ])
            let size = text.size()
            text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
            return true
        }
    }

    /// Chrome stores colours as signed 32-bit ARGB.
    private static func color(_ argb: Int?, fallback: NSColor) -> NSColor {
        guard let argb else { return fallback }
        let value = UInt32(truncatingIfNeeded: argb)
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    private static func circular(_ image: NSImage?) -> NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            NSBezierPath(ovalIn: rect).addClip()
            image?.draw(in: rect)
            return true
        }
    }

    // MARK: - Local State

    private struct LocalState: Decodable {
        struct Profile: Decodable {
            let infoCache: [String: Entry]?
            let profilesOrder: [String]?

            enum CodingKeys: String, CodingKey {
                case infoCache = "info_cache"
                case profilesOrder = "profiles_order"
            }
        }

        struct Entry: Decodable {
            let name: String?
            let userName: String?
            let isEphemeral: Bool?
            let isUsingDefaultAvatar: Bool?
            let useGaiaPicture: Bool?
            let avatarIcon: String?
            let gaiaPictureFileName: String?
            let defaultAvatarFillColor: Int?
            let defaultAvatarStrokeColor: Int?

            enum CodingKeys: String, CodingKey {
                case name
                case userName = "user_name"
                case isEphemeral = "is_ephemeral"
                case isUsingDefaultAvatar = "is_using_default_avatar"
                case useGaiaPicture = "use_gaia_picture"
                case avatarIcon = "avatar_icon"
                case gaiaPictureFileName = "gaia_picture_file_name"
                case defaultAvatarFillColor = "default_avatar_fill_color"
                case defaultAvatarStrokeColor = "default_avatar_stroke_color"
            }
        }

        let profile: Profile?
    }
}
