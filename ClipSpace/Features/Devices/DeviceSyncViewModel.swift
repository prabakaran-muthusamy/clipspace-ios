//
//  DeviceSyncViewModel.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 03/10/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class DeviceSyncViewModel {
    private(set) var accountAvailability: CloudAccountAvailability = .checking
    private(set) var devices: [ClipDevice] = []
    private(set) var isSyncing = false
    private(set) var lastSyncedAt: Date?
    var errorMessage: String?
    var isConsentGranted: Bool
    var includesSensitiveContent: Bool

    private let repository: any ClipRepository
    private let cloudService: CloudSyncService
    private let defaults: UserDefaults

    init(
        repository: any ClipRepository,
        cloudService: CloudSyncService? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.cloudService = cloudService ?? CloudSyncService()
        self.defaults = defaults
        self.isConsentGranted = defaults.bool(forKey: "cloudSyncConsentGranted")
        self.includesSensitiveContent = defaults.bool(forKey: "cloudSyncSensitiveContent")
        self.lastSyncedAt = defaults.object(forKey: "cloudSyncLastSyncedAt") as? Date
    }

    func refresh() async {
        accountAvailability = await cloudService.accountAvailability()
        guard isConsentGranted, accountAvailability == .available else {
            devices = []
            return
        }
        do {
            devices = try await cloudService.registerCurrentDevice()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func grantConsentAndSync() async -> Bool {
        accountAvailability = await cloudService.accountAvailability()
        guard accountAvailability == .available else {
            errorMessage = accountMessage
            return false
        }
        isConsentGranted = true
        defaults.set(true, forKey: "cloudSyncConsentGranted")
        await synchronize()
        return errorMessage == nil
    }

    func stopSyncing() {
        isConsentGranted = false
        defaults.set(false, forKey: "cloudSyncConsentGranted")
        devices = []
    }

    func setIncludesSensitiveContent(_ isIncluded: Bool) {
        includesSensitiveContent = isIncluded
        defaults.set(isIncluded, forKey: "cloudSyncSensitiveContent")
    }

    func synchronize() async {
        guard isConsentGranted, !isSyncing else { return }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        do {
            let localClips = try await repository.fetchClips()
            let result = try await cloudService.synchronize(
                localClips: localClips,
                includesSensitiveContent: includesSensitiveContent
            )
            try await repository.replaceClips(result.clips)
            devices = result.devices
            lastSyncedAt = result.syncedAt
            defaults.set(result.syncedAt, forKey: "cloudSyncLastSyncedAt")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setSyncEnabled(_ isEnabled: Bool, for device: ClipDevice) async {
        guard !device.isCurrentDevice else { return }
        do {
            try await cloudService.setSyncEnabled(isEnabled, for: device.id)
            if let index = devices.firstIndex(where: { $0.id == device.id }) {
                devices[index].isSyncEnabled = isEnabled
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var accountMessage: String {
        switch accountAvailability {
        case .checking:
            "Checking iCloud availability…"
        case .available:
            "Ready to sync with your private iCloud database."
        case .noAccount:
            "Sign in to iCloud in Settings to sync across devices."
        case .restricted:
            "iCloud access is restricted by Screen Time or device management."
        case .temporarilyUnavailable:
            "iCloud is temporarily unavailable. Local clips remain on this device."
        case .unknown:
            "ClipSpace couldn’t determine iCloud availability."
        }
    }
}
