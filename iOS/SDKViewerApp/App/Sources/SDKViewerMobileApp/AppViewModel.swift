import Foundation
import SwiftUI
import UniformTypeIdentifiers
#if canImport(ZIPFoundation)
import ZIPFoundation
#endif
#if canImport(SDKViewerApp)
import SDKViewerApp
#endif

struct TypeBrowserNode: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String?
    let type: SDKType?
    var children: [TypeBrowserNode]?
}

struct TypeFieldRow: Identifiable, Hashable {
    let field: SDKField
    let isWithinInheritedRegion: Bool

    var id: String { field.id }
}

struct TypeGraphSnapshot: Hashable {
    let selected: SDKType
    let ancestors: [SDKType]
    let children: [SDKType]
    let siblings: [SDKType]
    let descendantLayers: [[SDKType]]
    let depthLimit: Int
}

@MainActor
final class AppViewModel: ObservableObject {
    @Published var projects: [SDKProjectMetadata] = []
    @Published var currentProject: SDKProjectRecord?
    @Published var selectedPackage: SDKPackage?
    @Published var selectedType: SDKType?
    @Published var typeSearchText: String = ""
    @Published var pointerBaseExpression: String = "baseAddress"
    @Published var pointerOffsetsText: String = "0x0"
    @Published var pointerResultType: String = "uintptr_t"
    @Published var pointerResultName: String = "resultPtr"
    @Published var pointerOutput: String = ""
    @Published var errorMessage: String?

