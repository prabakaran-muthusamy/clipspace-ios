//
//  ClipLibraryViewModel.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ClipLibraryViewModel {
    private(set) var clips: [ClipItem] = []
    private(set) var isLoading = false
    var query = ""
    var category: ClipCategory = .all
    var errorMessage: String?

    private let repository: any ClipRepository
    private let clipboard: any ClipboardWriting
    private let loadClips: LoadClipsUseCase
    private let filterClips = FilterClipsUseCase()

    init(repository: any ClipRepository, clipboard: any ClipboardWriting) {
        self.repository = repository
        self.clipboard = clipboard
        self.loadClips = LoadClipsUseCase(repository: repository)
    }

    var filteredClips: [ClipItem] {
        filterClips.execute(clips: clips, query: query, category: category)
    }

    var suggestions: [ClipItem] {
        filteredClips.filter(\.isSuggestion)
    }

    var recentClips: [ClipItem] {
        filteredClips.filter { !$0.isSuggestion }
    }

    var pinnedClips: [ClipItem] {
        filterClips.execute(clips: clips, query: query, category: category, pinnedOnly: true)
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            clips = try await loadClips.execute()
        } catch {
            errorMessage = "Clip history couldn’t be loaded."
        }
    }

    func copy(_ clip: ClipItem) {
        clipboard.copy(clip.content)
    }

    func addClip(
        title: String,
        content: String,
        kind: ClipKind,
        sourceApp: ClipSourceApp,
        isPinned: Bool,
        isSensitive: Bool
    ) async -> Bool {
        let excludedApps = Set(
            (UserDefaults.standard.string(forKey: "excludedSourceApps") ?? "")
                .split(separator: "|")
                .map(String.init)
        )
        guard !excludedApps.contains(sourceApp.rawValue) else {
            errorMessage = "\(sourceApp.rawValue) is excluded in Settings."
            return false
        }
        let clip = ClipItem(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            sourceDevice: "This Device",
            sourceApp: sourceApp,
            createdAt: .now,
            byteCount: content.utf8.count,
            syncState: .local,
            isPinned: isPinned,
            isSensitive: isSensitive,
            isSuggestion: false
        )

        do {
            try await repository.addClip(clip)
            try await repository.enforceHistoryLimit(configuredHistoryLimit)
            await load()
            return true
        } catch {
            errorMessage = "The clip couldn’t be added."
            return false
        }
    }

    func togglePin(_ clip: ClipItem) async {
        do {
            try await repository.setPinned(!clip.isPinned, for: clip.id)
            await load()
        } catch {
            errorMessage = "The pin couldn’t be updated."
        }
    }

    func delete(_ clip: ClipItem) async {
        do {
            try await repository.deleteClip(id: clip.id)
            await load()
        } catch {
            errorMessage = "The clip couldn’t be deleted."
        }
    }

    func setPinned(_ isPinned: Bool, clips: [ClipItem]) async {
        do {
            for clip in clips {
                try await repository.setPinned(isPinned, for: clip.id)
            }
            await load()
        } catch {
            errorMessage = "The selected clips couldn’t be updated."
        }
    }

    func delete(_ clips: [ClipItem]) async {
        do {
            for clip in clips {
                try await repository.deleteClip(id: clip.id)
            }
            await load()
        } catch {
            errorMessage = "The selected clips couldn’t be deleted."
        }
    }

    func clearHistory(keepingPinned: Bool) async -> Bool {
        do {
            try await repository.clearClips(keepingPinned: keepingPinned)
            await load()
            return true
        } catch {
            errorMessage = "Clip history couldn’t be cleared."
            return false
        }
    }

    func applyHistoryLimit(_ value: Int) async {
        do {
            try await repository.enforceHistoryLimit(value == 0 ? nil : value)
            await load()
        } catch {
            errorMessage = "The history limit couldn’t be applied."
        }
    }

    private var configuredHistoryLimit: Int? {
        guard UserDefaults.standard.object(forKey: "clipHistoryLimit") != nil else {
            return 1_000
        }
        let value = UserDefaults.standard.integer(forKey: "clipHistoryLimit")
        return value == 0 ? nil : value
    }
}
