# Types Module

**Module:** `jam::types`

The types module defines all JAM protocol data structures, numeric aliases, and constants used throughout the SDK.

## Numeric aliases

```c
alias ServiceId  = uint;     // 32-bit service identifier
alias Timeslot   = uint;     // 32-bit timeslot index
alias Gas        = ulong;    // 64-bit unsigned gas
alias Balance    = ulong;    // 64-bit balance
alias CoreIndex  = uint;     // core index
```

## Fixed-size byte types

```c
alias Hash = char[32];       // 256-bit hash (blake2b-256)
alias Memo = char[128];      // 128-byte transfer memo
```

## Host sentinel values

These constants are returned by host functions to signal specific conditions:

| Constant | Value | Meaning |
|----------|-------|---------|
| `HOST_OK` | `0` | Success |
| `HOST_NONE` | `2^64 - 1` | Not found / no data |
| `HOST_WHAT` | `2^64 - 2` | Invalid argument |
| `HOST_OOB` | `2^64 - 3` | Out of bounds |
| `HOST_WHO` | `2^64 - 4` | Unknown service |
| `HOST_FULL` | `2^64 - 5` | Storage full / insufficient balance |
| `HOST_CORE` | `2^64 - 6` | Invalid core |
| `HOST_CASH` | `2^64 - 7` | Insufficient funds |
| `HOST_LOW` | `2^64 - 8` | Gas too low |
| `HOST_HUH` | `2^64 - 9` | Unprivileged / invalid operation |

You generally do not need to check these directly. The high-level SDK functions translate them into C3 faults.

## Fetch discriminators

Used internally by `host_fetch` to select what data to retrieve:

| Constant | Value | Description |
|----------|-------|-------------|
| `FETCH_CHAIN_PARAMS` | 0 | Chain parameters |
| `FETCH_CHAIN_ENTROPY32` | 1 | 32-byte chain entropy |
| `FETCH_AUTH_TRACE` | 2 | Authorization trace |
| `FETCH_NTH_ITEM_PAYLOAD` | 13 | Nth work item payload |
| `FETCH_INPUTS` | 14 | Accumulate inputs |
| `FETCH_SINGLE_ITEM` | 15 | Single work item |

## ServiceInfo

Metadata for a service account (96 bytes, packed):

```c
struct ServiceInfo @packed
{
    Hash     code_hash;
    Balance  balance;
    Balance  threshold_balance;
    Gas      min_gas_accumulate;
    Gas      min_gas_on_transfer;
    ulong    bytes_in_storage;
    uint     items_in_storage;
    ulong    gratis_storage_offset;
    Timeslot creation_slot;
    Timeslot last_accumulation_slot;
    Timeslot parent_slot;
}
```

## ChainParams

Protocol constants fetched from the chain (134 bytes, packed). Key fields include:

| Field | Type | Description |
|-------|------|-------------|
| `item_deposit` | `ulong` | Deposit per storage item |
| `byte_deposit` | `ulong` | Deposit per byte of storage |
| `base_deposit` | `ulong` | Base service deposit |
| `core_count` | `ushort` | Number of cores |
| `epoch_length` | `uint` | Slots per epoch |
| `val_count` | `ushort` | Number of validators |
| `slot_seconds` | `ushort` | Seconds per slot |
| `max_service_code_size` | `uint` | Maximum service code size |
| `max_bundle_size` | `uint` | Maximum work package bundle size |

See the source for the complete list of fields.

## Entry point argument structs

### RefineArgs

```c
struct RefineArgs @packed
{
    CoreIndex core_index;
    uint      work_item_index;
    ServiceId service_id;
    char*     work_payload;
    ulong     work_payload_len;
    Hash      work_package_hash;
}
```

### AccumulateArgs

```c
struct AccumulateArgs @packed
{
    Timeslot  timeslot;
    ServiceId service_id;
    Gas       num_inputs;
}
```

### IsAuthorizedArgs

```c
struct IsAuthorizedArgs @packed
{
    ushort core_index;
}
```

## RefineResult

Returned by `refine()` to pass output bytes back to the runtime:

```c
struct RefineResult
{
    char* ptr;
    usz   len;
}
```

Build these using the context methods `ctx.result_ok(ptr, len)` and `ctx.result_empty()`.

## Accumulate input types

### AccumulateOperand

A refined work item arriving in accumulate:

```c
struct AccumulateOperand
{
    Hash             work_package_hash;
    Hash             segment_root;
    Hash             authorizer_hash;
    Hash             payload_hash;
    Gas              gas_limit;
    WorkDigestOutput digest_output;
    WorkDigestOutput work_report_output;
}
```

### AccumulateTransfer

A deferred token transfer arriving in accumulate:

```c
struct AccumulateTransfer
{
    ServiceId sender;
    ServiceId receiver;
    Balance   amount;
    Memo      memo;
    Gas       gas_limit;
}
```

### AccumulateInput

Discriminated union over operands and transfers:

```c
enum AccumulateInputKind : char { OPERAND, TRANSFER }

struct AccumulateInput
{
    AccumulateInputKind kind;
    union
    {
        AccumulateOperand  operand;
        AccumulateTransfer transfer;
    }
}
```

### WorkDigestStatus

```c
enum WorkDigestStatus : char
{
    OK,
    OUT_OF_GAS,
    PANIC,
    BAD_EXPORTS,
    OVERSIZE,
    BAD_CODE,
    BIG_CODE,
}
```
