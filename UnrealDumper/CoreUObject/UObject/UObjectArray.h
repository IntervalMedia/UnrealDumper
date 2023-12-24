#pragma once
#include "ObjectMacros.h"

/**
* Single item in the UObject array.
*/
struct FUObjectItem
{
	// payson1337 Pointer to the allocated object
	class UObjectBase* Object;
	// payson1337 Internal flags
	int32_t Flags;
	// payson1337 UObject Owner Cluster Index
	int32_t ClusterRootIndex;
	// payson1337 Weak Object Pointer Serial number associated with the object
	int32_t SerialNumber;

	FUObjectItem()
		: Object(nullptr)
		, Flags(0)
		, ClusterRootIndex(0)
		, SerialNumber(0)
	{
	}
	~FUObjectItem()
	{
	}

	// payson1337 Non-copyable
	FUObjectItem(FUObjectItem&&) = delete;
	FUObjectItem(const FUObjectItem&) = delete;
	FUObjectItem& operator=(FUObjectItem&&) = delete;
	FUObjectItem& operator=(const FUObjectItem&) = delete;

	inline void SetOwnerIndex(int32_t OwnerIndex)
	{
		ClusterRootIndex = OwnerIndex;
	}

	inline int32_t GetOwnerIndex() const
	{
		return ClusterRootIndex;
	}

	/** Encodes the cluster index in the ClusterRootIndex variable */
	inline void SetClusterIndex(int32_t ClusterIndex)
	{
		ClusterRootIndex = -ClusterIndex - 1;
	}

	/** Decodes the cluster index from the ClusterRootIndex variable */
	inline int32_t GetClusterIndex() const
	{
		// payson1337 checkSlow(ClusterRootIndex < 0);
		return -ClusterRootIndex - 1;
	}

	inline int32_t GetSerialNumber() const
	{
		return SerialNumber;
	}

	/*inline void SetFlags(EInternalObjectFlags FlagsToSet)
	{
		// payson1337 check((int32(FlagsToSet) & ~int32(EInternalObjectFlags::AllFlags)) == 0);
		ThisThreadAtomicallySetFlag(FlagsToSet);
	}*/

	inline EInternalObjectFlags GetFlags() const
	{
		return EInternalObjectFlags(Flags);
	}

	/*inline void ClearFlags(EInternalObjectFlags FlagsToClear)
	{
		check((int32(FlagsToClear) & ~int32(EInternalObjectFlags::AllFlags)) == 0);
		ThisThreadAtomicallyClearedFlag(FlagsToClear);
	}*/

	/**
	 * Uses atomics to clear the specified flag(s).
	 * @param FlagsToClear
	 * @return True if this call cleared the flag, false if it has been cleared by another thread.
	 */
	 /*FORCEINLINE bool ThisThreadAtomicallyClearedFlag(EInternalObjectFlags FlagToClear)
	 {
		 static_assert(sizeof(int32) == sizeof(Flags), "Flags must be 32-bit for atomics.");
		 bool bIChangedIt = false;
		 while (1)
		 {
			 int32 StartValue = int32(Flags);
			 if (!(StartValue & int32(FlagToClear)))
			 {
				 break;
			 }
			 int32 NewValue = StartValue & ~int32(FlagToClear);
			 if ((int32)FPlatformAtomics::InterlockedCompareExchange((int32*)&Flags, NewValue, StartValue) == StartValue)
			 {
				 bIChangedIt = true;
				 break;
			 }
		 }
		 return bIChangedIt;
	 }

	 FORCEINLINE bool ThisThreadAtomicallySetFlag(EInternalObjectFlags FlagToSet)
	 {
		 static_assert(sizeof(int32) == sizeof(Flags), "Flags must be 32-bit for atomics.");
		 bool bIChangedIt = false;
		 while (1)
		 {
			 int32 StartValue = int32(Flags);
			 if (StartValue & int32(FlagToSet))
			 {
				 break;
			 }
			 int32 NewValue = StartValue | int32(FlagToSet);
			 if ((int32)FPlatformAtomics::InterlockedCompareExchange((int32*)&Flags, NewValue, StartValue) == StartValue)
			 {
				 bIChangedIt = true;
				 break;
			 }
		 }
		 return bIChangedIt;
	 }*/

	inline bool HasAnyFlags(EInternalObjectFlags InFlags) const
	{
		return !!(Flags & int32_t(InFlags));
	}
};

/**
* Simple array type that can be expanded without invalidating existing entries.
* This is critical to thread safe FNames.
* @param ElementType Type of the pointer we are storing in the array
* @param MaxTotalElements absolute maximum number of elements this array can ever hold
* @param ElementsPerChunk how many elements to allocate in a chunk
**/
struct FChunkedFixedUObjectArray
{
	enum
	{
		NumElementsPerChunk = 64 * 1024,
	};

