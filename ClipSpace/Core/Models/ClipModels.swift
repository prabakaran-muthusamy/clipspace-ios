//
//  ClipModels.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import Foundation

enum DateFormatterHelper {
    static func previewString(for date: Date, referenceDate now: Date = .now) -> String {
        let calendar = Calendar.autoupdatingCurrent
        let time = date.formatted(date: .omitted, time: .shortened)

        if calendar.isDate(date, inSameDayAs: now) {
            return String(localized: "Today at \(time)")
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return String(localized: "Yesterday at \(time)")
        }

        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

enum ClipKind: String, CaseIterable, Codable, Sendable {
    case text = "Text"
    case link = "Link"
    case image = "Image"
    case file = "File"

    var symbolName: String {
        switch self {
        case .text: "doc.text"
        case .link: "link"
        case .image: "photo"
        case .file: "doc"
        }
    }

}

enum ClipCategory: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case text = "Text"
    case link = "Links"
    case image = "Images"
    case file = "Files"

    var id: Self { self }

    var kind: ClipKind? {
        switch self {
        case .all: nil
        case .text: .text
        case .link: .link
        case .image: .image
        case .file: .file
        }
    }

    var symbolName: String {
        kind?.symbolName ?? "square.grid.2x2"
    }
}

enum SyncState: String, Codable, Sendable {
    case local = "On this device"
    case synced = "Synced"
    case pending = "Waiting to sync"
}

enum ClipSourceApp: String, CaseIterable, Codable, Identifiable, Sendable {
    case safari = "Safari"
    case notes = "Notes"
    case xcode = "Xcode"
    case photos = "Photos"
    case files = "Files"
    case unknown = "App"

    var id: Self { self }

    var symbolName: String {
        switch self {
        case .safari: "safari.fill"
        case .notes: "note.text"
        case .xcode: "hammer.fill"
        case .photos: "photo.on.rectangle.angled"
        case .files: "folder.fill"
        case .unknown: "app.fill"
        }
    }

    var assetName: String? {
        switch self {
        case .safari: "SourceSafari"
        case .notes: "SourceNotes"
        case .xcode: "SourceXcode"
        case .photos: "SourcePhotos"
        case .files: "SourceFiles"
        case .unknown: nil
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .safari: "com.apple.Safari"
        case .notes: "com.apple.Notes"
        case .xcode: "com.apple.dt.Xcode"
        case .photos: "com.apple.Photos"
        case .files: "com.apple.DocumentsApp"
        case .unknown: nil
        }
    }
}

struct ClipItem: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var title: String
    var content: String
    var kind: ClipKind
    var sourceDevice: String
    var sourceApp: ClipSourceApp = .unknown
    var createdAt: Date
    var updatedAt: Date = .now
    var byteCount: Int
    var syncState: SyncState
    var isPinned: Bool
    var isSensitive: Bool
    var isSuggestion: Bool

    var displayContent: String {
        isSensitive ? "••••••••••••••••" : content
    }

    func displayContent(maskingSensitiveContent: Bool) -> String {
        isSensitive && maskingSensitiveContent ? "••••••••••••••••" : content
    }

    var searchableText: String {
        [title, content, sourceDevice].joined(separator: " ").localizedLowercase
    }

    var webURL: URL? {
        guard kind == .link,
              let components = URLComponents(string: content.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else { return nil }
        return components.url
    }
}

enum DeviceKind: String, Codable, Sendable {
    case mac = "Mac"
    case phone = "iPhone"
    case tablet = "iPad"

    var symbolName: String {
        switch self {
        case .mac: "laptopcomputer"
        case .phone: "iphone"
        case .tablet: "ipad"
        }
    }
}

struct ClipDevice: Identifiable, Hashable, Sendable {
    let id: UUID
    let name: String
    let kind: DeviceKind
    let lastActive: Date
    let syncState: SyncState
    let isCurrentDevice: Bool
    var isSyncEnabled: Bool
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: Self { self }
}
