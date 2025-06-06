#pragma once

#include "../UEGameProfile.hpp"
using namespace UEMemory;

class Lineage2Profile : public IGameProfile
{
public:
    Lineage2Profile() = default;

    std::string GetAppName() const override
    {
        return "Lineage 2 Revolution";
    }

    std::vector<std::string> GetAppIDs() const override
    {
        return {"com.netmarble.lin2ws"};
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
        std::string ida_pattern = "28 11 08 8B 09 09 40 B9 29 01 02 32 09 09 00 B9";
        const int step = -0xC;

        auto text_seg = GetExecutableInfo().getSection("__TEXT", "__text");

        auto insn_addresses = KittyScanner::findIdaPatternAll(text_seg.start, text_seg.end, ida_pattern);
        if (insn_addresses.empty())
            return 0;

        for (const auto &it : insn_addresses)
        {
            uintptr_t objobjects = Arm64::Decode_ADRP_LDR(it + step, 8);
            if (objobjects)
                return (objobjects - GetOffsets()->FUObjectArray.ObjObjects);
        }

        return 0;
    }

    uintptr_t GetNamesPtr() const override
    {
        std::vector<std::pair<std::string, int>> idaPatterns = {
            // FName::Compare
            {"F9 ? FF 87 52 ? 02 ? 0B ? 02 00 71", -0x17},
            {"F9 ? FF 87 52 ? 02 ? 0B ? 02 00 71", -0x23},
            {"F9 ? FF 87 52 ? 02 ? 0B ? 02 00 71", -0x2B},
        };

        auto text_seg = GetExecutableInfo().getSection("__TEXT", "__text");

        for (const auto &it : idaPatterns)
        {
            std::string ida_pattern = it.first;
            const int step = it.second;

            uintptr_t ins = KittyScanner::findIdaPatternFirst(text_seg.start, text_seg.end, ida_pattern);
            if (ins != 0)
            {
                uintptr_t adrl = Arm64::Decode_ADRP_LDR(ins + step);
                if (adrl != 0) return adrl;
            }
        }

        return 0;
    }

    UE_Offsets *GetOffsets() const override
    {
        static UE_Offsets offsets = UE_DefaultOffsets::UE4_00_17(isUsingCasePreservingName());

        static bool once = false;
        if (!once)
        {
            once = true;
            offsets.FUObjectItem.Size = (sizeof(void *) + (sizeof(int32_t) * 2));
        }

        return &offsets;
    }
};
