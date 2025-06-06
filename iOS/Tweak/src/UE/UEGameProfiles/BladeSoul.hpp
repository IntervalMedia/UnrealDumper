#pragma once

#include "../UEGameProfile.hpp"
using namespace UEMemory;

class BladeSoulProfile : public IGameProfile
{
public:
    BladeSoulProfile() = default;

    std::string GetAppName() const override
    {
        return "Blade Soul Revolution";
    }

    std::vector<std::string> GetAppIDs() const override
    {
        return {"com.netmarble.bnsmasia"};
    }

    bool isUsingCasePreservingName() const override
    {
        return false;
    }

    bool IsUsingFNamePool() const override
    {
        return false;
    }
    bool isUsingOutlineNumberName() const override
    {
        return false;
    }

    uintptr_t GetGUObjectArrayPtr() const override
    {
        return KittyScanner::findSymbol(GetExecutableInfo(), "_GUObjectArray");
    }

    uintptr_t GetNamesPtr() const override
    {
        // GFNameTableForDebuggerVisualizers_MT = &GNames
        return KittyScanner::findSymbol(GetExecutableInfo(), "_GFNameTableForDebuggerVisualizers_MT");
    }

    UE_Offsets *GetOffsets() const override
    {
        static UE_Offsets offsets = UE_DefaultOffsets::UE4_20(isUsingCasePreservingName());
        return &offsets;
    }
};
