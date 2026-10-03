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

actor CloudSyncService {
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

    init(container: CKContainer = .default(), defaults: UserDefaults = .standard) {
        self.container = container
        self.database = container.privateCloudDatabase
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

        let currentID = currentDeviceID
        var deviceRecords = try await fetchRecords(ofType: RecordType.device)
        if let record = deviceRecords.first(where: { $0.recordID.recordName == currentID.uuidString }),
           (record[Field.syncEnabled] as? Int64) == 0 {
            throw CloudSyncError.deviceRestricted
        }

        let now = Date()
        let currentRecord = deviceRecords.first(where: { $0.recordID.recordName == currentID.uuidString })
            ?? CKRecord(recordType: RecordType.device, recordID: CKRecord.ID(recordName: currentID.uuidString))
        configureCurrentDeviceRecord(currentRecord, lastActive: now)
        _ = try await database.save(currentRecord)

        let eligibleLocalClips = localClips.filter { includesSensitiveContent || !$0.isSensitive }
        let localIDs = Set(eligibleLocalClips.map(\.id))
        for deletedID in previouslySyncedClipIDs.subtracting(localIDs) {
            do {
                try await database.deleteRecord(withID: CKRecord.ID(recordName: deletedID.uuidString))
            } catch let error as CKError where error.code == .unknownItem {
                continue
            }
        }

        let cloudRecords = try await fetchRecords(ofType: RecordType.clip)
        let cloudClips = cloudRecords.compactMap { try? decodeClip(from: $0) }
            .filter { includesSensitiveContent || !$0.isSensitive }
        var merged = Dictionary(uniqueKeysWithValues: cloudClips.map { ($0.id, $0) })
        for clip in eligibleLocalClips {
            if let cloudClip = merged[clip.id], cloudClip.updatedAt > clip.updatedAt {
                continue
            }
            merged[clip.id] = clip
        }

        var synchronizedClips: [ClipItem] = []
        for var clip in merged.values {
            clip.syncState = .synced
            _ = try await database.save(try encodeRecord(for: clip))
            synchronizedClips.append(clip)
        }

        previouslySyncedClipIDs = Set(synchronizedClips.map(\.id))
        deviceRecords = try await fetchRecords(ofType: RecordType.device)
        return CloudSyncResult(
            clips: synchronizedClips.sorted { $0.createdAt > $1.createdAt },
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
        let currentID = currentDeviceID
        return try await fetchRecords(ofType: RecordType.device)
            .compactMap { decodeDevice(from: $0, currentID: currentID) }
            .sorted { $0.lastActive > $1.lastActive }
    }

    func setSyncEnabled(_ isEnabled: Bool, for deviceID: UUID) async throws {
        let recordID = CKRecord.ID(recordName: deviceID.uuidString)
        let result = try await database.records(for: [recordID])
        guard case let .success(record)? = result[recordID] else { return }
        record[Field.syncEnabled] = (isEnabled ? 1 : 0) as CKRecordValue
        _ = try await database.save(record)
    }

    private func fetchRecords(ofType recordType: String) async throws -> [CKRecord] {
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        var response = try await database.records(matching: query)
        var records = response.matchResults.compactMap { try? $0.1.get() }
        while let cursor = response.queryCursor {
            response = try await database.records(continuingMatchFrom: cursor)
            records.append(contentsOf: response.matchResults.compactMap { try? $0.1.get() })
        }
        return records
    }

    private func encodeRecord(for clip: ClipItem) throws -> CKRecord {
        let id = CKRecord.ID(recordName: clip.id.uuidString)
        let record = CKRecord(recordType: RecordType.clip, recordID: id)
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
