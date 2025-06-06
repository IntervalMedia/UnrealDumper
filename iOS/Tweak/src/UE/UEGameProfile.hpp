#pragma once

#include <cstdint>
#include <functional>
#include <string>
#include <utility>
#include <vector>

#include "UEMemory.hpp"
#include "UEOffsets.hpp"

class IGameProfile
{
protected:
    UEVars _UEVars;

public:
    virtual ~IGameProfile() = default;

    UEVarsInitStatus InitUEVars();
    const UEVars *GetUEVars() const { return &_UEVars; }

    virtual std::string GetAppName() const = 0;

    virtual std::vector<std::string> GetAppIDs() const = 0;

    virtual MemoryFileInfo GetExecutableInfo() const
    {
        return KittyMemory::getBaseInfo();
    }

    virtual bool isUsingCasePreservingName() const = 0;

    virtual bool IsUsingFNamePool() const = 0;

    virtual bool isUsingOutlineNumberName() const = 0;

    virtual UE_Offsets *GetOffsets() const = 0;

protected:
    virtual uintptr_t GetGUObjectArrayPtr() const = 0;

    // GNames / NamePoolData
    virtual uintptr_t GetNamesPtr() const = 0;

    virtual uint8_t *GetNameEntry(int32_t id) const;
    // can override if decryption is needed
    virtual std::string GetNameEntryString(uint8_t *entry) const;
    virtual std::string GetNameByID(int32_t id) const;
};
