import CloudKit
import Foundation
import UIKit

enum CloudAccountAvailability: Equatable, Sendable {
    case checking
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    case unknown
}

enum CloudSyncError: LocalizedError {
    case accountUnavailable(CloudAccountAvailability)
    case deviceRestricted

    var errorDescription: String? {
        switch self {
        case .accountUnavailable(.noAccount):
            "Sign in to iCloud in Settings to sync your clips."
        case .accountUnavailable(.restricted):
            "iCloud access is restricted on this device."
        case .accountUnavailable(.temporarilyUnavailable):
            "iCloud is temporarily unavailable. Your local clips are safe."
        case .accountUnavailable:
            "ClipSpace couldn’t access iCloud right now."
        case .deviceRestricted:
            "Sync is disabled for this device. Enable it from another connected device."
        }
    }
}

struct CloudSyncResult: Sendable {
    let clips: [ClipItem]
    let devices: [ClipDevice]
    let syncedAt: Date
}

@MainActor
final class CloudSyncService {
    private static let containerIdentifier = "iCloud.com.prabakaranmuthusamy.clipspace.ios"

    private enum RecordType {
        static let clip = "ClipSpaceClip"
        static let device = "ClipSpaceDevice"
    }

    private enum Field {
        static let payload = "payload"
        static let name = "name"
        static let kind = "kind"
        static let lastActive = "lastActive"
        static let syncEnabled = "syncEnabled"
    }

    private let container: CKContainer
    private let database: CKDatabase
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let zoneID = CKRecordZone.ID(
        zoneName: "ClipSpaceSync",
        ownerName: CKCurrentUserDefaultName
    )
    private var hasPreparedZone = false

    init(container: CKContainer? = nil, defaults: UserDefaults = .standard) {
        let resolvedContainer = container ?? CKContainer(identifier: Self.containerIdentifier)
        self.container = resolvedContainer
        self.database = resolvedContainer.privateCloudDatabase
        self.defaults = defaults
    }

    func accountAvailability() async -> CloudAccountAvailability {
        await withCheckedContinuation { continuation in
            container.accountStatus { status, _ in
                let availability: CloudAccountAvailability = switch status {
                case .available: .available
                case .noAccount: .noAccount
                case .restricted: .restricted
                case .temporarilyUnavailable: .temporarilyUnavailable
                case .couldNotDetermine: .unknown
                @unknown default: .unknown
                }
                continuation.resume(returning: availability)
            }
        }
    }

