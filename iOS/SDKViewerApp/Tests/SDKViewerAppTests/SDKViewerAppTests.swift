import Foundation
import Testing
@testable import SDKViewerApp

@Test func parsesPackagesAndTypesFromAIOHeader() throws {
    let sample = """
    // Package: CoreUObject
    // Enums: 1
    // Structs: 1
    // Classes: 1

    // Object: Enum /Script/CoreUObject.EObjectFlags
    enum class EObjectFlags : uint8_t
    {
        RF_NoFlags = 0
    };

    // Object: ScriptStruct /Script/CoreUObject.Vector
    // Size: 0xC (Inherited: 0x0)
    struct FVector
    {
        float X; // 0x0(0x4)
    };

    // Object: Class /Script/Engine.Actor
    // Size: 0x10 (Inherited: 0x8)
    struct AActor : UObject
    {
        int32_t Id; // 0x8(0x4)
    };
    """

    let parsed = try SDKDumpParser.parse(aioHeader: sample)
    #expect(parsed.packages.count == 1)
    #expect(parsed.packages.first?.name == "CoreUObject")
    #expect(parsed.packages.first?.types.count == 3)
}

@Test func parsesScriptJSONFunctions() throws {
    let aio = "// Package: Empty\n"
    let script = """
    {
      "Functions": [
        {"Name": "UObject$$ProcessInternal", "Address": 1234}
      ]
    }
    """

    let parsed = try SDKDumpParser.parse(aioHeader: aio, scriptJSON: script)
    #expect(parsed.scriptFunctions.count == 1)
    #expect(parsed.scriptFunctions.first?.name == "UObject$$ProcessInternal")
}

@Test func generatesMultiLevelPointerCode() {
    let input = PointerChainInput(
        baseExpression: "baseAddress",
        offsets: [0x30, 0x18, 0x8],
        resultType: "FVector",
        resultName: "locationPtr"
    )

    let code = PointerCodeGenerator.generateCPP(input)
    #expect(code.contains("reinterpret_cast<uintptr_t*>(chain + 0x30)"))
    #expect(code.contains("reinterpret_cast<uintptr_t*>(chain + 0x18)"))
    #expect(code.contains("reinterpret_cast<FVector*>(chain + 0x8)"))
}
