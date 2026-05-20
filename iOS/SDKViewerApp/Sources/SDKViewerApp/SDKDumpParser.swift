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
        var packagesByName: [String: [SDKType]] = [:]
        var currentPackageName = "Unknown"
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("// Package: ") {
                currentPackageName = String(line.dropFirst("// Package: ".count)).trimmingCharacters(in: .whitespaces)
                if packagesByName[currentPackageName] == nil {
                    packagesByName[currentPackageName] = []
                }
                index += 1
                continue
            }

            if line.hasPrefix("// Object: ") {
                let fullName = String(line.dropFirst("// Object: ".count)).trimmingCharacters(in: .whitespaces)
                var declarationLineIndex: Int?
                var probe = index + 1
                while probe < lines.count {
                    let candidate = lines[probe].trimmingCharacters(in: .whitespaces)
                    if let kind = parseKind(from: candidate),
                       parseTypeName(from: candidate, kind: kind) != nil {
                        declarationLineIndex = probe
                        break
                    }
                    if lines[probe].hasPrefix("// Object: ") || lines[probe].hasPrefix("// Package: ") {
                        break
                    }
                    probe += 1
                }

                guard let declarationLineIndex else {
                    index += 1
                    continue
                }
                let declarationLine = lines[declarationLineIndex].trimmingCharacters(in: .whitespaces)
                guard let kind = parseKind(from: declarationLine),
                      let typeName = parseTypeName(from: declarationLine, kind: kind) else {
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
                    fullName: fullName,
                    declaration: declarationLine,
                    body: body,
                    kind: kind
                )
                packagesByName[currentPackageName, default: []].append(type)
                index = cursor + 1
                continue
            }

            index += 1
        }

        return packagesByName
            .map { SDKPackage(name: $0.key, types: $0.value.sorted(by: { $0.name < $1.name })) }
            .sorted(by: { $0.name < $1.name })
    }

    private static func parseScriptFunctions(from text: String?) -> [ScriptFunction] {
        guard let text, !text.isEmpty else { return [] }

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

    private static func parseKind(from declaration: String) -> SDKTypeKind? {
        if declaration.hasPrefix("struct ") { return .struct }
        if declaration.hasPrefix("class ") { return .class }
        if declaration.hasPrefix("enum class ") { return .enum }
        return nil
    }

    private static func parseTypeName(from declaration: String, kind: SDKTypeKind) -> String? {
        let keyword: String = switch kind {
        case .class: "class "
        case .struct: "struct "
        case .enum: "enum class "
        }

        guard declaration.hasPrefix(keyword) else { return nil }
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
}
