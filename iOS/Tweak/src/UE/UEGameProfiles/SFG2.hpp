#pragma once

#include "../UEGameProfile.hpp"
using namespace UEMemory;

class SFG2Profile : public IGameProfile
{
public:
    SFG2Profile() = default;

    std::string GetAppName() const override
    {
        return "Special Forces Group 2";
    }

    std::vector<std::string> GetAppIDs() const override
    {
        return {"com.ForgeGames.SpecialForcesGroup2"};
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
        std::vector<std::pair<std::string, int>> idaPatterns = {
            // FEngineLoop::PreInitPostStartupScreen
            {"A8 99 99 52 88 B9 A7 72 ? ? ? 1E ? ? 2C 1E E0 00 80 52", 0x34},

            {"40 20 1e ? 03 ? aa ? 03 ? aa ? ? 40 b9 ? ? ? ? ? ? ? 91", 0xF},

            {"40 B9 ? ? 40 39 ? ? ? ? ? ? ? 91 ? ? ? 97 ? ? ? 97 ? ? ? 97", 6},

            {"FF 9F 52 ? ? ? ? ? ? ? 91 ? 03 80 52 ? ? 40 F9", 3},
            {"80 52 ? FF 9F 52 ? ? ? ? ? ? ? 91 ? 03 80 52", 6},
        };

        auto text_seg = GetExecutableInfo().getSection("__TEXT", "__text");

        for (const auto &it : idaPatterns)
        {
            std::string ida_pattern = it.first;
            const int step = it.second;

            uintptr_t ins = KittyScanner::findIdaPatternFirst(text_seg.start, text_seg.end, ida_pattern);
            if (ins != 0)
            {
                uintptr_t adrl = Arm64::Decode_ADRP_ADD(ins + step);
                if (adrl != 0) return adrl;
            }
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
        static UE_Offsets offsets = UE_DefaultOffsets::UE4_22(isUsingCasePreservingName());
        return &offsets;
    }
};
