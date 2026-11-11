//
//  LinkraptorWindow.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import Foundation
import AppKit

class LinkraptorWindow: NSPanel {
    static let selectorWidth: CGFloat = 270
    static let selectorHeight: CGFloat = 200
    static let cornerRadius: CGFloat = 16

    public convenience init() {
        self.init(
            contentRect: .init(x: 0, y: 0, width: Self.selectorWidth, height: Self.selectorHeight),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        self.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllSpaces]
        self.isOpaque = false
        self.backgroundColor = .clear
        // No window shadow: the glass's own edge defines the panel.
        self.hasShadow = false
        self.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
        self.isMovable = false
        self.deactivateDelay()
    }
    
    func deactivateDelay() {
        self.hidesOnDeactivate = false
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            self.makeKeyAndOrderFront(nil)
            self.hidesOnDeactivate = true
        }
    }
}

extension NSPanel {
    open override var canBecomeKey: Bool { true }
}
