#pragma once

/**
 * Low level implementation of UObject, should not be used directly in game code
 */
class UObjectBase
{
	public:
		/**
		 * Returns the unique ID of the object...these are reused so it is only unique while the object is alive.
		 * Useful as a tag.
		**/
		/*uint32_t GetUniqueID() const
		{
			return (uint32_t)InternalIndex;
		}*/

		/** Returns the UClass that defines the fields of this object */
		struct UClass* GetClass() const
		{
			return *(struct UClass**)((__int64)this + Offsets::UObjectBase::ClassPrivate);
		}

		/** Returns the UObject this object resides in */
		struct UObject* GetOuter() const
		{
			return *(struct UObject**)((__int64)this + 0x20); // payson1337 GAY
		}

		/** Returns the logical name of this object */
		uint64_t GetFName() // payson1337 NOTE: Yea, that's not 100% correct
		{
			return *(uint64_t*)((__int64)this + Offsets::UObjectBase::NamePrivate);
		}
};