import Foundation
import XCTest
@testable import SDKViewerApp

final class SDKViewerAppTests: XCTestCase {
    func testParsesPackagesAndTypesFromAIOHeader() throws {
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
        XCTAssertEqual(parsed.packages.count, 1)
        XCTAssertEqual(parsed.packages.first?.name, "CoreUObject")
        XCTAssertEqual(parsed.packages.first?.types.count, 3)
        XCTAssertEqual(parsed.packages.first?.summary?.enumCount, 1)
        XCTAssertEqual(parsed.packages.first?.summary?.structCount, 1)
        XCTAssertEqual(parsed.packages.first?.summary?.classCount, 1)
    }

    func testParsesScriptJSONFunctions() throws {
        let aio = "// Package: Empty\n"
        let script = """
        {
          "Functions": [
            {"Name": "UObject$$ProcessInternal", "Address": 1234}
          ]
        }
        """

        let parsed = try SDKDumpParser.parse(aioHeader: aio, scriptJSON: script)
        XCTAssertEqual(parsed.scriptFunctions.count, 1)
        XCTAssertEqual(parsed.scriptFunctions.first?.name, "UObject$$ProcessInternal")
    }

    func testGeneratesMultiLevelPointerCode() {
        let input = PointerChainInput(
            baseExpression: "baseAddress",
            offsets: [0x30, 0x18, 0x8],
            resultType: "FVector",
            resultName: "locationPtr"
        )

        let code = PointerCodeGenerator.generateCPP(input)
        XCTAssertTrue(code.contains("reinterpret_cast<uintptr_t*>(chain + 0x30)"))
        XCTAssertTrue(code.contains("reinterpret_cast<uintptr_t*>(chain + 0x18)"))
        XCTAssertTrue(code.contains("reinterpret_cast<FVector*>(chain + 0x8)"))
    }

    func testUsesObjectMetadataForClassKindAndInheritance() throws {
        let sample = """
        // Package: Engine
        // Enums: 0
        // Structs: 1
        // Classes: 2

        // Object: ScriptStruct Engine.Vector
        // Size: 0xC (Inherited: 0x0)
        struct FVector
        {
        };

        // Object: Class Engine.Actor
        // Size: 0x10 (Inherited: 0x8)
        struct AActor : UObject
        {
        };

        // Object: WidgetBlueprintGeneratedClass Engine.ActorWidget
        // Size: 0x18 (Inherited: 0x10)
        struct UActorWidget : AActor
        {
        };
        """

        let parsed = try SDKDumpParser.parse(aioHeader: sample)
        let package = try XCTUnwrap(parsed.packages.first)
        let actor = try XCTUnwrap(package.types.first(where: { $0.name == "AActor" }))
        let widget = try XCTUnwrap(package.types.first(where: { $0.name == "UActorWidget" }))
        let vector = try XCTUnwrap(package.types.first(where: { $0.name == "FVector" }))

        XCTAssertEqual(actor.kind, .class)
        XCTAssertEqual(actor.objectLabel, "Class")
        XCTAssertEqual(actor.parentTypeName, "UObject")
        XCTAssertEqual(actor.sizeBytes, 0x10)
        XCTAssertEqual(actor.inheritedSizeBytes, 0x8)

        XCTAssertEqual(widget.kind, .class)
        XCTAssertEqual(widget.objectLabel, "WidgetBlueprintGeneratedClass")
        XCTAssertEqual(widget.parentTypeName, "AActor")

        XCTAssertEqual(vector.kind, .struct)
        XCTAssertEqual(vector.objectLabel, "ScriptStruct")
    }

    func testPreservesDocumentOrderWithinPackage() throws {
        let sample = """
        // Package: CoreUObject
        // Enums: 1
        // Structs: 1
        // Classes: 1

        // Object: Enum CoreUObject.FirstEnum
        enum class EFirstEnum : uint8_t
        {
            Value = 0
        };

        // Object: ScriptStruct CoreUObject.SecondStruct
        struct FSecondStruct
        {
        };

        // Object: Class CoreUObject.ThirdClass
        struct UThirdClass : UObject
        {
        };
        """

        let parsed = try SDKDumpParser.parse(aioHeader: sample)
        let package = try XCTUnwrap(parsed.packages.first)
        XCTAssertEqual(package.types.map(\.name), ["EFirstEnum", "FSecondStruct", "UThirdClass"])
        XCTAssertEqual(package.types.map(\.sourceOrder), [0, 1, 2])
    }

    func testParsesFieldOffsetsPaddingAndInheritanceMetadata() throws {
        let sample = """
        // Package: CoreUObject
        // Enums: 0
        // Structs: 2
        // Classes: 0

        // Object: ScriptStruct CoreUObject.Vector
        // Size: 0xC (Inherited: 0x0)
        struct FVector
        {
            float X; // 0x0(0x4)
            float Y; // 0x4(0x4)
            float Z; // 0x8(0x4)
        };

        // Object: ScriptStruct CoreUObject.Plane
        // Size: 0x10 (Inherited: 0xC)
        struct FPlane : FVector
        {
            uint8_t Pad_0xC[0x0]; // 0xC(0x0)
            float W; // 0xC(0x4)
        };
        """

        let parsed = try SDKDumpParser.parse(aioHeader: sample)
        let package = try XCTUnwrap(parsed.packages.first)
        let plane = try XCTUnwrap(package.types.first(where: { $0.name == "FPlane" }))

        XCTAssertEqual(plane.parentTypeName, "FVector")
        XCTAssertEqual(plane.fields.count, 2)
        XCTAssertEqual(plane.fields.first?.name, "Pad_0xC")
        XCTAssertEqual(plane.fields.first?.isPadding, true)
        XCTAssertEqual(plane.fields.first?.offsetBytes, 0xC)
        XCTAssertEqual(plane.fields.last?.name, "W")
        XCTAssertEqual(plane.fields.last?.typeName, "float")
        XCTAssertEqual(plane.fields.last?.offsetBytes, 0xC)
        XCTAssertEqual(plane.fields.last?.sizeBytes, 0x4)
    }
}
