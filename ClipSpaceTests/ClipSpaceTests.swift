//
//  ClipSpaceTests.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import Foundation
import Testing
@testable import ClipSpace

private struct TestClipboardWriter: ClipboardWriting {
    @MainActor
    func copy(_ value: String) { }
}

@MainActor
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

    @Test func historyLimitKeepsPinnedAndNewestUnpinnedClips() async throws {
        let repository = LocalClipRepository(fileURL: temporaryStoreURL())
        let oldest = makeClip(
            title: "Oldest",
            content: "1",
            device: "iPhone",
            kind: .text,
            createdAt: .now.addingTimeInterval(-300)
        )
        let newest = makeClip(
            title: "Newest",
            content: "2",
            device: "iPhone",
            kind: .text,
            createdAt: .now
        )
        let pinned = makeClip(
            title: "Pinned",
            content: "3",
            device: "iPhone",
            kind: .text,
            isPinned: true,
            createdAt: .now.addingTimeInterval(-600)
        )
        try await repository.replaceClips([oldest, newest, pinned])

        try await repository.enforceHistoryLimit(2)

        let clips = try await repository.fetchClips()
        #expect(Set(clips.map(\.title)) == ["Newest", "Pinned"])
    }

    @Test func clearHistoryCanPreservePinnedClips() async throws {
        let repository = LocalClipRepository(fileURL: temporaryStoreURL())
        let regular = makeClip(title: "Regular", content: "1", device: "iPhone", kind: .text)
        let pinned = makeClip(
            title: "Pinned",
            content: "2",
            device: "iPhone",
            kind: .text,
            isPinned: true
        )
        try await repository.replaceClips([regular, pinned])

        try await repository.clearClips(keepingPinned: true)

        let clips = try await repository.fetchClips()
        #expect(clips.map(\.title) == ["Pinned"])
    }

    @Test func repositoryAddsPinsAndDeletesClip() async throws {
        let repository = LocalClipRepository(fileURL: temporaryStoreURL())
        let clip = makeClip(title: "Saved", content: "Value", device: "iPhone", kind: .text)

        try await repository.addClip(clip)
        #expect(try await repository.fetchClips().map(\.id) == [clip.id])

        try await repository.setPinned(true, for: clip.id)
        #expect(try await repository.fetchClips().first?.isPinned == true)

        try await repository.deleteClip(id: clip.id)
        #expect(try await repository.fetchClips().isEmpty)
    }

    @Test func malformedPersistenceDataThrowsWithoutOverwritingFile() async throws {
        let url = temporaryStoreURL()
        let malformed = Data("not-json".utf8)
        try malformed.write(to: url, options: .atomic)
        let repository = LocalClipRepository(fileURL: url)

        await #expect(throws: DecodingError.self) {
            _ = try await repository.fetchClips()
        }
        #expect(try Data(contentsOf: url) == malformed)
    }

    @Test func linkValidationAllowsOnlyHTTPAndHTTPSWithHosts() {
        let https = makeClip(title: "Web", content: "https://example.com/path", device: "iPhone", kind: .link)
        let customScheme = makeClip(title: "Unsafe", content: "shortcuts://run-shortcut", device: "iPhone", kind: .link)
        let malformed = makeClip(title: "Malformed", content: "https://", device: "iPhone", kind: .link)

        #expect(https.webURL?.host == "example.com")
        #expect(customScheme.webURL == nil)
        #expect(malformed.webURL == nil)
    }

    @Test func excludedSourcePreventsSaving() async {
        let suiteName = "ClipSpaceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(ClipSourceApp.safari.rawValue, forKey: "excludedSourceApps")

        let repository = MockClipRepository()
        let model = ClipLibraryViewModel(
            repository: repository,
            clipboard: TestClipboardWriter(),
            defaults: defaults
        )

        let didSave = await model.addClip(
            title: "Blocked",
            content: "https://example.com",
            kind: .link,
            sourceApp: .safari,
            isPinned: false,
            isSensitive: false
        )

        #expect(!didSave)
        #expect(model.errorMessage == "Safari is excluded in Settings.")
    }

    @Test func sensitiveSyncPreferencePersists() {
        let suiteName = "ClipSpaceTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            Issue.record("Could not create isolated defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let repository = MockClipRepository()
        let model = DeviceSyncViewModel(repository: repository, defaults: defaults)

        model.setIncludesSensitiveContent(true)

        let restored = DeviceSyncViewModel(repository: repository, defaults: defaults)
        #expect(restored.includesSensitiveContent)
    }

    private func makeClip(
        title: String,
        content: String,
        device: String,
        kind: ClipKind,
        isPinned: Bool = false,
        isSensitive: Bool = false,
        createdAt: Date = .now
    ) -> ClipItem {
        ClipItem(
            id: UUID(),
            title: title,
            content: content,
            kind: kind,
            sourceDevice: device,
            createdAt: createdAt,
            byteCount: content.utf8.count,
            syncState: .local,
            isPinned: isPinned,
            isSensitive: isSensitive,
            isSuggestion: false
        )
    }

    private func temporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }
}
