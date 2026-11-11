//
//  AboutTab.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct AboutTab: View {
    var body: some View {
        VStack {
            Spacer()
            
            Image(nsImage: NSWorkspace.shared.icon(forFile: Bundle.main.bundlePath))
                .resizable()
                .frame(width: 128, height: 128)
            
            Text(
                "Linkraptor v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as! String)"
            )
            .font(.title)
            .frame(maxWidth: .infinity)
            
            Spacer()
                .frame(height: 16)
            
            Button(action: {
                NSWorkspace.shared.open(
                    URL(string: "https://github.com/Matmac945/Linkraptor/")!
                )
            }) {
                Text("https://github.com/Matmac945/Linkraptor/")
            }
            .buttonStyle(.link)

            Spacer()
                .frame(height: 16)

            Button(action: {
                NSWorkspace.shared.open(
                    URL(string: "https://github.com/AlexStrNik/Browserino/")!
                )
            }) {
                Text("A fork of Browserino by Aleksandr Strizhnev")
                    .font(.callout)
            }
            .buttonStyle(.link)

            Spacer()
        }
    }
}

#Preview {
    AboutTab()
}
