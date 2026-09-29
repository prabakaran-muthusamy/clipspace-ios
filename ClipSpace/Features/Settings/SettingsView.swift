//
//  SettingsView.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearance = AppearancePreference.system.rawValue
    @State private var syncAcrossDevices = true
    @State private var syncSensitiveContent = false

    var body: some View {
        Form {
            Section("Sync") {
                Toggle("Sync Across Devices", systemImage: "icloud", isOn: $syncAcrossDevices)
                Toggle("Sync Sensitive Content", systemImage: "lock.icloud", isOn: $syncSensitiveContent)
            }

            Section("App") {
                Picker("Appearance", systemImage: "circle.lefthalf.filled", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.rawValue).tag(option.rawValue)
                    }
                }
                NavigationLink("Clip History Limit", destination: Text("History limits will be available with local persistence."))
                Label("Siri & Shortcuts", systemImage: "sparkles")
                Label("Keyboard Extension", systemImage: "keyboard")
                Label("Widgets & Controls", systemImage: "square.grid.2x2")
            }

            Section("Privacy & Security") {
                Label("Sensitive Content", systemImage: "eye.slash")
                Label("Excluded Apps", systemImage: "hand.raised")
                Button("Clear History", systemImage: "trash", role: .destructive) { }
            }

            Section("About") {
                Label("Privacy", systemImage: "hand.raised.fill")
                Label("Terms", systemImage: "doc.text")
                Label("About ClipSpace", systemImage: "info.circle")
                LabeledContent("Version", value: "1.0")
            }
        }
        .navigationTitle("Settings")
    }
}
