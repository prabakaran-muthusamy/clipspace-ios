//
//  DevicesView.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import SwiftUI

struct DevicesView: View {
    private let devices = [
        ClipDevice(id: UUID(), name: "MacBook Pro", kind: .mac, lastActive: .now.addingTimeInterval(-120), syncState: .synced),
        ClipDevice(id: UUID(), name: "iPhone", kind: .phone, lastActive: .now.addingTimeInterval(-480), syncState: .synced),
        ClipDevice(id: UUID(), name: "iPad", kind: .tablet, lastActive: .now.addingTimeInterval(-7_200), syncState: .pending)
    ]

    var body: some View {
        List {
            Section {
                LabeledContent {
                    Label("Mock data", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("iCloud Sync", systemImage: "icloud")
                }
            } footer: {
                Text("CloudKit sync is not enabled yet. Device status shown here is sample data.")
            }

            Section("Devices") {
                ForEach(devices) { device in
                    HStack(spacing: 14) {
                        Image(systemName: device.kind.symbolName)
                            .font(.title2)
                            .frame(width: 36)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading) {
                            Text(device.name).font(.headline)
                            Text("Active \(DateFormatterHelper.previewString(for: device.lastActive))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        SyncStatusView(state: device.syncState)
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Label("Sync Settings", systemImage: "arrow.trianglehead.2.clockwise")
                Label("Manage Devices", systemImage: "laptopcomputer.and.iphone")
                Label("Security & Privacy", systemImage: "lock.shield")
            }
        }
        .navigationTitle("Devices")
    }
}