    func synchronize(localClips: [ClipItem], includesSensitiveContent: Bool) async throws -> CloudSyncResult {
        let availability = await accountAvailability()
        guard availability == .available else {
            throw CloudSyncError.accountUnavailable(availability)
        }
        try await prepareZoneIfNeeded()

        let currentID = currentDeviceID
        let currentRecordID = recordID(for: currentID)
        let currentDeviceResult = try await database.records(for: [currentRecordID])
        let storedCurrentRecord: CKRecord?
        if case let .success(record)? = currentDeviceResult[currentRecordID] {
            storedCurrentRecord = record
        } else {
            storedCurrentRecord = nil
        }
        if let storedCurrentRecord,
           (storedCurrentRecord[Field.syncEnabled] as? Int64) == 0 {
            throw CloudSyncError.deviceRestricted
        }

        let now = Date()
        let currentRecord = storedCurrentRecord
            ?? CKRecord(recordType: RecordType.device, recordID: currentRecordID)
        configureCurrentDeviceRecord(currentRecord, lastActive: now)
        _ = try await database.save(currentRecord)

        let eligibleLocalClips = localClips.filter { includesSensitiveContent || !$0.isSensitive }
        let localIDs = Set(eligibleLocalClips.map(\.id))
        for deletedID in previouslySyncedClipIDs.subtracting(localIDs) {
            do {
                try await database.deleteRecord(withID: recordID(for: deletedID))
            } catch let error as CKError where error.code == .unknownItem {
                continue
            }
        }

        let cloudRecords = try await fetchRecords(ofType: RecordType.clip)
        let legacySampleRecords = cloudRecords.filter { record in
            guard let clip = try? decodeClip(from: record) else { return false }
            return isLegacyBundledSample(clip)
        }
        for record in legacySampleRecords {
            try await database.deleteRecord(withID: record.recordID)
        }
        let activeCloudRecords = cloudRecords.filter { record in
            !legacySampleRecords.contains { $0.recordID == record.recordID }
        }
        let cloudClips = activeCloudRecords.compactMap { try? decodeClip(from: $0) }
            .filter { includesSensitiveContent || !$0.isSensitive }
        var merged = Dictionary(uniqueKeysWithValues: cloudClips.map { ($0.id, $0) })
        let cloudIDs = Set(cloudClips.map(\.id))
        let remotelyDeletedIDs = previouslySyncedClipIDs.subtracting(cloudIDs)
        for clip in eligibleLocalClips where !remotelyDeletedIDs.contains(clip.id) {
            if let cloudClip = merged[clip.id], cloudClip.updatedAt > clip.updatedAt {
                continue
            }
            merged[clip.id] = clip
        }

        let cloudRecordsByID = Dictionary(
            uniqueKeysWithValues: activeCloudRecords.map { ($0.recordID.recordName, $0) }
        )
        var synchronizedClips: [ClipItem] = []
        for var clip in merged.values {
            clip.syncState = .synced
            let existingRecord = cloudRecordsByID[clip.id.uuidString]
            _ = try await database.save(try encodeRecord(for: clip, existingRecord: existingRecord))
            synchronizedClips.append(clip)
        }

        previouslySyncedClipIDs = Set(synchronizedClips.map(\.id))
        let deviceRecords = try await fetchRecords(ofType: RecordType.device)
        let retainedSensitiveClips = includesSensitiveContent ? [] : localClips.filter(\.isSensitive)
        return CloudSyncResult(
            clips: (synchronizedClips + retainedSensitiveClips)
                .sorted { $0.createdAt > $1.createdAt },
            devices: deviceRecords.compactMap { decodeDevice(from: $0, currentID: currentID) }
                .sorted { $0.lastActive > $1.lastActive },
            syncedAt: now
        )
    }

    func fetchDevices() async throws -> [ClipDevice] {
        let availability = await accountAvailability()
        guard availability == .available else {
            throw CloudSyncError.accountUnavailable(availability)
        }
        try await prepareZoneIfNeeded()
        let currentID = currentDeviceID
        return try await fetchRecords(ofType: RecordType.device)
            .compactMap { decodeDevice(from: $0, currentID: currentID) }
            .sorted { $0.lastActive > $1.lastActive }
    }

    func registerCurrentDevice() async throws -> [ClipDevice] {
        let availability = await accountAvailability()
        guard availability == .available else {
            throw CloudSyncError.accountUnavailable(availability)
        }
        try await prepareZoneIfNeeded()

        let currentID = currentDeviceID
        let currentRecordID = recordID(for: currentID)
        let result = try await database.records(for: [currentRecordID])
        let storedRecord: CKRecord?
        if case let .success(record)? = result[currentRecordID] {
            storedRecord = record
        } else {
            storedRecord = nil
        }
        if let storedRecord,
           (storedRecord[Field.syncEnabled] as? Int64) == 0 {
            throw CloudSyncError.deviceRestricted
        }

        let record = storedRecord
            ?? CKRecord(recordType: RecordType.device, recordID: currentRecordID)
        configureCurrentDeviceRecord(record, lastActive: .now)
        _ = try await database.save(record)
        return try await fetchDevices()
    }

    func setSyncEnabled(_ isEnabled: Bool, for deviceID: UUID) async throws {
        try await prepareZoneIfNeeded()
        let recordID = recordID(for: deviceID)
        let result = try await database.records(for: [recordID])
        guard case let .success(record)? = result[recordID] else { return }
        record[Field.syncEnabled] = (isEnabled ? 1 : 0) as CKRecordValue
        _ = try await database.save(record)
    }

