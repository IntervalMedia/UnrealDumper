import Foundation

public enum SDKTypeKind: String, Codable, CaseIterable {
    case `class`
    case `struct`
    case `enum`
}

public struct SDKPackageSummary: Codable, Hashable {
    public let enumCount: Int
    public let structCount: Int
    public let classCount: Int

    public init(enumCount: Int, structCount: Int, classCount: Int) {
        self.enumCount = enumCount
        self.structCount = structCount
        self.classCount = classCount
    }
}

public struct SDKField: Codable, Hashable, Identifiable {
    public var id: String {
        let offsetComponent = offsetBytes.map(String.init) ?? "unknown"
        return "\(name)#\(sourceOrder)#\(offsetComponent)"
    }

    public let name: String
    public let declaration: String
    public let typeName: String
    public let offsetBytes: UInt64?
    public let sizeBytes: UInt64?
    public let sourceOrder: Int
    public let isPadding: Bool

    public init(
        name: String,
        declaration: String,
        typeName: String,
        offsetBytes: UInt64? = nil,
        sizeBytes: UInt64? = nil,
        sourceOrder: Int = 0,
        isPadding: Bool = false
    ) {
        self.name = name
        self.declaration = declaration
        self.typeName = typeName
        self.offsetBytes = offsetBytes
        self.sizeBytes = sizeBytes
        self.sourceOrder = sourceOrder
        self.isPadding = isPadding
    }
}

public struct SDKType: Codable, Hashable, Identifiable {
    public var id: String { fullName }
    public let name: String
    public let fullName: String
    public let declaration: String
    public let body: String
    public let kind: SDKTypeKind
    public let objectLabel: String
    public let parentTypeName: String?
    public let sizeBytes: UInt64?
    public let inheritedSizeBytes: UInt64?
    public let fields: [SDKField]
    public let sourceOrder: Int

    public init(
        name: String,
        fullName: String,
        declaration: String,
        body: String,
        kind: SDKTypeKind,
        objectLabel: String,
        parentTypeName: String? = nil,
        sizeBytes: UInt64? = nil,
        inheritedSizeBytes: UInt64? = nil,
        fields: [SDKField] = [],
        sourceOrder: Int = 0
    ) {
        self.name = name
        self.fullName = fullName
        self.declaration = declaration
        self.body = body
        self.kind = kind
        self.objectLabel = objectLabel
        self.parentTypeName = parentTypeName
        self.sizeBytes = sizeBytes
        self.inheritedSizeBytes = inheritedSizeBytes
        self.fields = fields
        self.sourceOrder = sourceOrder
    }

    enum CodingKeys: String, CodingKey {
        case name
        case fullName
        case declaration
        case body
        case kind
        case objectLabel
        case parentTypeName
        case sizeBytes
        case inheritedSizeBytes
        case fields
        case sourceOrder
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        fullName = try container.decode(String.self, forKey: .fullName)
        declaration = try container.decode(String.self, forKey: .declaration)
        body = try container.decode(String.self, forKey: .body)
        kind = try container.decode(SDKTypeKind.self, forKey: .kind)
        objectLabel = try container.decodeIfPresent(String.self, forKey: .objectLabel) ?? kind.defaultObjectLabel
        parentTypeName = try container.decodeIfPresent(String.self, forKey: .parentTypeName)
        sizeBytes = try container.decodeIfPresent(UInt64.self, forKey: .sizeBytes)
        inheritedSizeBytes = try container.decodeIfPresent(UInt64.self, forKey: .inheritedSizeBytes)
        fields = try container.decodeIfPresent([SDKField].self, forKey: .fields) ?? []
        sourceOrder = try container.decodeIfPresent(Int.self, forKey: .sourceOrder) ?? 0
    }
}

public struct SDKPackage: Codable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let summary: SDKPackageSummary?
    public let sourceOrder: Int
    public var types: [SDKType]

    public init(name: String, summary: SDKPackageSummary? = nil, sourceOrder: Int = 0, types: [SDKType]) {
        self.name = name
        self.summary = summary
        self.sourceOrder = sourceOrder
        self.types = types
    }

    enum CodingKeys: String, CodingKey {
        case name
        case summary
        case sourceOrder
        case types
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        summary = try container.decodeIfPresent(SDKPackageSummary.self, forKey: .summary)
        sourceOrder = try container.decodeIfPresent(Int.self, forKey: .sourceOrder) ?? 0
        types = try container.decode([SDKType].self, forKey: .types)
    }

    public var enumCount: Int {
        summary?.enumCount ?? types.filter { $0.kind == .enum }.count
    }

    public var structCount: Int {
        summary?.structCount ?? types.filter { $0.kind == .struct }.count
    }

    public var classCount: Int {
        summary?.classCount ?? types.filter { $0.kind == .class }.count
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

private extension SDKTypeKind {
    var defaultObjectLabel: String {
        switch self {
        case .class:
            "Class"
        case .struct:
            "ScriptStruct"
        case .enum:
            "Enum"
        }
    }
}
