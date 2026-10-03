//
//  ClipRepository.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import Foundation

protocol ClipRepository: Sendable {
    func fetchClips() async throws -> [ClipItem]
    func addClip(_ clip: ClipItem) async throws
    func setPinned(_ isPinned: Bool, for id: UUID) async throws
    func deleteClip(id: UUID) async throws
    func replaceClips(_ clips: [ClipItem]) async throws
    func clearClips(keepingPinned: Bool) async throws
    func enforceHistoryLimit(_ limit: Int?) async throws
}

protocol ClipboardWriting: Sendable {
    @MainActor
    func copy(_ value: String)
}