    let projectStore: SDKProjectStore

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let root = documents.appendingPathComponent("SDKViewerProjects", isDirectory: true)
        self.projectStore = SDKProjectStore(rootURL: root)
        reloadProjects()
    }

    func reloadProjects() {
        do {
            projects = try projectStore.listProjects()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createProject(named name: String) {
        do {
            currentProject = try projectStore.createProject(named: name)
            reloadProjects()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadProject(_ metadata: SDKProjectMetadata) {
        do {
            currentProject = try projectStore.loadProject(named: metadata.name)
            selectPackage(currentProject?.dump?.packages.first)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importDumpArchive(from url: URL) {
        guard var record = currentProject else { return }

        do {
            let projectDir = projectStore.projectDirectoryURL(for: record.metadata.name)
            let archiveURL = projectDir.appendingPathComponent("sdk_dump.zip")
            let extractedURL = projectDir.appendingPathComponent("sdk_dump", isDirectory: true)

            if FileManager.default.fileExists(atPath: extractedURL.path) {
                try FileManager.default.removeItem(at: extractedURL)
            }
            try FileManager.default.createDirectory(at: extractedURL, withIntermediateDirectories: true)

            if FileManager.default.fileExists(atPath: archiveURL.path) {
                try FileManager.default.removeItem(at: archiveURL)
            }
            try FileManager.default.copyItem(at: url, to: archiveURL)

            try unzip(archiveURL: archiveURL, destinationURL: extractedURL)

            let aioURL = extractedURL.appendingPathComponent("AIOHeader.hpp")
            let scriptURL = extractedURL.appendingPathComponent("script.json")

            let aioText = try String(contentsOf: aioURL, encoding: .utf8)
            let scriptText = FileManager.default.fileExists(atPath: scriptURL.path)
                ? try String(contentsOf: scriptURL, encoding: .utf8)
                : nil

            let parsed = try SDKDumpParser.parse(aioHeader: aioText, scriptJSON: scriptText)
            record.metadata.lastImportedAt = Date()
            record.metadata.sourceArchiveName = archiveURL.lastPathComponent
            record.dump = parsed
            try projectStore.save(record: record)

            currentProject = record
            selectPackage(parsed.packages.first)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generatePointerCode() {
        let offsets = pointerOffsetsText
            .split(separator: ",")
            .compactMap { parseOffset(String($0)) }

        let input = PointerChainInput(
            baseExpression: pointerBaseExpression,
            offsets: offsets,
            resultType: pointerResultType,
            resultName: pointerResultName
        )

        pointerOutput = PointerCodeGenerator.generateCPP(input)
    }

    func closeProject() {
        currentProject = nil
        selectedPackage = nil
        selectedType = nil
        typeSearchText = ""
    }

    func selectPackage(_ package: SDKPackage?) {
        selectedPackage = package
        typeSearchText = ""
        selectedType = firstType(in: package)
    }

    func selectType(_ type: SDKType?) {
        selectedType = type
        if let type = type, let package = package(containing: type) {
            selectedPackage = package
        }
    }

    func browserNodes(for package: SDKPackage) -> [TypeBrowserNode] {
        let sections: [(title: String, count: Int, types: [SDKType], supportsInheritance: Bool)] = [
            ("Enums", package.enumCount, package.types.filter { $0.kind == .enum }, false),
            ("Structs", package.structCount, package.types.filter { $0.kind == .struct }, true),
            ("Classes", package.classCount, package.types.filter { $0.kind == .class }, true)
        ]

        return sections.compactMap { section in
            guard !section.types.isEmpty else { return nil }
            return TypeBrowserNode(
                id: "group:\(package.name):\(section.title)",
                title: section.title,
                detail: "\(section.count)",
                type: nil,
                children: section.supportsInheritance ? buildInheritanceTree(for: section.types) : section.types.map { makeLeafNode(for: $0) }
            )
        }
    }

    func filteredBrowserNodes(for package: SDKPackage) -> [TypeBrowserNode] {
        let query = typeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return browserNodes(for: package)
        }

        let loweredQuery = query.lowercased()
        return browserNodes(for: package).compactMap { filter(node: $0, query: loweredQuery) }
    }

    func fieldRows(for type: SDKType) -> [TypeFieldRow] {
        let inheritedLimit = type.inheritedSizeBytes ?? 0
        return type.fields
            .sorted { lhs, rhs in
                if lhs.offsetBytes != rhs.offsetBytes {
                    return (lhs.offsetBytes ?? .max) < (rhs.offsetBytes ?? .max)
                }
                return lhs.sourceOrder < rhs.sourceOrder
            }
            .map {
                TypeFieldRow(
                    field: $0,
                    isWithinInheritedRegion: ($0.offsetBytes ?? .max) < inheritedLimit
                )
            }
    }

    func graphSnapshot(for type: SDKType, depth: Int = 2) -> TypeGraphSnapshot {
        let allTypes = allTypesInDump()
        let typesByName = Dictionary(allTypes.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        let clampedDepth = min(max(depth, 1), 4)

        var ancestors: [SDKType] = []
        var visitedNames: Set<String> = [type.name]
        var currentParentName = type.parentTypeName
        while let parentName = currentParentName,
              let parent = typesByName[parentName],
              !visitedNames.contains(parent.name) {
            ancestors.insert(parent, at: 0)
            visitedNames.insert(parent.name)
            currentParentName = parent.parentTypeName
        }

        let children = allTypes
            .filter { $0.parentTypeName == type.name && $0.fullName != type.fullName }
            .sorted(by: typeSort(lhs:rhs:))

        var descendantLayers: [[SDKType]] = []
        var currentLayer = children
        var visitedDescendants = Set(children.map(\.fullName))
        var remainingDepth = clampedDepth
        while !currentLayer.isEmpty && remainingDepth > 0 {
            descendantLayers.append(currentLayer)
            remainingDepth -= 1

            guard remainingDepth > 0 else { break }

            let parentNames = Set(currentLayer.map(\.name))
            let nextLayer = allTypes
                .filter {
                    guard let parentTypeName = $0.parentTypeName else { return false }
                    return parentNames.contains(parentTypeName)
                        && $0.fullName != type.fullName
                        && !visitedDescendants.contains($0.fullName)
                }
                .sorted(by: typeSort(lhs:rhs:))

            for descendant in nextLayer {
                visitedDescendants.insert(descendant.fullName)
            }
            currentLayer = nextLayer
        }

        let siblings: [SDKType]
        if let parentName = type.parentTypeName {
            siblings = allTypes
                .filter { $0.parentTypeName == parentName && $0.fullName != type.fullName }
                .sorted(by: typeSort(lhs:rhs:))
        } else {
            siblings = []
        }

        return TypeGraphSnapshot(
            selected: type,
            ancestors: ancestors,
            children: children,
            siblings: siblings,
            descendantLayers: descendantLayers,
            depthLimit: clampedDepth
        )
    }

    func package(containing type: SDKType) -> SDKPackage? {
        currentProject?.dump?.packages.first(where: { package in
            package.types.contains(where: { $0.fullName == type.fullName })
        })
    }

    func packageSummaryText(for package: SDKPackage) -> String {
        "\(package.enumCount) enums · \(package.structCount) structs · \(package.classCount) classes"
    }

    private func parseOffset(_ raw: String) -> UInt64? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("0x") {
            return UInt64(trimmed.dropFirst(2), radix: 16)
        }
        return UInt64(trimmed)
    }

    private func unzip(archiveURL: URL, destinationURL: URL) throws {
        #if canImport(ZIPFoundation)
        guard let archive = Archive(url: archiveURL, accessMode: .read) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        for entry in archive {
            let outputURL = destinationURL.appendingPathComponent(entry.path)
            let standardizedDest = destinationURL.standardizedFileURL.path
            let standardizedOut = outputURL.standardizedFileURL.path
            guard standardizedOut.hasPrefix(standardizedDest) else {
                continue
            }

            let parentURL = outputURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentURL, withIntermediateDirectories: true)
            _ = try archive.extract(entry, to: outputURL)
        }
        #else
        let ok = SSZipArchive.unzipFile(atPath: archiveURL.path, toDestination: destinationURL.path)
        if !ok {
            throw CocoaError(.fileReadCorruptFile)
        }
        #endif
    }

    private func firstType(in package: SDKPackage?) -> SDKType? {
        guard let package = package else { return nil }

        for node in filteredBrowserNodes(for: package) {
            if let type = firstType(in: node) {
                return type
            }
        }

        return nil
    }

    private func firstType(in node: TypeBrowserNode) -> SDKType? {
        if let type = node.type {
            return type
        }

        for child in node.children ?? [] {
            if let type = firstType(in: child) {
                return type
            }
        }

        return nil
    }

    private func buildInheritanceTree(for types: [SDKType]) -> [TypeBrowserNode] {
        let sortedTypes = types.enumerated().sorted { lhs, rhs in
            if lhs.element.sourceOrder != rhs.element.sourceOrder {
                return lhs.element.sourceOrder < rhs.element.sourceOrder
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
        let names = Set(sortedTypes.map(\.name))
        var childrenByParent: [String: [SDKType]] = [:]
        var roots: [SDKType] = []

        for type in sortedTypes {
            if let parent = type.parentTypeName, names.contains(parent), parent != type.name {
                childrenByParent[parent, default: []].append(type)
            } else {
                roots.append(type)
            }
        }

        return roots.map { makeNode(for: $0, childrenByParent: childrenByParent) }
    }

    private func makeNode(for type: SDKType, childrenByParent: [String: [SDKType]]) -> TypeBrowserNode {
        let children = (childrenByParent[type.name] ?? []).map { makeNode(for: $0, childrenByParent: childrenByParent) }
        return TypeBrowserNode(
            id: type.id,
            title: type.name,
            detail: type.parentTypeName,
            type: type,
            children: children.isEmpty ? nil : children
        )
    }

    private func makeLeafNode(for type: SDKType) -> TypeBrowserNode {
        TypeBrowserNode(
            id: type.id,
            title: type.name,
            detail: nil,
            type: type,
            children: nil
        )
    }

    private func filter(node: TypeBrowserNode, query: String) -> TypeBrowserNode? {
        let filteredChildren = node.children?.compactMap { filter(node: $0, query: query) }
        let matchesNode = node.title.lowercased().contains(query)
            || (node.detail?.lowercased().contains(query) ?? false)
            || (node.type?.fullName.lowercased().contains(query) ?? false)
            || (node.type?.objectLabel.lowercased().contains(query) ?? false)

        guard matchesNode || !(filteredChildren?.isEmpty ?? true) else {
            return nil
        }

        return TypeBrowserNode(
            id: node.id,
            title: node.title,
            detail: node.detail,
            type: node.type,
            children: filteredChildren
        )
    }

    private func allTypesInDump() -> [SDKType] {
        let packages = currentProject?.dump?.packages ?? []
        return packages.flatMap { $0.types }
    }

    private func typeSort(lhs: SDKType, rhs: SDKType) -> Bool {
        if lhs.sourceOrder != rhs.sourceOrder {
            return lhs.sourceOrder < rhs.sourceOrder
        }
        return lhs.name < rhs.name
    }
}
