import Foundation

public enum SDKTypeKind: String, Codable, CaseIterable {
    case `class`
    case `struct`
    case `enum`
}

public struct SDKType: Codable, Hashable, Identifiable {
    public var id: String { fullName }
    public let name: String
    public let fullName: String
    public let declaration: String
    public let body: String
    public let kind: SDKTypeKind

    public init(name: String, fullName: String, declaration: String, body: String, kind: SDKTypeKind) {
        self.name = name
        self.fullName = fullName
        self.declaration = declaration
        self.body = body
        self.kind = kind
    }
}

public struct SDKPackage: Codable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public var types: [SDKType]

    public init(name: String, types: [SDKType]) {
        self.name = name
        self.types = types
    }
}

public struct ScriptFunction: Codable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let address: UInt64

    public init(name: String, address: UInt64) {
        self.name = name
        self.address = address
    }
}

public struct ParsedSDKDump: Codable, Hashable {
    public let packages: [SDKPackage]
    public let scriptFunctions: [ScriptFunction]

    public init(packages: [SDKPackage], scriptFunctions: [ScriptFunction]) {
        self.packages = packages
        self.scriptFunctions = scriptFunctions
    }
}

public struct SDKProjectMetadata: Codable, Hashable {
    public let name: String
    public let createdAt: Date
    public var lastImportedAt: Date?
    public var sourceArchiveName: String?

    public init(name: String, createdAt: Date, lastImportedAt: Date? = nil, sourceArchiveName: String? = nil) {
        self.name = name
        self.createdAt = createdAt
        self.lastImportedAt = lastImportedAt
        self.sourceArchiveName = sourceArchiveName
    }
}

public struct SDKProjectRecord: Codable, Hashable {
    public var metadata: SDKProjectMetadata
    public var dump: ParsedSDKDump?

    public init(metadata: SDKProjectMetadata, dump: ParsedSDKDump? = nil) {
        self.metadata = metadata
        self.dump = dump
    }
}

public struct PointerChainInput: Codable, Hashable {
    public let baseExpression: String
    public let offsets: [UInt64]
    public let resultType: String
    public let resultName: String

    public init(baseExpression: String, offsets: [UInt64], resultType: String, resultName: String) {
        self.baseExpression = baseExpression
        self.offsets = offsets
        self.resultType = resultType
        self.resultName = resultName
    }
}
