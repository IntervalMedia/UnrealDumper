#pragma once

#include "../UEGameProfile.hpp"
using namespace UEMemory;

class HelloNeighborNDProfile : public IGameProfile
{
public:
    HelloNeighborNDProfile() = default;

    std::string GetAppName() const override
    {
        return "Hello Neighbor Nicky's Diaries";
    }

    std::vector<std::string> GetAppIDs() const override
    {
        return {"com.tinybuildgames.hndiaries"};
    }

    bool isUsingCasePreservingName() const override
    {
        return false;
    }

    bool IsUsingFNamePool() const override
    {
        return true;
    }

    bool isUsingOutlineNumberName() const override
    {
        return false;
    }

    uintptr_t GetGUObjectArrayPtr() const override
    {
        std::vector<std::pair<std::string, int>> idaPatterns = {
            // FUObjectArray::FUObjectArray();
            {"94 E0 23 00 91 ? ? ? 94 08 7D 80 52", 0x11},
            {"00 E6 07 2F 00 00 00 FD 1F 08 00 B9 ? ? 80 52", 0xB4},
            {"00 E6 07 2F 00 00 00 FD 1F 08 00 B9 ? ? 80 52", 0x74},

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
            // GetPlainName ToString AppendString GetStringLength
            {"02 ? 91 C8 00 00 37 ? ? ? ? ? ? ? 91", 7},

            {"39 C8 00 00 37 ? ? ? ? ? ? ? 91 ? ? ? 97 ? 00 80 52 ? ? ? 39", 5},
            {"C8 00 00 37 ? ? ? ? ? ? ? 91 ? ? ? 97 ? 00 80 52", 4},
            {"C8 00 00 37 ? ? ? ? ? ? ? 91 ? ? ? 97", 4},
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

    UE_Offsets *GetOffsets() const override
    {
        static UE_Offsets offsets = UE_DefaultOffsets::UE5_00_02(isUsingCasePreservingName(), isUsingOutlineNumberName());
        return &offsets;
    }
};
