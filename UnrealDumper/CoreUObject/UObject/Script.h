#pragma once

//
// payson1337 Function flags.
//
// payson1337 Note: Please keep ParseFunctionFlags in sync when this enum is modified.
enum EFunctionFlags // payson1337 : uint32_t
{
	// payson1337 Function flags.
	FUNC_None = 0x00000000,

	FUNC_Final = 0x00000001,	// payson1337 Function is final (prebindable, non-overridable function).
	FUNC_RequiredAPI = 0x00000002,	// payson1337 Indicates this function is DLL exported/imported.
	FUNC_BlueprintAuthorityOnly = 0x00000004,   // payson1337 Function will only run if the object has network authority
	FUNC_BlueprintCosmetic = 0x00000008,   // payson1337 Function is cosmetic in nature and should not be invoked on dedicated servers
	// payson1337 FUNC_				= 0x00000010,   // payson1337 unused.
	// payson1337 FUNC_				= 0x00000020,   // payson1337 unused.
	FUNC_Net = 0x00000040,   // payson1337 Function is network-replicated.
	FUNC_NetReliable = 0x00000080,   // payson1337 Function should be sent reliably on the network.
	FUNC_NetRequest = 0x00000100,	// payson1337 Function is sent to a net service
	FUNC_Exec = 0x00000200,	// payson1337 Executable from command line.
	FUNC_Native = 0x00000400,	// payson1337 Native function.
	FUNC_Event = 0x00000800,   // payson1337 Event function.
	FUNC_NetResponse = 0x00001000,   // payson1337 Function response from a net service
	FUNC_Static = 0x00002000,   // payson1337 Static function.
	FUNC_NetMulticast = 0x00004000,	// payson1337 Function is networked multicast Server -> All Clients
	FUNC_UbergraphFunction = 0x00008000,   // payson1337 Function is used as the merge 'ubergraph' for a blueprint, only assigned when using the persistent 'ubergraph' frame
	FUNC_MulticastDelegate = 0x00010000,	// payson1337 Function is a multi-cast delegate signature (also requires FUNC_Delegate to be set!)
	FUNC_Public = 0x00020000,	// payson1337 Function is accessible in all classes (if overridden, parameters must remain unchanged).
	FUNC_Private = 0x00040000,	// payson1337 Function is accessible only in the class it is defined in (cannot be overridden, but function name may be reused in subclasses.  IOW: if overridden, parameters don't need to match, and Super.Func() cannot be accessed since it's private.)
	FUNC_Protected = 0x00080000,	// payson1337 Function is accessible only in the class it is defined in and subclasses (if overridden, parameters much remain unchanged).
	FUNC_Delegate = 0x00100000,	// payson1337 Function is delegate signature (either single-cast or multi-cast, depending on whether FUNC_MulticastDelegate is set.)
	FUNC_NetServer = 0x00200000,	// payson1337 Function is executed on servers (set by replication code if passes check)
	FUNC_HasOutParms = 0x00400000,	// payson1337 function has out (pass by reference) parameters
	FUNC_HasDefaults = 0x00800000,	// payson1337 function has structs that contain defaults
	FUNC_NetClient = 0x01000000,	// payson1337 function is executed on clients
	FUNC_DLLImport = 0x02000000,	// payson1337 function is imported from a DLL
	FUNC_BlueprintCallable = 0x04000000,	// payson1337 function can be called from blueprint code
	FUNC_BlueprintEvent = 0x08000000,	// payson1337 function can be overridden/implemented from a blueprint
	FUNC_BlueprintPure = 0x10000000,	// payson1337 function can be called from blueprint code, and is also pure (produces no side effects). If you set this, you should set FUNC_BlueprintCallable as well.
	FUNC_EditorOnly = 0x20000000,	// payson1337 function can only be called from an editor scrippt.
	FUNC_Const = 0x40000000,	// payson1337 function can be called from blueprint code, and only reads state (never writes state)
	FUNC_NetValidate = 0x80000000,	// payson1337 function must supply a _Validate implementation

	FUNC_AllFlags = 0xFFFFFFFF,
};