    private func fetchRecords(ofType recordType: String) async throws -> [CKRecord] {
        try await prepareZoneIfNeeded()
        var recordsByID: [CKRecord.ID: CKRecord] = [:]
        var changeToken: CKServerChangeToken?
        var moreComing = true

        while moreComing {
            let response = try await database.recordZoneChanges(
                inZoneWith: zoneID,
                since: changeToken
            )
            for (recordID, result) in response.modificationResultsByID {
                if case let .success(modification) = result {
                    recordsByID[recordID] = modification.record
                }
            }
            for deletion in response.deletions {
                recordsByID.removeValue(forKey: deletion.recordID)
            }
            changeToken = response.changeToken
            moreComing = response.moreComing
        }

        return recordsByID.values.filter { $0.recordType == recordType }
    }

    private func encodeRecord(for clip: ClipItem, existingRecord: CKRecord? = nil) throws -> CKRecord {
        let id = recordID(for: clip.id)
        let record = existingRecord ?? CKRecord(recordType: RecordType.clip, recordID: id)
        record[Field.payload] = try encoder.encode(clip) as CKRecordValue
        return record
    }

    private func decodeClip(from record: CKRecord) throws -> ClipItem {
        guard let data = record[Field.payload] as? Data else {
            throw CocoaError(.coderReadCorrupt)
        }
        return try decoder.decode(ClipItem.self, from: data)
    }

    private func configureCurrentDeviceRecord(_ record: CKRecord, lastActive: Date) {
        record[Field.name] = UIDevice.current.name as CKRecordValue
        record[Field.kind] = currentDeviceKind.rawValue as CKRecordValue
        record[Field.lastActive] = lastActive as CKRecordValue
        if record[Field.syncEnabled] == nil {
            record[Field.syncEnabled] = 1 as CKRecordValue
        }
    }

    private func decodeDevice(from record: CKRecord, currentID: UUID) -> ClipDevice? {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let name = record[Field.name] as? String,
              let kindValue = record[Field.kind] as? String,
              let kind = DeviceKind(rawValue: kindValue),
              let lastActive = record[Field.lastActive] as? Date else { return nil }
        let isEnabled = (record[Field.syncEnabled] as? Int64) != 0
        return ClipDevice(
            id: id,
            name: name,
            kind: kind,
            lastActive: lastActive,
            syncState: isEnabled ? .synced : .local,
            isCurrentDevice: id == currentID,
            isSyncEnabled: isEnabled
        )
    }

    private var currentDeviceKind: DeviceKind {
        switch UIDevice.current.userInterfaceIdiom {
        case .pad: .tablet
        case .phone: .phone
        default: .mac
        }
    }

    private func prepareZoneIfNeeded() async throws {
        guard !hasPreparedZone else { return }
        _ = try await database.save(CKRecordZone(zoneID: zoneID))
        hasPreparedZone = true
    }

    private func recordID(for id: UUID) -> CKRecord.ID {
        CKRecord.ID(recordName: id.uuidString, zoneID: zoneID)
    }

    private func isLegacyBundledSample(_ clip: ClipItem) -> Bool {
        let signatures: Set<String> = [
            "developer.apple.com|https://developer.apple.com/design/human-interface-guidelines/",
            "Project launch checklist|Review accessibility, test offline mode, prepare App Store screenshots.",
            "Design review|clipspace-design-review.png",
            "API Key|sk-live-51N9xP3qZ7mK2",
            "ClipSpace Roadmap|ClipSpace-Roadmap.pdf",
            "SwiftUI documentation|https://developer.apple.com/documentation/swiftui"
        ]
        return signatures.contains("\(clip.title)|\(clip.content)")
    }

    private var currentDeviceID: UUID {
        if let value = defaults.string(forKey: "cloudSyncDeviceID"), let id = UUID(uuidString: value) {
            return id
        }
        let id = UUID()
        defaults.set(id.uuidString, forKey: "cloudSyncDeviceID")
        return id
    }

    private var previouslySyncedClipIDs: Set<UUID> {
        get {
            Set((defaults.stringArray(forKey: "cloudSyncClipIDs") ?? []).compactMap(UUID.init(uuidString:)))
        }
        set {
            defaults.set(newValue.map(\.uuidString), forKey: "cloudSyncClipIDs")
        }
    }
}
