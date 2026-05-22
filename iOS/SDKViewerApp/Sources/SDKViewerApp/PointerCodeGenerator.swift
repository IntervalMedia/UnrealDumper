import Foundation

public enum PointerCodeGenerator {
    public static func generateCPP(_ input: PointerChainInput) -> String {
        guard !input.offsets.isEmpty else {
            return "// No offsets were provided."
        }

        let offsets = input.offsets.map { String(format: "0x%llX", $0) }
        var lines: [String] = []
        lines.append("uintptr_t chain = static_cast<uintptr_t>(\(input.baseExpression));")

        if offsets.count > 1 {
            for offset in offsets.dropLast() {
                lines.append("chain = *reinterpret_cast<uintptr_t*>(chain + \(offset));")
            }
        }

        let lastOffset = offsets.last ?? "0x0"
        lines.append("auto \(input.resultName) = reinterpret_cast<\(input.resultType)*>(chain + \(lastOffset));")

        return lines.joined(separator: "\n")
    }
}
