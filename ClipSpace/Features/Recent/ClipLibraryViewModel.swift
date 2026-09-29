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
}
