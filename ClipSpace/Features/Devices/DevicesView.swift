//
//  DevicesView.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 03/10/26.
//

import SwiftUI

struct DevicesView: View {
    @Environment(\.scenePhase) private var scenePhase

    let model: DeviceSyncViewModel
    let clipsDidChange: () async -> Void

    @State private var showsConsent = false
    @State private var showsStopConfirmation = false

    var body: some View {
        List {
            CloudSyncStatusSection(
                accountAvailability: model.accountAvailability,
                accountMessage: model.accountMessage,
                isConsentGranted: model.isConsentGranted,
                isSyncing: model.isSyncing,
                lastSyncedAt: model.lastSyncedAt,
                enableAction: { showsConsent = true },
                retryAction: { Task { await model.refresh() } },
                stopAction: { showsStopConfirmation = true },
                syncAction: synchronize
            )

            if model.isConsentGranted {
                DeviceListSection(devices: model.devices) { device, isEnabled in
                    await model.setSyncEnabled(isEnabled, for: device)
                }

                SensitiveSyncSection(
                    includesSensitiveContent: model.includesSensitiveContent,
                    updateAction: model.setIncludesSensitiveContent
                )
            }
        }
        .navigationTitle("Devices")
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.refresh() }
        }
        .refreshable {
            await model.refresh()
        }
        .alert("Turn On iCloud Sync?", isPresented: $showsConsent) {
            Button("Not Now", role: .cancel) { }
            Button("Turn On") {
                Task {
                    if await model.grantConsentAndSync() {
                        await clipsDidChange()
                    }
                }
            }
        } message: {
            Text("ClipSpace will store your clipboard history in your private iCloud database so it can appear on your signed-in devices. You can turn sync off at any time.")
        }
        .confirmationDialog(
            "Stop syncing this device?",
            isPresented: $showsStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop Syncing", role: .destructive) {
                model.stopSyncing()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Existing iCloud data stays available to your other devices. Clips on this device remain local.")
        }
        .alert(
            "Sync Unavailable",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func synchronize() {
        Task {
            await model.synchronize()
            await clipsDidChange()
        }
    }
}

private struct CloudSyncStatusSection: View {
    let accountAvailability: CloudAccountAvailability
    let accountMessage: String
    let isConsentGranted: Bool
    let isSyncing: Bool
    let lastSyncedAt: Date?
    let enableAction: () -> Void
    let retryAction: () -> Void
    let stopAction: () -> Void
    let syncAction: () -> Void

    var body: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: statusSymbol)
                    .font(.title2)
                    .foregroundStyle(statusColor)
                    .frame(width: 36)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(accountMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSyncing {
                    ProgressView()
                }
            }
            .padding(.vertical, 4)

            if isConsentGranted {
                LabeledContent("Last Sync") {
                    if let lastSyncedAt {
                        Text(DateFormatterHelper.previewString(for: lastSyncedAt))
                    } else {
                        Text("Not synced yet")
                    }
                }

                Button(action: syncAction) {
                    Label(isSyncing ? "Syncing…" : "Sync Now", systemImage: "arrow.trianglehead.2.clockwise")
                }
                .disabled(isSyncing || accountAvailability != .available)

                Button("Stop Syncing This Device", systemImage: "icloud.slash", role: .destructive, action: stopAction)
            } else {
                if accountAvailability == .available {
                    Button("Sync with iCloud", systemImage: "icloud.and.arrow.up", action: enableAction)
                } else if accountAvailability == .checking {
                    LabeledContent("Checking iCloud") {
                        ProgressView()
                    }
                } else {
                    Button("Check iCloud Again", systemImage: "arrow.clockwise", action: retryAction)
                }
            }
        } header: {
            Text("iCloud Sync")
        } footer: {
            Text("ClipSpace uses your private CloudKit database. Your clips aren’t visible to other ClipSpace users.")
        }
    }

    private var statusTitle: LocalizedStringKey {
        if isSyncing { return "Syncing with iCloud" }
        if isConsentGranted && accountAvailability == .available { return "Syncing Enabled" }
        return "Syncing Off"
    }

    private var statusSymbol: String {
        isConsentGranted && accountAvailability == .available ? "checkmark.icloud.fill" : "icloud.slash"
    }

    private var statusColor: Color {
        isConsentGranted && accountAvailability == .available ? .green : .secondary
    }
}

private struct DeviceListSection: View {
    let devices: [ClipDevice]
    let updateAction: (ClipDevice, Bool) async -> Void

    var body: some View {
        Section {
            if devices.isEmpty {
                ContentUnavailableView(
                    "No ClipSpace Devices",
                    systemImage: "laptopcomputer.and.iphone",
                    description: Text("Devices appear here after ClipSpace sync is enabled on them.")
                )
            } else {
                ForEach(devices) { device in
                    DeviceSyncRow(device: device, updateAction: updateAction)
                }
            }
        } header: {
            Text("ClipSpace Devices")
        } footer: {
            Text("For privacy, Apple doesn’t provide apps with your complete Apple Account device list. Only devices that enable ClipSpace sync appear here.")
        }
    }
}

private struct DeviceSyncRow: View {
    let device: ClipDevice
    let updateAction: (ClipDevice, Bool) async -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: device.kind.symbolName)
                .font(.title2)
                .frame(width: 36)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(device.name)
                        .font(.headline)
                    if device.isCurrentDevice {
                        Text("This Device")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
                Text("Last active \(DateFormatterHelper.previewString(for: device.lastActive))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(
                "Allow Sync",
                isOn: Binding(
                    get: { device.isSyncEnabled },
                    set: { isEnabled in
                        Task { await updateAction(device, isEnabled) }
                    }
                )
            )
            .labelsHidden()
            .disabled(device.isCurrentDevice)
            .accessibilityLabel("Sync \(device.name)")
            .accessibilityHint(device.isCurrentDevice ? "Use Stop Syncing to disable this device." : "Allows or blocks this device from syncing.")
        }
        .padding(.vertical, 4)
    }
}

private struct SensitiveSyncSection: View {
    let includesSensitiveContent: Bool
    let updateAction: (Bool) -> Void

    var body: some View {
        Section {
            Toggle(
                "Sync Sensitive Content",
                systemImage: "lock.icloud",
                isOn: Binding(get: { includesSensitiveContent }, set: updateAction)
            )
        } footer: {
            Text("Off by default. Clips marked sensitive stay only on the device where they were copied.")
        }
    }
}

#Preview {
    NavigationStack {
        DevicesView(
            model: DeviceSyncViewModel(repository: MockClipRepository()),
            clipsDidChange: { }
        )
    }
}
