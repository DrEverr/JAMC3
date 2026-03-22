# Host Functions

**Module:** `jam::host`

The host module declares the raw PVM host function imports. These are extern functions with `@cname` attributes matching the symbols that the PolkaVM toolchain resolves to `ecalli` host-call indices.

In most cases, you should use the high-level SDK wrappers (`jam::service`, `jam::storage`, context methods) rather than calling host functions directly. The raw functions are documented here for completeness and for cases where the high-level API does not cover your needs.

## General host functions

These are available in all contexts (refine, accumulate, and authorizer).

### host_gas (index 0)

```c
extern fn ulong host_gas() @cname("gas");
```

Returns the remaining gas.

### host_fetch (index 1)

```c
extern fn ulong host_fetch(
    char* buffer, ulong offset, ulong len,
    ulong discriminator, ulong w11, ulong w12
) @cname("fetch");
```

Fetches chain data into a buffer. The `discriminator` selects what to fetch (see `FETCH_*` constants in `jam::types`). Returns bytes written or an error sentinel.

### host_lookup (index 2)

```c
extern fn ulong host_lookup(
    char* hash, char* out, ulong offset, ulong len
) @cname("lookup");
```

Looks up a preimage by hash. Returns bytes written or `HOST_NONE`.

### host_read (index 3)

```c
extern fn ulong host_read(
    ulong service_id, char* key, ulong key_len,
    char* out, ulong offset, ulong len
) @cname("read");
```

Reads from service storage. Pass `HOST_NONE` as `service_id` to read from the current service.

### host_write (index 4)

```c
extern fn ulong host_write(
    char* key, ulong key_len, char* value, ulong value_len
) @cname("write");
```

Writes to the current service's storage. Pass `null` with `value_len=0` to delete.

### host_info (index 5)

```c
extern fn ulong host_info(ulong service_id, char* out) @cname("info");
```

Retrieves service account info (96 bytes). Pass `HOST_NONE` for the current service.

### host_log (index 100)

```c
extern fn void host_log(
    ulong level, char* target, ulong target_len,
    char* msg, ulong msg_len
) @cname("log");
```

Emits a log message at the given level.

## Refine-only host functions

These are only valid during refine execution. Calling them during accumulate is undefined behavior.

### host_historical_lookup (index 6)

```c
extern fn ulong host_historical_lookup(
    ulong service_id, char* hash, char* out,
    ulong offset, ulong max_len
) @cname("historical_lookup");
```

Historical preimage lookup for a specific service.

### host_export (index 7)

```c
extern fn ulong host_export(char* ptr, ulong len) @cname("export");
```

Exports a data segment. Returns the segment index.

### host_machine (index 8)

```c
extern fn ulong host_machine(
    char* code, ulong len, ulong pc
) @cname("machine");
```

Creates a sub-VM from PVM bytecode. Returns a machine ID.

### host_peek (index 9)

```c
extern fn ulong host_peek(
    ulong machine_id, char* out, ulong addr, ulong len
) @cname("peek");
```

Reads from sub-VM memory.

### host_poke (index 10)

```c
extern fn ulong host_poke(
    ulong machine_id, ulong addr, char* data, ulong len
) @cname("poke");
```

Writes to sub-VM memory.

### host_pages (index 11)

```c
extern fn ulong host_pages(
    ulong machine_id, ulong start, ulong count, ulong mode
) @cname("pages");
```

Manages sub-VM page permissions. Modes: 0=none, 1=read-only, 2=read-write.

### host_invoke (index 12)

```c
extern fn ulong host_invoke(
    ulong machine_id, char* params
) @cname("invoke");
```

Runs a sub-VM until it halts. `params` is a 14x u64 register initialization block.

### host_expunge (index 13)

```c
extern fn ulong host_expunge(ulong machine_id) @cname("expunge");
```

Destroys a sub-VM.

## Accumulate-only host functions

These are only valid during accumulate execution.

### host_bless (index 14)

```c
extern fn ulong host_bless(
    ulong manager, char* assigners,
    ulong delegator, ulong registrar,
    char* extra, ulong count
) @cname("bless");
```

Sets privileged service roles (manager-only). This function exceeds PolkaVM's 6-register limit when called as a context method, so call it directly.

### host_assign (index 15)

```c
extern fn ulong host_assign(
    ulong core, char* authorizers, ulong assigner
) @cname("assign");
```

Assigns authorizer pool to a core.

### host_designate (index 16)

```c
extern fn ulong host_designate(char* validators) @cname("designate");
```

Registers pending validator keys (registrar-only).

### host_checkpoint (index 17)

```c
extern fn ulong host_checkpoint() @cname("checkpoint");
```

Creates a state checkpoint. Returns gas consumed since the last checkpoint.

### host_new (index 18)

```c
extern fn ulong host_new(
    char* code_hash, ulong code_len,
    ulong min_gas_acc, ulong min_gas_memo,
    ulong gratis_offset, ulong desired_id
) @cname("new");
```

Creates a new service account. Returns the assigned service ID.

### host_upgrade (index 19)

```c
extern fn ulong host_upgrade(
    char* code_hash, ulong min_gas_acc, ulong min_gas_memo
) @cname("upgrade");
```

Upgrades the current service's code.

### host_transfer (index 20)

```c
extern fn ulong host_transfer(
    ulong receiver, ulong amount, ulong gas_limit, char* memo
) @cname("transfer");
```

Transfers tokens to another service.

### host_eject (index 21)

```c
extern fn ulong host_eject(ulong service_id, char* memo) @cname("eject");
```

Destroys a service account.

### host_query (index 22)

```c
extern fn ulong host_query(char* hash, ulong len) @cname("query");
```

Queries preimage request status.

### host_solicit (index 23)

```c
extern fn ulong host_solicit(char* hash, ulong len) @cname("solicit");
```

Solicits a preimage by hash.

### host_forget (index 24)

```c
extern fn ulong host_forget(char* hash, ulong len) @cname("forget");
```

Cancels a preimage solicitation.

### host_yield (index 25)

```c
extern fn ulong host_yield(char* hash) @cname("yield");
```

Sets the accumulation output hash.

### host_provide (index 26)

```c
extern fn ulong host_provide(
    ulong service_id, char* data, ulong len
) @cname("provide");
```

Provides preimage data to fulfill a solicitation.
