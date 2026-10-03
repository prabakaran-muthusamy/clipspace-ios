//
//  SettingsView.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 03/10/26.
//

import SwiftUI
import UIKit

struct SettingsView: View {
    let syncModel: DeviceSyncViewModel
    let libraryModel: ClipLibraryViewModel

    @AppStorage("appearance") private var appearance = AppearancePreference.system.rawValue
    @AppStorage("clipHistoryLimit") private var historyLimit = 1_000
    @State private var showsSyncConsent = false
    @State private var showsClearHistory = false

    var body: some View {
        Form {
            SettingsSyncSection(syncModel: syncModel, showsConsent: $showsSyncConsent)

            Section("App") {
                Picker("Appearance", systemImage: "circle.lefthalf.filled", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.rawValue).tag(option.rawValue)
                    }
                }

                NavigationLink {
                    HistoryLimitSettingsView(
                        selection: $historyLimit,
                        applyAction: libraryModel.applyHistoryLimit
                    )
                } label: {
                    LabeledContent {
                        Text(historyLimit == 0 ? "Unlimited" : historyLimit.formatted())
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Clip History Limit", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }
                }

                NavigationLink {
                    SiriShortcutsSettingsView()
                } label: {
                    Label("Siri & Shortcuts", systemImage: "sparkles")
                }

                NavigationLink {
                    KeyboardSettingsView()
                } label: {
                    Label("Keyboard Extension", systemImage: "keyboard")
                }

                NavigationLink {
                    WidgetsSettingsView()
                } label: {
                    Label("Widgets & Controls", systemImage: "square.grid.2x2")
                }
            }

            Section("Privacy & Security") {
                NavigationLink {
                    SensitiveContentSettingsView(syncModel: syncModel)
                } label: {
                    Label("Sensitive Content", systemImage: "eye.slash")
                }

                NavigationLink {
                    ExcludedAppsSettingsView()
                } label: {
                    Label("Excluded Apps", systemImage: "hand.raised")
                }

                Button("Clear History", systemImage: "trash", role: .destructive) {
                    showsClearHistory = true
                }
                .disabled(libraryModel.clips.isEmpty)
            }

            Section("About") {
                ExternalSettingsLink(
                    title: "Privacy",
                    symbol: "hand.raised.fill",
                    urlString: "https://clipspaceai.com/privacy/ios/"
                )
                ExternalSettingsLink(
                    title: "Terms",
                    symbol: "doc.text",
                    urlString: "https://clipspaceai.com/terms/ios/"
                )
                ExternalSettingsLink(
                    title: "About ClipSpace",
                    symbol: "info.circle",
                    urlString: "https://clipspaceai.com/"
                )
                LabeledContent("Version", value: appVersion)
            }
        }
        .navigationTitle("Settings")
        .task { await syncModel.refresh() }
        .alert("Turn On iCloud Sync?", isPresented: $showsSyncConsent) {
            Button("Not Now", role: .cancel) { }
            Button("Turn On") {
                Task { _ = await syncModel.grantConsentAndSync() }
            }
        } message: {
            Text("ClipSpace will store your clipboard history in your private iCloud database so it can appear on your signed-in devices.")
        }
        .confirmationDialog(
            "Clear Clip History?",
            isPresented: $showsClearHistory,
            titleVisibility: .visible
        ) {
            Button("Clear Unpinned Clips", role: .destructive) {
                Task { _ = await libraryModel.clearHistory(keepingPinned: true) }
            }
            Button("Clear All Clips", role: .destructive) {
                Task { _ = await libraryModel.clearHistory(keepingPinned: false) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Deleted clips are removed from this device and from iCloud during the next sync.")
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return [version, build.map { "(\($0))" }]
            .compactMap { $0 }
            .joined(separator: " ")
    }
}

private struct SettingsSyncSection: View {
    let syncModel: DeviceSyncViewModel
    @Binding var showsConsent: Bool

    var body: some View {
        Section("Sync") {
            Toggle(
                "Sync Across Devices",
                systemImage: "icloud",
                isOn: Binding(
                    get: { syncModel.isConsentGranted },
                    set: { isEnabled in
                        if isEnabled {
                            showsConsent = true
                        } else {
                            syncModel.stopSyncing()
                        }
                    }
                )
            )
            Toggle(
                "Sync Sensitive Content",
                systemImage: "lock.icloud",
                isOn: Binding(
                    get: { syncModel.includesSensitiveContent },
                    set: syncModel.setIncludesSensitiveContent
                )
            )
            .disabled(!syncModel.isConsentGranted)

            if syncModel.isConsentGranted {
                LabeledContent("Last Sync") {
                    Text(
                        syncModel.lastSyncedAt.map {
                            DateFormatterHelper.previewString(for: $0)
                        } ?? "Not synced yet"
                    )
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct HistoryLimitSettingsView: View {
    @Binding var selection: Int
    let applyAction: (Int) async -> Void

    private let options = [50, 100, 250, 500, 1_000, 0]

    var body: some View {
        List {
            Section {
                ForEach(options, id: \.self) { option in
                    Button {
                        selection = option
                        Task { await applyAction(option) }
                    } label: {
                        HStack {
                            Text(option == 0 ? "Unlimited" : option.formatted())
                                .foregroundStyle(.primary)
                            Spacer()
                            if selection == option {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .accessibilityAddTraits(selection == option ? .isSelected : [])
                }
            } footer: {
                Text("Pinned clips are always kept. When the limit is reached, ClipSpace removes the oldest unpinned clips first.")
            }
        }
        .navigationTitle("History Limit")
    }
}

private struct SensitiveContentSettingsView: View {
    let syncModel: DeviceSyncViewModel
    @AppStorage("maskSensitiveContent") private var masksSensitiveContent = true

    var body: some View {
        Form {
            Section {
                Toggle("Mask Sensitive Content", systemImage: "eye.slash", isOn: $masksSensitiveContent)
                Toggle(
                    "Sync Sensitive Content",
                    systemImage: "lock.icloud",
                    isOn: Binding(
                        get: { syncModel.includesSensitiveContent },
                        set: syncModel.setIncludesSensitiveContent
                    )
                )
                .disabled(!syncModel.isConsentGranted)
            } footer: {
                Text("Sensitive clips are masked in lists by default. Cloud sync for sensitive clips is separately disabled by default.")
            }
        }
        .navigationTitle("Sensitive Content")
    }
}

private struct ExcludedAppsSettingsView: View {
    @AppStorage("excludedSourceApps") private var storedApps = ""

    var body: some View {
        List {
            Section {
                ForEach(ClipSourceApp.allCases.filter { $0 != .unknown }) { app in
                    Toggle(
                        isOn: Binding(
                            get: { excludedApps.contains(app.rawValue) },
                            set: { update(app, isExcluded: $0) }
                        )
                    ) {
                        Label(app.rawValue, systemImage: app.symbolName)
                    }
                }
            } header: {
                Text("Don’t Save From")
            } footer: {
                Text("Excluded sources can’t be selected when new clips are saved. Existing clips are not removed.")
            }
        }
        .navigationTitle("Excluded Apps")
    }

    private var excludedApps: Set<String> {
        Set(storedApps.split(separator: "|").map(String.init))
    }

    private func update(_ app: ClipSourceApp, isExcluded: Bool) {
        var values = excludedApps
        if isExcluded {
            values.insert(app.rawValue)
        } else {
            values.remove(app.rawValue)
        }
        storedApps = values.sorted().joined(separator: "|")
    }
}

private struct SiriShortcutsSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Label("Open ClipSpace", systemImage: "rectangle.stack")
                Label("Show Recent Clips", systemImage: "clock")
            } header: {
                Text("Available Actions")
            } footer: {
                Text("These actions are available in Siri, Spotlight, the Action button, and the Shortcuts app.")
            }

            Section {
                Button("Open Shortcuts", systemImage: "arrow.up.forward.app") {
                    guard let url = URL(string: "shortcuts://") else { return }
                    openURL(url)
                }
            }
        }
        .navigationTitle("Siri & Shortcuts")
    }
}

private struct KeyboardSettingsView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Label("Open Settings", systemImage: "gear")
                    .onTapGesture {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(url)
                    }
            } header: {
                Text("ClipSpace Keyboard")
            } footer: {
                Text("A keyboard extension target must be installed before it appears under Settings → General → Keyboard → Keyboards.")
            }
        }
        .navigationTitle("Keyboard Extension")
    }
}

private struct WidgetsSettingsView: View {
    var body: some View {
        List {
            Section {
                Label("Recent Clips Widget", systemImage: "clock")
                Label("Pinned Clips Widget", systemImage: "pin")
                Label("Save Clipboard Control", systemImage: "doc.on.clipboard")
            } footer: {
                Text("Widget and Control Center extension targets are required before these items can be added to the Home Screen or Control Center.")
            }
        }
        .navigationTitle("Widgets & Controls")
    }
}

private struct ExternalSettingsLink: View {
    let title: LocalizedStringKey
    let symbol: String
    let urlString: String

    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            guard let url = URL(string: urlString) else { return }
            openURL(url)
        } label: {
            HStack {
                Label(title, systemImage: symbol)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.primary)
        .accessibilityHint("Opens in your browser")
    }
}

#Preview {
    let repository = MockClipRepository()
    NavigationStack {
        SettingsView(
            syncModel: DeviceSyncViewModel(repository: repository),
            libraryModel: ClipLibraryViewModel(
                repository: repository,
                clipboard: SystemClipboardWriter()
            )
        )
    }
}
