//
//  ClipUseCases.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import Foundation

struct LoadClipsUseCase: Sendable {
    let repository: any ClipRepository

    func execute() async throws -> [ClipItem] {
        try await repository.fetchClips()
            .sorted { $0.createdAt > $1.createdAt }
    }
}

struct FilterClipsUseCase: Sendable {
    func execute(
        clips: [ClipItem],
        query: String,
        category: ClipCategory,
        pinnedOnly: Bool = false
    ) -> [ClipItem] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
        return clips.filter { clip in
            let matchesCategory = category.kind.map { clip.kind == $0 } ?? true
            let matchesPin = !pinnedOnly || clip.isPinned
            let matchesQuery = normalizedQuery.isEmpty || clip.searchableText.contains(normalizedQuery)
            return matchesCategory && matchesPin && matchesQuery
        }
    }
}
