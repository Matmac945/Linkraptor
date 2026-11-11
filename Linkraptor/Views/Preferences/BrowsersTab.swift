//
//  BrowsersTab.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct BrowsersTab: View {
    @AppStorage("browsers") private var browsers: [URL] = []
    @AppStorage("hiddenBrowsers") private var hiddenBrowsers: [URL] = []
    @AppStorage("privateArgs") private var privateArgs: [String: String] = [:]

    @State private var showsChromeProfiles = false
    /// The browser whose private argument pop-up is open, if any.
    @State private var editingPrivateArg: String?

    private func move(from source: IndexSet, to destination: Int) {
        browsers.move(fromOffsets: source, toOffset: destination)
    }

    private func privateArg(for key: String) -> Binding<String> {
        return .init(
            get: { self.privateArgs[key, default: ""] },
            set: { self.privateArgs[key] = $0 })
    }

    var body: some View {
        VStack(alignment: .leading) {
            List {
                ForEach(Array(browsers.enumerated()), id: \.offset) { offset, browser in
                    if let bundle = Bundle(url: browser) {
                        let isChrome = bundle.bundleIdentifier == ChromeProfiles.bundleIdentifier

                        VStack(alignment: .leading, spacing: 0) {
                            HStack {
                                Text((offset + 1).formatted())
                                    .font(
                                        .system(size: 16)
                                    )
                                    .frame(width: 30, alignment: .leading)

                                Image(nsImage: NSWorkspace.shared.icon(forFile: bundle.bundlePath))
                                    .resizable()
                                    .frame(width: 32, height: 32)

                                Spacer()
                                    .frame(width: 8)

                                Group {
                                    if isChrome {
                                        Button {
                                            showsChromeProfiles.toggle()
                                        } label: {
                                            Image(systemName: showsChromeProfiles ? "chevron.down" : "chevron.right")
                                                .font(.system(size: 11, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                                .frame(width: 14, height: 20)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .help("Choose which Chrome profiles show in the picker")
                                    }
                                }
                                .frame(width: 14)

                                Text(bundle.infoDictionary!["CFBundleName"] as! String)
                                    .font(
                                        .system(size: 14)
                                    )

                                Spacer()
                                    .frame(width: 32)

                                // Edited in a pop-up rather than a text box here:
                                // clicks inside this reorderable list felt slow to
                                // reach a text box.
                                let bundleId = bundle.bundleIdentifier!
                                let arg = privateArgs[bundleId, default: ""]

                                HStack(spacing: 6) {
                                    Text(arg.isEmpty ? "No private argument" : arg)
                                        .font(arg.isEmpty ? .system(size: 13) : .system(size: 14).monospaced())
                                        .foregroundStyle(arg.isEmpty ? .secondary : .primary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)

                                    Button {
                                        editingPrivateArg = bundleId
                                    } label: {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 15))
                                            .frame(width: 24, height: 24)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Edit the private argument")
                                    .popover(
                                        isPresented: .init(
                                            get: { editingPrivateArg == bundleId },
                                            set: { if !$0 { editingPrivateArg = nil } }
                                        ),
                                        arrowEdge: .bottom
                                    ) {
                                        TextEditPopover(
                                            title: "Private argument",
                                            placeholder: "--incognito",
                                            hint: "Added when you Shift-click a browser in the picker or press Shift-Return, to open the link in a private window. Chrome: --incognito. Zen and Firefox: --private-window.",
                                            monospaced: true,
                                            text: privateArg(for: bundleId),
                                            close: { editingPrivateArg = nil }
                                        )
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Spacer()
                                    .frame(width: 32)

                                ShortcutButton(
                                    browserId: bundle.bundleIdentifier!
                                )

                                Spacer()
                                    .frame(width: 8)

                                Button(action: {
                                    if let idx = hiddenBrowsers.firstIndex(of: browser) {
                                        hiddenBrowsers.remove(at: idx)
                                    } else {
                                        hiddenBrowsers.append(browser)
                                    }
                                }) {
                                    Image(
                                        systemName: hiddenBrowsers.contains(browser)
                                            ? "eye.slash.fill" : "eye.fill")
                                }
                                .buttonStyle(.plain)
                            }

                            if isChrome && showsChromeProfiles {
                                ChromeProfileList()
                            }
                        }
                        .padding(10)
                    }
                }
                .onMove(perform: move)
            }
            .onAppear {
                if browsers.isEmpty {
                    browsers = BrowserUtil.loadBrowsers(
                        oldBrowsers: browsers
                    )
                }
            }

            Text(
                "Drag and drop to reorder. Press record to assign a shortcut. Click on eye to hide unwanted browsers from prompt. Click the arrow next to Chrome to pick its profiles."
            )
            .font(.subheadline)
            .foregroundStyle(.primary.opacity(0.5))
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 20)
    }
}

/// Chrome's profiles with a tick box each. Ticked ones show in the picker
/// under Chrome, using the name typed next to them.
private struct ChromeProfileList: View {
    @AppStorage("chromeProfiles") private var selected: [String: String] = [:]
    @AppStorage("primaryChromeProfile") private var primaryChromeProfile: String = ""

    private let profiles = ChromeProfiles.all()

    /// The profile whose rename pop-up is open, if any.
    @State private var renaming: String?

    private func isShown(_ profile: ChromeProfile) -> Binding<Bool> {
        .init(
            get: { selected[profile.directory] != nil },
            set: { shown in
                selected[profile.directory] = shown ? "" : nil
                if !shown && primaryChromeProfile == profile.directory {
                    primaryChromeProfile = ""
                }
            }
        )
    }

    private func label(_ profile: ChromeProfile) -> Binding<String> {
        .init(
            get: { selected[profile.directory] ?? "" },
            set: { selected[profile.directory] = $0 }
        )
    }

    private func isRenaming(_ profile: ChromeProfile) -> Binding<Bool> {
        .init(
            get: { renaming == profile.directory },
            set: { if !$0 { renaming = nil } }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Show these profiles in the picker")
                Spacer()
                Text("\(profiles.filter { selected[$0.directory] != nil }.count) of \(profiles.count)")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            if profiles.isEmpty {
                Text("Couldn't read Chrome's profile list.")
                    .foregroundStyle(.secondary)
            }

            ForEach(profiles, id: \.directory) { profile in
                let shown = selected[profile.directory] != nil

                HStack(spacing: 9) {
                    Toggle("", isOn: isShown(profile))
                        .toggleStyle(.checkbox)
                        .labelsHidden()

                    Image(nsImage: profile.avatar)
                        .resizable()
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile.name)
                            .foregroundStyle(shown ? .primary : .secondary)
                        Text(profile.email.isEmpty ? "Not signed in" : profile.email)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Renaming happens in a pop-up rather than in a text box
                    // here: clicks inside this reorderable list felt slow to
                    // reach a text box.
                    if shown {
                        let custom = selected[profile.directory] ?? ""

                        Text(custom.isEmpty ? profile.name : custom)
                            .foregroundStyle(custom.isEmpty ? .secondary : .primary)
                            .lineLimit(1)

                        Button {
                            renaming = profile.directory
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 15))
                                .frame(width: 24, height: 24)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .help("Rename in the picker")
                        .popover(isPresented: isRenaming(profile), arrowEdge: .bottom) {
                            TextEditPopover(
                                title: "Name in the picker",
                                placeholder: profile.name,
                                hint: "Leave empty to use Chrome's name.",
                                text: label(profile),
                                close: { renaming = nil }
                            )
                        }
                    }
                }
            }
        }
        .padding(.top, 10)
        .padding(.leading, 84)
    }
}

/// A small pop-up with one text box, opened from a pencil button. Its text
/// box lives in the pop-up's own window, outside the reorderable list.
private struct TextEditPopover: View {
    let title: String
    let placeholder: String
    let hint: String
    var monospaced = false
    @Binding var text: String
    let close: () -> Void

    @State private var draft: String
    @FocusState private var focused: Bool

    init(
        title: String,
        placeholder: String,
        hint: String,
        monospaced: Bool = false,
        text: Binding<String>,
        close: @escaping () -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.hint = hint
        self.monospaced = monospaced
        self._text = text
        self.close = close
        self._draft = State(initialValue: text.wrappedValue)
    }

    private func save() {
        text = draft.trimmingCharacters(in: .whitespaces)
        close()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))

            TextField(placeholder, text: $draft)
                .textFieldStyle(.roundedBorder)
                .font(monospaced ? .system(size: 13).monospaced() : .system(size: 13))
                .frame(width: 260)
                .focused($focused)
                .onSubmit(save)

            Text(hint)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 260, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("Cancel", action: close)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .onAppear { focused = true }
    }
}

#Preview {
    PreferencesView()
}
