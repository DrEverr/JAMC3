# SDK Reference

This section provides detailed reference documentation for each jamc3 module.

## Module overview

| Module | Description |
|--------|-------------|
| [`jam::types`](./types.md) | All JAM protocol types: ServiceId, Hash, Balance, Gas, entry point argument structs, host sentinels |
| [`jam::storage`](./storage.md) | Key-value storage: kv_read, kv_read_of, kv_write, kv_delete |
| [`jam::codec`](./codec.md) | Binary encoding/decoding: natural number varints, fixed-width LE integers, blobs, memory utilities |
| [`jam::log`](./logging.md) | Logging with levels (error, warn, info, debug, trace) and integer formatting |
| [`jam::host`](./host-functions.md) | Raw host function imports (27 functions mapped to PolkaVM ecalli indices) |
| `jam::service` | High-level API: gas, chain params, service info, transfers, checkpoints, service creation |
| `jam::refine` | Refine context: typed wrapper with read-only chain access, sub-VMs, and segment export |
| `jam::accumulate` | Accumulate context: typed wrapper with storage writes, transfers, input iteration |
| `jam::authorizer` | Authorizer context: typed wrapper with read-only chain access |
| `jam::entry` | Entry point dispatch for refine and accumulate (internal) |
| `jam::entry_auth` | Entry point dispatch for is_authorized (internal) |
| `jam::result` | Fault definitions for error handling |

## Entry points

The SDK expects you to implement these functions. The entry point modules decode raw arguments and call your hooks with typed context objects.

### Standard service (refine + accumulate)

```c
module my_service;

import jam::types;
import jam::refine;
import jam::accumulate;

fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    // Your refine logic
    return ctx.result_empty();
}

fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    // Your accumulate logic
}
```

### Authorizer

```c
module my_auth;

import jam::types;
import jam::authorizer;

fn void is_authorized(authorizer::Ctx* ctx) @export("is_authorized")
{
    // Your authorization logic
}
```

Build authorizers with the `--authorizer` flag.

## Error handling

jamc3 uses C3's optional/fault system for error handling. Functions that can fail return optional types (denoted by `?`). Use `!` to propagate faults or `if (catch ...)` / `if (try ...)` to handle them:

```c
// Propagate with !
ctx.kv_write(&key, 4, &value, 8)!;

// Handle explicitly
usz? result = ctx.kv_read(&key, 4, &buf, 8);
if (try bytes_read = result)
{
    // Success: use bytes_read
}
else
{
    // Failure: key not found
}
```

### Fault types

All faults are defined in `jam::result`:

| Fault | Meaning |
|-------|---------|
| `NO_KEY` | Key not found in storage |
| `NO_DATA` | Data unavailable (chain params, entropy, preimage, inputs exhausted) |
| `UNDECODABLE` | Wire format decode failure |
| `TOO_BIG` | Encode buffer too small |
| `INSUFFICIENT_BALANCE` | Not enough balance for the operation |
| `UNREACHABLE` | Target service does not exist |
| `HOST_ERROR` | General host-call failure |
| `HOST_UNPRIVILEGED` | Caller lacks required privilege |
| `ALLOC_FAILURE` | Allocation failed |
