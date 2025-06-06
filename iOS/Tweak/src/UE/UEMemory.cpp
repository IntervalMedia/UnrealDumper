#include "UEMemory.hpp"

namespace UEMemory
{
    KittyPtrValidator PtrValidator;

    bool vm_rpm_ptr(const void *address, void *result, size_t len)
    {
        if (!PtrValidator.isPtrReadable(address))
            return false;

        // faster but will crash on any invalid address
#ifdef RPM_USE_MEMCPY
        return memcpy(result, address, len) != nullptr;
#else

        vm_size_t outSize = 0;
        kern_return_t kret = vm_read_overwrite(mach_task_self(), (vm_address_t)address,
                                               (vm_size_t)len, (vm_address_t)result, &outSize);

        return kret == 0 && outSize == len;

#endif
    }

    std::string vm_rpm_str(const void *address, size_t max_len)
    {
#ifdef RPM_USE_MEMCPY
        if (PtrValidator.isPtrReadable(address))
        {
            const char *chars = (const char *)address;
            std::string str = "";
            for (size_t i = 0; i < max_len; i++)
            {
                if (chars[i] == '\0')
                    break;

                str.push_back(chars[i]);
            }
            return str;
        }
        return "";
#else
        std::vector<char> chars(max_len, '\0');
        if (!vm_rpm_ptr(address, chars.data(), max_len))
            return "";

        std::string str = "";
        for (size_t i = 0; i < chars.size(); i++)
        {
            if (chars[i] == '\0')
                break;

            str.push_back(chars[i]);
        }

        chars.clear();
        chars.shrink_to_fit();

        if ((int)str[0] == 0 && str.size() == 1)
            return "";

        return str;
#endif
    }

    std::wstring vm_rpm_strw(const void *address, size_t max_len)
    {
#ifdef RPM_USE_MEMCPY
        if (PtrValidator.isPtrReadable(address))
        {
            const wchar_t *chars = (const wchar_t *)address;
            std::wstring str = L"";
            for (size_t i = 0; i < max_len; i++)
            {
                if (chars[i] == L'\0')
                    break;

                str.push_back(chars[i]);
            }
            return str;
        }
        return L"";
#else
        std::vector<wchar_t> chars(max_len, '\0');
        if (!vm_rpm_ptr(address, chars.data(), max_len * 2))
            return L"";

        std::wstring str = L"";
        for (size_t i = 0; i < chars.size(); i++)
        {
            if (chars[i] == L'\0')
                break;

            str.push_back(chars[i]);
        }

        chars.clear();
        chars.shrink_to_fit();

        if ((int)str[0] == 0 && str.size() == 1)
            return L"";

        return str;
#endif
    }

    uintptr_t FindAlignedPointerRefrence(uintptr_t start, size_t range, uintptr_t ptr)
    {
        if (start == 0 || start != GetPtrAlignedOf(start))
            return 0;

        if (range < sizeof(void *) || range != GetPtrAlignedOf(range))
            return 0;

        for (size_t i = 0; (i + sizeof(void *)) <= range; i += sizeof(void *))
        {
            uintptr_t val = vm_rpm_ptr<uintptr_t>((void *)(start + i));
            if (val == ptr) return (start + i);
        }
        return 0;
    }

    namespace Arm64
    {
        uintptr_t Decode_ADRP_ADD(uintptr_t adrp_address, uint32_t add_offset)
        {
            if (adrp_address == 0) return 0;

            const uintptr_t page_off = kINSN_PAGE_OFFSET(adrp_address);

            int64_t adrp_pc_rel = 0;
            int32_t add_imm12 = 0;

            uint32_t adrp_insn = vm_rpm_ptr<uint32_t>((void *)(adrp_address));
            uint32_t add_insn = vm_rpm_ptr<uint32_t>((void *)(adrp_address + add_offset));
            if (adrp_insn == 0 || add_insn == 0)
                return 0;

            if (!KittyArm64::decode_adr_imm(adrp_insn, &adrp_pc_rel) || adrp_pc_rel == 0)
                return 0;

            add_imm12 = KittyArm64::decode_addsub_imm(add_insn);

            return (page_off + adrp_pc_rel + add_imm12);
        }

        uintptr_t Decode_ADRP_LDR(uintptr_t adrp_address, uint32_t ldr_offset)
        {
            if (adrp_address == 0) return 0;

            const uintptr_t page_off = kINSN_PAGE_OFFSET(adrp_address);

            int64_t adrp_pc_rel = 0;
            int32_t ldr_imm12 = 0;

            uint32_t adrp_insn = vm_rpm_ptr<uint32_t>((void *)(adrp_address));
            uint32_t ldr_insn = vm_rpm_ptr<uint32_t>((void *)(adrp_address + ldr_offset));
            if (adrp_insn == 0 || ldr_insn == 0)
                return 0;

            if (!KittyArm64::decode_adr_imm(adrp_insn, &adrp_pc_rel) || adrp_pc_rel == 0)
                return 0;

            if (!KittyArm64::decode_ldrstr_uimm(ldr_insn, &ldr_imm12))
                return 0;

            return (page_off + adrp_pc_rel + ldr_imm12);
        }
    }  // namespace Arm64

}  // namespace UEMemory

namespace IOUtils
{
    std::string remove_specials(std::string s)
    {
        for (size_t i = 0; i < s.size(); i++)
        {
            if (!((s[i] < 'A' || s[i] > 'Z') && (s[i] < 'a' || s[i] > 'z')))
                continue;

            if (!(s[i] < '0' || s[i] > '9'))
                continue;

            if (s[i] == '_')
                continue;

            s.erase(s.begin() + i);
            --i;
        }
        return s;
    }

    std::string replace_specials(std::string s, char c)
    {
        for (size_t i = 0; i < s.size(); i++)
        {
            if (!((s[i] < 'A' || s[i] > 'Z') && (s[i] < 'a' || s[i] > 'z')))
                continue;

            if (!(s[i] < '0' || s[i] > '9'))
                continue;

            if (s[i] == '_')
                continue;

            s[i] = c;
        }
        return s;
    }
}  // namespace IOUtils
