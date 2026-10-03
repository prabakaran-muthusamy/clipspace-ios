import Foundation

actor LocalClipRepository: ClipRepository {
    private let fileURL: URL
    private var cachedClips: [ClipItem]?

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
    }

    func fetchClips() async throws -> [ClipItem] {
        try loadIfNeeded()
        return cachedClips ?? []
    }

    func addClip(_ clip: ClipItem) async throws {
        try loadIfNeeded()
        cachedClips?.append(clip)
        try persist()
    }

    func setPinned(_ isPinned: Bool, for id: UUID) async throws {
        try loadIfNeeded()
        guard let index = cachedClips?.firstIndex(where: { $0.id == id }) else { return }
        cachedClips?[index].isPinned = isPinned
        cachedClips?[index].updatedAt = .now
        try persist()
    }

    func deleteClip(id: UUID) async throws {
        try loadIfNeeded()
        cachedClips?.removeAll { $0.id == id }
        try persist()
    }

    func replaceClips(_ clips: [ClipItem]) async throws {
        cachedClips = clips
        try persist()
    }

    func clearClips(keepingPinned: Bool) async throws {
        try loadIfNeeded()
        cachedClips = keepingPinned ? cachedClips?.filter(\.isPinned) : []
        try persist()
    }

    func enforceHistoryLimit(_ limit: Int?) async throws {
        try loadIfNeeded()
        guard let limit, limit > 0, let clips = cachedClips else { return }
        let pinned = clips.filter(\.isPinned)
        let unpinned = clips
            .filter { !$0.isPinned }
            .sorted { $0.createdAt > $1.createdAt }
        let availableSlots = max(0, limit - pinned.count)
        cachedClips = (pinned + unpinned.prefix(availableSlots))
            .sorted { $0.createdAt > $1.createdAt }
        try persist()
    }

    private func loadIfNeeded() throws {
        guard cachedClips == nil else { return }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            cachedClips = []
            return
        }
        let data = try Data(contentsOf: fileURL)
        cachedClips = try JSONDecoder().decode([ClipItem].self, from: data)
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(cachedClips ?? [])
        try data.write(to: fileURL, options: .atomic)
    }

    nonisolated private static var defaultFileURL: URL {
        let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("ClipSpace", isDirectory: true)
            .appendingPathComponent("clips.json", isDirectory: false)
    }
}
