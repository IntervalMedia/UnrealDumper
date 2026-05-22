import Foundation

public final class SDKProjectStore {
    public static let projectFileName = "project.json"
    public static let dumpFileName = "parsed_dump.json"

    private let rootURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(rootURL: URL) {
        self.rootURL = rootURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func ensureRootDirectory() throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    public func listProjects() throws -> [SDKProjectMetadata] {
        try ensureRootDirectory()
        let urls = try FileManager.default.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
        return try urls.compactMap { url in
            let projectURL = url.appendingPathComponent(Self.projectFileName)
            guard FileManager.default.fileExists(atPath: projectURL.path) else { return nil }
            let data = try Data(contentsOf: projectURL)
            return try decoder.decode(SDKProjectMetadata.self, from: data)
        }.sorted(by: { $0.name < $1.name })
    }

    public func createProject(named name: String) throws -> SDKProjectRecord {
        let sanitized = sanitizeProjectName(name)
        let projectURL = rootURL.appendingPathComponent(sanitized, isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let metadata = SDKProjectMetadata(name: sanitized, createdAt: Date())
        let record = SDKProjectRecord(metadata: metadata, dump: nil)
        try save(record: record)
        return record
    }

    public func save(record: SDKProjectRecord) throws {
        let projectURL = rootURL.appendingPathComponent(record.metadata.name, isDirectory: true)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let metadataData = try encoder.encode(record.metadata)
        try metadataData.write(to: projectURL.appendingPathComponent(Self.projectFileName), options: .atomic)

        if let dump = record.dump {
            let dumpData = try encoder.encode(dump)
            try dumpData.write(to: projectURL.appendingPathComponent(Self.dumpFileName), options: .atomic)
        }
    }

    public func loadProject(named name: String) throws -> SDKProjectRecord {
        let projectURL = rootURL.appendingPathComponent(name, isDirectory: true)
        let metadataData = try Data(contentsOf: projectURL.appendingPathComponent(Self.projectFileName))
        let metadata = try decoder.decode(SDKProjectMetadata.self, from: metadataData)

        let dumpURL = projectURL.appendingPathComponent(Self.dumpFileName)
        let dump: ParsedSDKDump?
        if FileManager.default.fileExists(atPath: dumpURL.path) {
            let data = try Data(contentsOf: dumpURL)
            dump = try decoder.decode(ParsedSDKDump.self, from: data)
        } else {
            dump = nil
        }

        return SDKProjectRecord(metadata: metadata, dump: dump)
    }

    public func projectDirectoryURL(for name: String) -> URL {
        rootURL.appendingPathComponent(name, isDirectory: true)
    }

    public func sanitizeProjectName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalid = CharacterSet.alphanumerics.union(.init(charactersIn: "-_"))
        let cleaned = trimmed.unicodeScalars.map { invalid.contains($0) ? Character($0) : "_" }
        let candidate = String(cleaned)
        return candidate.isEmpty ? "Project" : candidate
    }
}
