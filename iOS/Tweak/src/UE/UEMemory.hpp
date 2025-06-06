#pragma once

#include <mach-o/dyld.h>
#include <mach-o/getsect.h>
#include <mach/mach.h>

#include <unistd.h>
#include <cstdint>
#include <string>
#include <vector>

#include <KittyInclude.hpp>

#define kINSN_PAGE_OFFSET(x) ((uintptr_t)x & ~(uintptr_t)(4096 - 1));
#define kSET_FUNC_PTR(pfunc, addr) *reinterpret_cast<void **>(&pfunc) = (void *)(addr);

namespace UEMemory
{
    extern KittyPtrValidator PtrValidator;

    bool vm_rpm_ptr(const void *address, void *result, size_t len);

    template <typename T>
    T vm_rpm_ptr(const void *address)
    {
        T buffer{};
        vm_rpm_ptr(address, &buffer, sizeof(T));
        return buffer;
    }

    std::string vm_rpm_str(const void *address, size_t max_len = 1024);
    std::wstring vm_rpm_strw(const void *address, size_t max_len = 1024);

    template <typename T>
    constexpr uint64_t GetMaxOfType()
    {
        return (1ull << (sizeof(T) * 0x8ull)) - 1;
    }

    inline uintptr_t GetPtrAlignedOf(uintptr_t p)
    {
        return ((p + (sizeof(void *) - 1)) & ~(sizeof(void *) - 1));
    }

    uintptr_t FindAlignedPointerRefrence(uintptr_t start, size_t range, uintptr_t ptr);
    inline uintptr_t FindAlignedPointerRefrence(uintptr_t start, size_t range, const void *ptr)
    {
        return FindAlignedPointerRefrence(start, range, uintptr_t(ptr));
    }

    namespace Arm64
    {
        // adrp followed by add imm
        uintptr_t Decode_ADRP_ADD(uintptr_t adrp_address, uint32_t add_offset=4);
        
        // adrp followed by ldr imm
        uintptr_t Decode_ADRP_LDR(uintptr_t adrp_address, uint32_t ldr_offset=4);
    }  // namespace Arm64
    
}  // namespace UEMemory

namespace IOUtils
{
    std::string remove_specials(std::string s);
    std::string replace_specials(std::string s, char c);
}  // namespace IOUtils

////////////////////////////////////////////////////////////////
//
//    EnumBitmask
//    https://github.com/Reputeless/EnumBitmask
//    License: CC0 1.0 Universal
//
#include <type_traits>

namespace EnumBitmask
{
    template <class Enum>
    struct EnumWrapper
    {
        Enum e;

        constexpr explicit operator bool() const noexcept
        {
            return (e != Enum{0});
        }

        constexpr operator Enum() const noexcept
        {
            return e;
        }
    };

    template <class Enum>
    EnumWrapper(Enum e) -> EnumWrapper<Enum>;
}  // namespace EnumBitmask

#define kDEFINE_ENUM_BITMASK_OPERATORS(ENUM)                          \
    static_assert(std::is_enum_v<ENUM>, "ENUM must be an enum type"); \
    [[nodiscard]]                                                     \
    inline constexpr auto operator&(ENUM lhs, ENUM rhs) noexcept      \
    {                                                                 \
        using U = std::underlying_type_t<ENUM>;                       \
        return EnumBitmask::EnumWrapper{                              \
            ENUM(static_cast<U>(lhs) & static_cast<U>(rhs))};         \
    }                                                                 \
    [[nodiscard]]                                                     \
    inline constexpr auto operator|(ENUM lhs, ENUM rhs) noexcept      \
    {                                                                 \
        using U = std::underlying_type_t<ENUM>;                       \
        return EnumBitmask::EnumWrapper{                              \
            ENUM(static_cast<U>(lhs) | static_cast<U>(rhs))};         \
    }                                                                 \
    [[nodiscard]]                                                     \
    inline constexpr auto operator^(ENUM lhs, ENUM rhs) noexcept      \
    {                                                                 \
        using U = std::underlying_type_t<ENUM>;                       \
        return EnumBitmask::EnumWrapper{                              \
            ENUM(static_cast<U>(lhs) ^ static_cast<U>(rhs))};         \
    }                                                                 \
    [[nodiscard]]                                                     \
    inline constexpr ENUM operator~(ENUM value) noexcept              \
    {                                                                 \
        using U = std::underlying_type_t<ENUM>;                       \
        return ENUM(~static_cast<U>(value));                          \
    }                                                                 \
    inline constexpr ENUM &operator&=(ENUM &lhs, ENUM rhs) noexcept   \
    {                                                                 \
        return lhs = (lhs & rhs);                                     \
    }                                                                 \
    inline constexpr ENUM &operator|=(ENUM &lhs, ENUM rhs) noexcept   \
    {                                                                 \
        return lhs = (lhs | rhs);                                     \
    }                                                                 \
    inline constexpr ENUM &operator^=(ENUM &lhs, ENUM rhs) noexcept   \
    {                                                                 \
        return lhs = (lhs ^ rhs);                                     \
    }
