//
//  PromptItem.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct PromptItem: View {
    static let height: CGFloat = 34

    var app: URL
    /// Set for a Chrome profile row: drawn indented under Chrome, with the
    /// profile's picture and the name chosen in Preferences.
    var profile: (label: String, avatar: NSImage)? = nil
    /// Letter shortcut the user assigned in Preferences, if any.
    var shortcut: String?
    /// Key hint shown on the right: the letter shortcut, or the row number.
    var keyHint: String?
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let profile {
                    Image(nsImage: profile.avatar)
                        .resizable()
                        .frame(width: 20, height: 20)
                        .padding(.leading, 16)
                } else {
                    Image(nsImage: app.appIcon)
                        .resizable()
                        .frame(width: 24, height: 24)
                }

                Text(profile?.label ?? app.appDisplayName)
                    .font(.system(size: 15))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 8)

                if let keyHint {
                    Text(keyHint)
                        .font(.system(size: 13))
                        .foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: Self.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(SelectButtonStyle(selected: selected))
        .if(shortcut != nil) {
            return $0.keyboardShortcut(
                KeyEquivalent(shortcut!.lowercased().first!),
                modifiers: [.shift]
            ).background {
                Button(action: action) {}
                    .opacity(0)
                    .keyboardShortcut(
                        KeyEquivalent(shortcut!.lowercased().first!),
                        modifiers: []
                    )
            }
        }
    }
}
