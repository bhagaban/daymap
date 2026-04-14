import Foundation

struct PersistedPayload: Codable {
    var tasks: [Task]
    var settings: AppSettings
    var scratchpad: Scratchpad
}

enum JSONTaskStore {
    private static var supportURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("Daymap", isDirectory: true)
    }

    private static var fileURL: URL {
        supportURL.appendingPathComponent("daymap.json", isDirectory: false)
    }

    static func load() -> PersistedPayload {
        do {
            try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return PersistedPayload(tasks: [], settings: .default, scratchpad: .empty)
            }
            let data = try Data(contentsOf: fileURL)
            // Backwards compatible decode for older payloads (before scratchpad existed).
            if let v2 = try? JSONDecoder().decode(PersistedPayload.self, from: data) {
                return v2
            }
            struct LegacyPayload: Codable {
                var tasks: [Task]
                var settings: AppSettings
            }
            if let legacy = try? JSONDecoder().decode(LegacyPayload.self, from: data) {
                return PersistedPayload(tasks: legacy.tasks, settings: legacy.settings, scratchpad: .empty)
            }
            return PersistedPayload(tasks: [], settings: .default, scratchpad: .empty)
        } catch {
            return PersistedPayload(tasks: [], settings: .default, scratchpad: .empty)
        }
    }

    static func save(_ payload: PersistedPayload) {
        do {
            try FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Intentionally quiet: local-first app should not crash on save failure
        }
    }
}
