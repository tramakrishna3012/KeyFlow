import Foundation

struct SharedSnippet: Codable {
    let id: UUID
    let text: String
    let capturedAt: Date
}

struct SharedSnippetStore {
    private let directory: URL
    private let files = FileManager.default

    init() throws {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "KeyFlowShareGroup") as? String,
              !group.isEmpty,
              let container = FileManager.default.containerURL(
                  forSecurityApplicationGroupIdentifier: group
              ) else {
            throw CocoaError(.fileNoSuchFile)
        }
        directory = container.appendingPathComponent("SharedSnippets", isDirectory: true)
    }

    func add(_ text: String, id: UUID) throws {
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        var backupExcludedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try backupExcludedDirectory.setResourceValues(values)
        let snippet = SharedSnippet(id: id, text: text, capturedAt: Date())
        let data = try JSONEncoder().encode(snippet)
        try data.write(to: fileURL(for: id), options: [.atomic, .completeFileProtection])
    }

    func next() throws -> SharedSnippet? {
        let urls: [URL]
        do {
            urls = try files.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return nil
        }

        let candidates = urls.compactMap { url -> (URL, Date)? in
            guard url.pathExtension == "json",
                  UUID(uuidString: url.deletingPathExtension().lastPathComponent) != nil,
                  let metadata = try? url.resourceValues(forKeys: [.creationDateKey]) else {
                return nil
            }
            return (url, metadata.creationDate ?? .distantPast)
        }
        guard let oldest = candidates.min(by: { $0.1 < $1.1 }) else { return nil }
        let snippet = try JSONDecoder().decode(SharedSnippet.self, from: Data(contentsOf: oldest.0))
        guard fileURL(for: snippet.id) == oldest.0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return snippet
    }

    func remove(_ id: UUID) throws {
        do {
            try files.removeItem(at: fileURL(for: id))
        } catch let error as CocoaError where
            error.code == .fileNoSuchFile || error.code == .fileReadNoSuchFile {
            // Finishing the same import twice is harmless.
        }
    }

    private func fileURL(for id: UUID) -> URL {
        directory.appendingPathComponent(id.uuidString).appendingPathExtension("json")
    }
}
