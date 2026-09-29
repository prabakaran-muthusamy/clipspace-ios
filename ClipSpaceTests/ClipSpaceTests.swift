//
//  ClipSpaceTests.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import Foundation
import Testing
@testable import ClipSpace

struct ClipSpaceTests {
    private let filter = FilterClipsUseCase()

    @Test func filtersByQueryAcrossTitleContentAndDevice() {
        let clips = [
            makeClip(title: "Apple Design", content: "Human Interface Guidelines", device: "MacBook Pro", kind: .link),
            makeClip(title: "Meeting", content: "Quarterly notes", device: "iPhone", kind: .text)
        ]

        #expect(filter.execute(clips: clips, query: "macbook", category: .all).map(\.title) == ["Apple Design"])
        #expect(filter.execute(clips: clips, query: "quarterly", category: .all).map(\.title) == ["Meeting"])
    }

    @Test func filtersByCategoryAndPinnedState() {
        let clips = [
            makeClip(title: "Pinned text", content: "Keep me", device: "iPhone", kind: .text, isPinned: true),
            makeClip(title: "Image", content: "photo.png", device: "iPad", kind: .image)
        ]

        let result = filter.execute(clips: clips, query: "", category: .text, pinnedOnly: true)
        #expect(result.count == 1)
        #expect(result.first?.title == "Pinned text")
    }

    @Test func sensitiveContentIsMaskedByDefault() {
        let clip = makeClip(
            title: "API Key",
            content: "secret-value",
            device: "MacBook Pro",
            kind: .text,
            isSensitive: true
        )

        #expect(clip.displayContent == "••••••••••••••••")
        #expect(clip.displayContent.contains("secret-value") == false)
    }

    private func makeClip(
        title: String,
        content: String,
        device: String,
        kind: ClipKind,
        isPinned: Bool = false,
        isSensitive: Bool = false
    ) -> ClipItem {
        ClipItem(
            id: UUID(),
            title: title,
            content: content,
            kind: kind,
            sourceDevice: device,
            createdAt: .now,
            byteCount: content.utf8.count,
            syncState: .local,
            isPinned: isPinned,
            isSensitive: isSensitive,
            isSuggestion: false
        )
    }
}
