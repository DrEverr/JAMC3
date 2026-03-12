// JAM SDK - Host Function Imports
// These are the raw PVM host-call declarations.
// Each host function is imported by index as specified by the JAM protocol.
//
// In the C SDK these are declared via POLKAVM_IMPORT_WITH_INDEX macros which
// embed metadata into special ELF sections. For C3 targeting PolkaVM, we
// declare them as extern functions with @cname matching the symbol names
// that polkavm-cc / polkatool expect.
//
// The actual binding mechanism depends on the PolkaVM toolchain resolving
// these imports at link time. The C3 compiler emits standard C-ABI calls
// which the PolkaVM linker (polkatool) maps to ecalli host-call indices.
module jam::host;

// ---------------------------------------------------------------------------
// General host functions (available in both refine and accumulate)
// ---------------------------------------------------------------------------

// Index 0: Returns remaining gas.
extern fn ulong host_gas() @cname("gas");

// Index 1: Fetch chain data into buffer.
// Returns bytes written or error sentinel.
extern fn ulong host_fetch(
    char* buffer,
    ulong offset,
    ulong len,
    ulong discriminator,
    ulong w11,
    ulong w12
) @cname("fetch");

// Index 2: Lookup preimage by hash.
extern fn ulong host_lookup(
    char* hash,
    char* out,
    ulong offset,
    ulong len
) @cname("lookup");

// Index 3: Read from service storage.
extern fn ulong host_read(
    ulong service_id,
    char* key,
    ulong key_len,
    char* out,
    ulong offset,
    ulong len
) @cname("read");

// Index 4: Write to own service storage.
extern fn ulong host_write(
    char* key,
    ulong key_len,
    char* value,
    ulong value_len
) @cname("write");

// Index 5: Get service account info.
extern fn ulong host_info(
    ulong service_id,
    char* out
) @cname("info");

// Index 100: Log a message.
extern fn void host_log(
    ulong level,
    char* target,
    ulong target_len,
    char* msg,
    ulong msg_len
) @cname("log");

// ---------------------------------------------------------------------------
// Refine-only host functions
// ---------------------------------------------------------------------------

// Index 6: Historical preimage lookup.
extern fn ulong host_historical_lookup(
    ulong service_id,
    char* hash,
    char* out,
    ulong len
) @cname("historical_lookup");

// Index 7: Export data segment.
extern fn ulong host_export(
    char* ptr,
    ulong len
) @cname("export");

// Index 8: Create sub-VM machine.
extern fn ulong host_machine(
    char* code,
    ulong len,
    ulong pc
) @cname("machine");

// Index 9: Read sub-VM memory.
extern fn ulong host_peek(
    ulong machine_id,
    char* out,
    ulong addr,
    ulong len
) @cname("peek");

// Index 10: Write sub-VM memory.
extern fn ulong host_poke(
    ulong machine_id,
    char* data,
    ulong addr,
    ulong len
) @cname("poke");

// Index 11: Manage sub-VM page permissions.
extern fn ulong host_pages(
    ulong machine_id,
    ulong start,
    ulong count,
    ulong mode
) @cname("pages");

// Index 12: Invoke sub-VM execution.
extern fn ulong host_invoke(
    ulong machine_id,
    char* params
) @cname("invoke");

// Index 13: Destroy sub-VM.
extern fn ulong host_expunge(
    ulong machine_id
) @cname("expunge");

// ---------------------------------------------------------------------------
// Accumulate-only host functions
// ---------------------------------------------------------------------------

// Index 14: Bless privileged services (manager-only).
extern fn ulong host_bless(
    ulong manager,
    char* assigners,
    ulong delegator,
    ulong registrar,
    char* extra,
    ulong count
) @cname("bless");

// Index 15: Assign authorizers to a core.
extern fn ulong host_assign(
    ulong core,
    char* authorizers,
    ulong assigner
) @cname("assign");

// Index 16: Designate pending validator keys.
extern fn ulong host_designate(
    char* validators
) @cname("designate");

// Index 17: Create state checkpoint (returns gas).
extern fn ulong host_checkpoint() @cname("checkpoint");

// Index 18: Create a new service account.
extern fn ulong host_new(
    char* code_hash,
    ulong code_len,
    ulong min_gas_acc,
    ulong min_gas_memo,
    ulong gratis_offset,
    ulong desired_id
) @cname("new");

// Index 19: Upgrade service code.
extern fn ulong host_upgrade(
    char* code_hash,
    ulong min_gas_acc,
    ulong min_gas_memo
) @cname("upgrade");

// Index 20: Transfer tokens to another service.
extern fn ulong host_transfer(
    ulong receiver,
    ulong amount,
    ulong gas_limit,
    char* memo
) @cname("transfer");

// Index 21: Destroy/eject a service account.
extern fn ulong host_eject(
    ulong service_id,
    char* memo
) @cname("eject");

// Index 22: Query preimage request status.
extern fn ulong host_query(
    char* hash,
    ulong len
) @cname("query");

// Index 23: Solicit a preimage.
extern fn ulong host_solicit(
    char* hash,
    ulong len
) @cname("solicit");

// Index 24: Forget a preimage request.
extern fn ulong host_forget(
    char* hash,
    ulong len
) @cname("forget");

// Index 25: Yield accumulation output hash.
extern fn ulong host_yield(
    char* hash
) @cname("yield");

// Index 26: Provide preimage data.
extern fn ulong host_provide(
    ulong service_id,
    ulong offset,
    ulong len
) @cname("provide");
