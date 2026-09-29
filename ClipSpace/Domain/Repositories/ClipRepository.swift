//
//  ClipRepository.swift
//  ClipSpace
//
//  Created by Prabakaran Muthusamy on 27/09/26.
//

import Foundation

protocol ClipRepository: Sendable {
    func fetchClips() async throws -> [ClipItem]
    func setPinned(_ isPinned: Bool, for id: UUID) async throws
    func deleteClip(id: UUID) async throws
}

protocol ClipboardWriting: Sendable {
    @MainActor
    func copy(_ value: String)
}