	/** Master table to chunks of pointers **/
	FUObjectItem** Objects;
	/** If requested, a contiguous memory where all objects are allocated **/
	FUObjectItem* PreAllocatedObjects;
	/** Maximum number of elements **/
	int32_t MaxElements;
	/** Number of elements we currently have **/
	int32_t NumElements;
	/** Maximum number of chunks **/
	int32_t MaxChunks;
	/** Number of chunks we currently have **/
	int32_t NumChunks;

public:

	/**
	* Return the number of elements in the array
	* Thread safe, but you know, someone might have added more elements before this even returns
	* @return	the number of elements in the array
	**/
	inline int32_t Num() const
	{
		return NumElements;
	}
	/**
	* Return if this index is valid
	* Thread safe, if it is valid now, it is valid forever. Other threads might be adding during this call.
	* @param	Index	Index to test
	* @return	true, if this is a valid
	**/
	inline bool IsValidIndex(int32_t Index) const
	{
		return Index < Num() && Index >= 0;
	}

	/**
	* Return a pointer to the pointer to a given element
	* @param Index The Index of an element we want to retrieve the pointer-to-pointer for
	**/
	inline FUObjectItem const* GetObjectPtr(int32_t Index) const // payson1337 TSAN_SAFE
	{
		const int32_t ChunkIndex = Index / NumElementsPerChunk;
		const int32_t WithinChunkIndex = Index % NumElementsPerChunk;
		// payson1337 checkf(IsValidIndex(Index), TEXT("IsValidIndex(%d)"), Index);
		// payson1337 checkf(ChunkIndex < NumChunks, TEXT("ChunkIndex (%d) < NumChunks (%d)"), ChunkIndex, NumChunks);
		// payson1337 checkf(Index < MaxElements, TEXT("Index (%d) < MaxElements (%d)"), Index, MaxElements);
		FUObjectItem* Chunk = Objects[ChunkIndex];
		// payson1337 check(Chunk);
		return Chunk + WithinChunkIndex;
	}
	inline FUObjectItem* GetObjectPtr(int32_t Index) // payson1337 TSAN_SAFE
	{
		const int32_t ChunkIndex = Index / NumElementsPerChunk;
		const int32_t WithinChunkIndex = Index % NumElementsPerChunk;
		// payson1337 checkf(IsValidIndex(Index), TEXT("IsValidIndex(%d)"), Index);
		// payson1337 checkf(ChunkIndex < NumChunks, TEXT("ChunkIndex (%d) < NumChunks (%d)"), ChunkIndex, NumChunks);
		// payson1337 checkf(Index < MaxElements, TEXT("Index (%d) < MaxElements (%d)"), Index, MaxElements);
		FUObjectItem* Chunk = Objects[ChunkIndex];
		// payson1337 check(Chunk);
		return Chunk + WithinChunkIndex;
	}

	/**
	* Return a reference to an element
	* @param	Index	Index to return
	* @return	a reference to the pointer to the element
	* Thread safe, if it is valid now, it is valid forever. This might return nullptr, but by then, some other thread might have made it non-nullptr.
	**/
	inline FUObjectItem const& operator[](int32_t Index) const
	{
		FUObjectItem const* ItemPtr = GetObjectPtr(Index);
		// payson1337 check(ItemPtr);
		return *ItemPtr;
	}
	inline FUObjectItem& operator[](int32_t Index)
	{
		FUObjectItem* ItemPtr = GetObjectPtr(Index);
		// payson1337 check(ItemPtr);
		return *ItemPtr;
	}
};

/**
* Fixed size UObject array.
*/
class FFixedUObjectArray
{
	/** Static master table to chunks of pointers **/
	FUObjectItem* Objects;
	/** Number of elements we currently have **/
	int32_t MaxElements;
	/** Current number of UObject slots */
	int32_t NumElements;
public:
	FORCEINLINE FUObjectItem const* GetObjectPtr(int32_t Index) const
	{
		// payson1337 check(Index >= 0 && Index < NumElements);
		return &Objects[Index];
	}

	FORCEINLINE FUObjectItem* GetObjectPtr(int32_t Index)
	{
		// payson1337 check(Index >= 0 && Index < NumElements);
		return &Objects[Index];
	}

	/**
	* Return the number of elements in the array
	* Thread safe, but you know, someone might have added more elements before this even returns
	* @return	the number of elements in the array
	**/
	FORCEINLINE int32_t Num() const
	{
		return NumElements;
	}

	/**
	* Return the number max capacity of the array
	* Thread safe, but you know, someone might have added more elements before this even returns
	* @return	the maximum number of elements in the array
	**/
	FORCEINLINE int32_t Capacity() const
	{
		return MaxElements;
	}

	/**
	* Return if this index is valid
	* Thread safe, if it is valid now, it is valid forever. Other threads might be adding during this call.
	* @param	Index	Index to test
	* @return	true, if this is a valid
	**/
	FORCEINLINE bool IsValidIndex(int32_t Index) const
	{
		return Index < Num() && Index >= 0;
	}
};