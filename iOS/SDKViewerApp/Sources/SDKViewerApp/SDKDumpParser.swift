import Foundation

public enum SDKDumpParserError: Error {
    case missingAIOHeader
}

public enum SDKDumpParser {
    public static func parse(aioHeader: String, scriptJSON: String? = nil) throws -> ParsedSDKDump {
        let packages = parsePackages(from: aioHeader)
        let functions = parseScriptFunctions(from: scriptJSON)
        return ParsedSDKDump(packages: packages, scriptFunctions: functions)
    }

    private static func parsePackages(from text: String) -> [SDKPackage] {
        let lines = text.components(separatedBy: .newlines)
        var packages: [PackageAccumulator] = []
        var currentPackageIndex: Int?
        var index = 0
        var sourceOrder = 0

        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("// Package: ") {
                let packageName = String(line.dropFirst("// Package: ".count)).trimmingCharacters(in: .whitespaces)
                let summaryResult = parsePackageSummary(in: lines, startingAt: index + 1)
                packages.append(
                    PackageAccumulator(
                        name: packageName,
                        summary: summaryResult.summary,
                        sourceOrder: packages.count
                    )
                )
                currentPackageIndex = packages.indices.last
                index = summaryResult.nextIndex
                continue
            }

            if let metadata = parseObjectMetadata(from: line) {
                var declarationLineIndex: Int?
                var sizeBytes: UInt64?
                var inheritedSizeBytes: UInt64?
                var probe = index + 1
                while probe < lines.count {
                    let candidate = lines[probe].trimmingCharacters(in: .whitespaces)

                    if let sizeMetadata = parseSizeMetadata(from: candidate) {
                        sizeBytes = sizeMetadata.sizeBytes
                        inheritedSizeBytes = sizeMetadata.inheritedSizeBytes
                    }

                    if parseDeclaredTypeName(from: candidate) != nil {
                        declarationLineIndex = probe
                        break
                    }
                    if lines[probe].hasPrefix("// Object: ") || lines[probe].hasPrefix("// Package: ") {
                        break
                    }
                    probe += 1
                }

                guard let declarationLineIndex = declarationLineIndex else {
                    index += 1
                    continue
                }
                let declarationLine = lines[declarationLineIndex].trimmingCharacters(in: .whitespaces)
                guard let typeName = parseDeclaredTypeName(from: declarationLine) else {
                    index += 1
                    continue
                }

                var bodyLines: [String] = [declarationLine]
                var cursor = declarationLineIndex + 1
                while cursor < lines.count {
                    let bodyLine = lines[cursor]
                    bodyLines.append(bodyLine)
                    if bodyLine.trimmingCharacters(in: .whitespacesAndNewlines) == "};" {
                        break
                    }
                    cursor += 1
                }

                let body = bodyLines.joined(separator: "\n")
                let type = SDKType(
                    name: typeName,
                    fullName: metadata.fullName,
                    declaration: declarationLine,
                    body: body,
                    kind: metadata.kind,
                    objectLabel: metadata.objectLabel,
                    parentTypeName: parseParentTypeName(from: declarationLine),
                    sizeBytes: sizeBytes,
                    inheritedSizeBytes: inheritedSizeBytes,
                    fields: parseFields(from: bodyLines),
                    sourceOrder: sourceOrder
                )
                sourceOrder += 1

                if currentPackageIndex == nil {
                    packages.append(PackageAccumulator(name: "Unknown", summary: nil, sourceOrder: packages.count))
                    currentPackageIndex = packages.indices.last
                }

                if let targetPackageIndex = currentPackageIndex {
                    packages[targetPackageIndex].types.append(type)
                }
                index = cursor + 1
                continue
            }

            index += 1
        }

