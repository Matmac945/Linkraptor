//
//  ButtonStyles.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import SwiftUI
import Foundation

// Native menu row: the accent highlight follows the mouse and arrow keys,
// so there is no separate hover effect.
struct SelectButtonStyle: ButtonStyle {
    let selected: Bool

    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isPressed || selected ? Color.accentColor : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
