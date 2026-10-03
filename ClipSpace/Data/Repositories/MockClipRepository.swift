//
//  MockClipRepository.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import Foundation
import UIKit

actor MockClipRepository: ClipRepository {
    private var clips: [ClipItem] = MockClipRepository.samples

    func fetchClips() async throws -> [ClipItem] {
        clips
    }

    func addClip(_ clip: ClipItem) async throws {
        clips.append(clip)
    }

    func setPinned(_ isPinned: Bool, for id: UUID) async throws {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].isPinned = isPinned
        clips[index].updatedAt = .now
    }

    func deleteClip(id: UUID) async throws {
        clips.removeAll { $0.id == id }
    }

    func replaceClips(_ clips: [ClipItem]) async throws {
        self.clips = clips
    }

    func clearClips(keepingPinned: Bool) async throws {
        clips = keepingPinned ? clips.filter(\.isPinned) : []
    }

    func enforceHistoryLimit(_ limit: Int?) async throws {
        guard let limit, limit > 0 else { return }
        let pinned = clips.filter(\.isPinned)
        let availableSlots = max(0, limit - pinned.count)
        clips = (pinned + clips.filter { !$0.isPinned }.prefix(availableSlots))
            .sorted { $0.createdAt > $1.createdAt }
    }

    nonisolated private static let samples: [ClipItem] = [
        ClipItem(id: UUID(), title: "developer.apple.com", content: "https://developer.apple.com/design/human-interface-guidelines/", kind: .link, sourceDevice: "MacBook Pro", sourceApp: .safari, createdAt: .now.addingTimeInterval(-120), byteCount: 68, syncState: .synced, isPinned: false, isSensitive: false, isSuggestion: true),
        ClipItem(id: UUID(), title: "Project launch checklist", content: "Review accessibility, test offline mode, prepare App Store screenshots.", kind: .text, sourceDevice: "iPhone", sourceApp: .notes, createdAt: .now.addingTimeInterval(-540), byteCount: 71, syncState: .synced, isPinned: true, isSensitive: false, isSuggestion: false),
        ClipItem(id: UUID(), title: "Design review", content: "clipspace-design-review.png", kind: .image, sourceDevice: "iPad", sourceApp: .photos, createdAt: .now.addingTimeInterval(-2_400), byteCount: 2_430_000, syncState: .local, isPinned: false, isSensitive: false, isSuggestion: false),
        ClipItem(id: UUID(), title: "API Key", content: "sk-live-51N9xP3qZ7mK2", kind: .text, sourceDevice: "MacBook Pro", sourceApp: .xcode, createdAt: .now.addingTimeInterval(-5_400), byteCount: 22, syncState: .local, isPinned: true, isSensitive: true, isSuggestion: false),
        ClipItem(id: UUID(), title: "ClipSpace Roadmap", content: "ClipSpace-Roadmap.pdf", kind: .file, sourceDevice: "MacBook Pro", sourceApp: .files, createdAt: .now.addingTimeInterval(-9_000), byteCount: 860_000, syncState: .pending, isPinned: false, isSensitive: false, isSuggestion: false),
        ClipItem(id: UUID(), title: "SwiftUI documentation", content: "https://developer.apple.com/documentation/swiftui", kind: .link, sourceDevice: "iPhone", sourceApp: .safari, createdAt: .now.addingTimeInterval(-86_400), byteCount: 48, syncState: .synced, isPinned: true, isSensitive: false, isSuggestion: false)
    ]
}

struct SystemClipboardWriter: ClipboardWriting {
    @MainActor
    func copy(_ value: String) {
        UIPasteboard.general.string = value
    }
}