        return packages.map { accumulator in
            SDKPackage(
                name: accumulator.name,
                summary: accumulator.summary,
                sourceOrder: accumulator.sourceOrder,
                types: accumulator.types
            )
        }
    }

    private static func parseScriptFunctions(from text: String?) -> [ScriptFunction] {
        guard let text = text, !text.isEmpty else { return [] }

        struct Root: Decodable {
            struct Entry: Decodable {
                let Name: String
                let Address: UInt64
            }

            let Functions: [Entry]?
        }

        guard let data = text.data(using: .utf8),
              let root = try? JSONDecoder().decode(Root.self, from: data),
              let entries = root.Functions else {
            return []
        }

        return entries.map { ScriptFunction(name: $0.Name, address: $0.Address) }
            .sorted(by: { $0.name < $1.name })
    }

    private static func parseDeclaredTypeName(from declaration: String) -> String? {
        for keyword in ["enum class ", "struct ", "class "] where declaration.hasPrefix(keyword) {
            var remainder = String(declaration.dropFirst(keyword.count))

            if let brace = remainder.firstIndex(of: "{") {
                remainder = String(remainder[..<brace])
            }
            if let colon = remainder.firstIndex(of: ":") {
                remainder = String(remainder[..<colon])
            }

            let cleaned = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? nil : cleaned
        }

        return nil
    }

    private static func parseParentTypeName(from declaration: String) -> String? {
        guard let colon = declaration.firstIndex(of: ":") else { return nil }
        let tailStart = declaration.index(after: colon)
        let tail = declaration[tailStart...]

        let clause: Substring
        if let brace = tail.firstIndex(of: "{") {
            clause = tail[..<brace]
        } else {
            clause = tail
        }

        let cleaned = clause
            .replacingOccurrences(of: "public ", with: "")
            .replacingOccurrences(of: "protected ", with: "")
            .replacingOccurrences(of: "private ", with: "")
            .replacingOccurrences(of: "virtual ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let parentClause = cleaned.split(separator: ",").first else {
            return nil
        }

        let parent = parentClause.trimmingCharacters(in: .whitespacesAndNewlines)
        return parent.isEmpty ? nil : parent
    }

    private static func parseObjectMetadata(from line: String) -> ObjectMetadata? {
        guard line.hasPrefix("// Object: ") else { return nil }
        let payload = String(line.dropFirst("// Object: ".count)).trimmingCharacters(in: .whitespaces)
        guard let separator = payload.firstIndex(of: " ") else { return nil }

        let objectLabel = String(payload[..<separator])
        let fullName = String(payload[payload.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        guard let kind = semanticKind(for: objectLabel) else { return nil }

        return ObjectMetadata(objectLabel: objectLabel, fullName: fullName, kind: kind)
    }

    private static func semanticKind(for objectLabel: String) -> SDKTypeKind? {
        switch objectLabel {
        case "Enum", "UserDefinedEnum":
            return .enum
        case "ScriptStruct", "UserDefinedStruct", "PropertyBag":
            return .struct
        case "Class",
             "BlueprintGeneratedClass",
             "WidgetBlueprintGeneratedClass",
             "AnimBlueprintGeneratedClass",
             "ControlRigBlueprintGeneratedClass",
             "DynamicClass",
             "LinkerPlaceholderClass",
             "AISenseBlueprintListener":
            return .class
        default:
            if objectLabel.hasSuffix("Class") || objectLabel.contains("Blueprint") {
                return .class
            }
            if objectLabel.contains("Struct") || objectLabel == "PropertyBag" {
                return .struct
            }
            if objectLabel.contains("Enum") {
                return .enum
            }
            return nil
        }
    }

    private static func parsePackageSummary(in lines: [String], startingAt startIndex: Int) -> (summary: SDKPackageSummary?, nextIndex: Int) {
        var enumCount: Int?
        var structCount: Int?
        var classCount: Int?
        var index = startIndex

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            if let count = parseCount(line, prefix: "// Enums: ") {
                enumCount = count
                index += 1
                continue
            }
            if let count = parseCount(line, prefix: "// Structs: ") {
                structCount = count
                index += 1
                continue
            }
            if let count = parseCount(line, prefix: "// Classes: ") {
                classCount = count
                index += 1
                continue
            }
            if line.isEmpty {
                index += 1
                continue
            }
            break
        }

        if let enumCount = enumCount,
           let structCount = structCount,
           let classCount = classCount {
            return (SDKPackageSummary(enumCount: enumCount, structCount: structCount, classCount: classCount), index)
        }

        return (nil, index)
    }

    private static func parseCount(_ line: String, prefix: String) -> Int? {
        guard line.hasPrefix(prefix) else { return nil }
        return Int(line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces))
    }

    private static func parseSizeMetadata(from line: String) -> SizeMetadata? {
        guard line.hasPrefix("// Size: ") else { return nil }
        let pattern = #"^// Size: 0x([0-9A-Fa-f]+) \(Inherited: 0x([0-9A-Fa-f]+)\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              match.numberOfRanges == 3,
              let sizeRange = Range(match.range(at: 1), in: line),
              let inheritedRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        return SizeMetadata(
            sizeBytes: UInt64(line[sizeRange], radix: 16),
            inheritedSizeBytes: UInt64(line[inheritedRange], radix: 16)
        )
    }

    private static func parseFields(from bodyLines: [String]) -> [SDKField] {
        var fields: [SDKField] = []

        for line in bodyLines {
            if let field = parseField(from: line, sourceOrder: fields.count) {
                fields.append(field)
            }
        }

        return fields
    }

    private static func parseField(from line: String, sourceOrder: Int) -> SDKField? {
        guard let commentRange = line.range(of: "//") else { return nil }

        let declarationWithSemicolon = line[..<commentRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let offsetComment = line[commentRange.lowerBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard declarationWithSemicolon.hasSuffix(";"),
              let offsetMatch = parseOffsetComment(offsetComment) else {
            return nil
        }

        let declaration = String(declarationWithSemicolon.dropLast())
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let split = splitFieldDeclaration(declaration) else {
            return nil
        }

        return SDKField(
            name: split.name,
            declaration: declaration,
            typeName: split.typeName,
            offsetBytes: offsetMatch.offsetBytes,
            sizeBytes: offsetMatch.sizeBytes,
            sourceOrder: sourceOrder,
            isPadding: split.name.hasPrefix("Pad_0x")
        )
    }

    private static func splitFieldDeclaration(_ declaration: String) -> (typeName: String, name: String)? {
        let pattern = #"^(.+?)\s+([A-Za-z_][A-Za-z0-9_]*)(\[[^\]]+\])?(?:\s*:\s*\d+)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(declaration.startIndex..<declaration.endIndex, in: declaration)
        guard let match = regex.firstMatch(in: declaration, range: range),
              match.numberOfRanges >= 3,
              let typeRange = Range(match.range(at: 1), in: declaration),
              let nameRange = Range(match.range(at: 2), in: declaration) else {
            return nil
        }

        return (
            typeName: String(declaration[typeRange]).trimmingCharacters(in: .whitespacesAndNewlines),
            name: String(declaration[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private static func parseOffsetComment(_ comment: String) -> (offsetBytes: UInt64, sizeBytes: UInt64)? {
        let pattern = #"^//\s*0x([0-9A-Fa-f]+)\(0x([0-9A-Fa-f]+)\)$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(comment.startIndex..<comment.endIndex, in: comment)
        guard let match = regex.firstMatch(in: comment, range: range),
              match.numberOfRanges == 3,
              let offsetRange = Range(match.range(at: 1), in: comment),
              let sizeRange = Range(match.range(at: 2), in: comment),
              let offsetBytes = UInt64(comment[offsetRange], radix: 16),
              let sizeBytes = UInt64(comment[sizeRange], radix: 16) else {
            return nil
        }

        return (offsetBytes, sizeBytes)
    }

    private struct PackageAccumulator {
        let name: String
        let summary: SDKPackageSummary?
        let sourceOrder: Int
        var types: [SDKType] = []
    }

    private struct ObjectMetadata {
        let objectLabel: String
        let fullName: String
        let kind: SDKTypeKind
    }

    private struct SizeMetadata {
        let sizeBytes: UInt64?
        let inheritedSizeBytes: UInt64?
    }
}
