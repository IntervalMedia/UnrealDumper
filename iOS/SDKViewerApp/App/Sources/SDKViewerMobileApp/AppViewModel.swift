import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation
import SDKViewerApp

@MainActor
final class AppViewModel: ObservableObject {
    @Published var projects: [SDKProjectMetadata] = []
    @Published var currentProject: SDKProjectRecord?
    @Published var selectedPackage: SDKPackage?
    @Published var selectedType: SDKType?
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
            selectedPackage = currentProject?.dump?.packages.first
            selectedType = selectedPackage?.types.first
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
            selectedPackage = parsed.packages.first
            selectedType = selectedPackage?.types.first
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
    }

    private func parseOffset(_ raw: String) -> UInt64? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("0x") {
            return UInt64(trimmed.dropFirst(2), radix: 16)
        }
        return UInt64(trimmed)
    }

    private func unzip(archiveURL: URL, destinationURL: URL) throws {
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
    }
}
