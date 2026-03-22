# Services

A **service** is the fundamental unit of on-chain logic in JAM. Each service is an account on the chain with its own code, storage, and token balance.

## Service lifecycle

A service is created by another service (or the privileged manager service) during accumulation. Once deployed, it processes work items through the refine-accumulate cycle until it is ejected or runs out of balance.

## Entry points

Every JAM service must implement two entry points. An optional third entry point is used for authorizers.

### refine

```c
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
```

Refine runs **off-chain** on validator nodes. It receives a single work item and produces a result (the "work digest"). Refine has read-only access to chain state and cannot modify storage.

Key properties of refine:
- Runs in parallel across cores.
- Deterministic -- all validators must produce the same result.
- Can read storage and preimages, but cannot write.
- Can create sub-VMs for sandboxed computation.
- Returns a `RefineResult` containing output bytes.

The refine context (`refine::Ctx`) provides:
- Work item payload (`ctx.payload()`, `ctx.payload_len()`)
- Core and work item index
- Read-only chain queries (storage, preimage lookup, chain parameters)
- Sub-VM creation and management
- Data segment export

### accumulate

```c
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
```

Accumulate runs **on-chain** after refine results have been validated. It receives the refined outputs (work digests) and any deferred transfers, and can modify the service's persistent state.

Key properties of accumulate:
- Runs sequentially on-chain.
- Can read and write storage.
- Can transfer tokens to other services.
- Can create new services and upgrade code.
- Can set checkpoints to commit partial state changes.
- Receives both work digest operands and deferred transfers as inputs.

The accumulate context (`accumulate::Ctx`) provides:
- Input iteration over operands and transfers
- Key-value storage read/write/delete
- Token transfers
- Service creation and code upgrades
- Preimage solicitation and provision
- Checkpointing and yield

### is_authorized (authorizers only)

```c
fn void is_authorized(authorizer::Ctx* ctx) @export("is_authorized")
```

Authorizers are special services that validate work packages before they are processed. An authorizer checks whether a work package is permitted to execute on a given core.

The authorizer context (`authorizer::Ctx`) provides read-only access:
- Core index
- Chain queries (storage, preimage lookup, service info)

## Contexts and type safety

jamc3 uses separate context types for each entry point. This means the compiler prevents you from calling accumulate-only operations (like `kv_write`) inside refine, or refine-only operations (like `export_segment`) inside accumulate. The type system enforces the JAM protocol rules at compile time.

```c
// This will NOT compile -- kv_write is not available on refine::Ctx
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    ctx.kv_write(&key, 4, &val, 8);  // ERROR: no such method
    return ctx.result_empty();
}
```

## Service information

You can query metadata about any service on the chain:

```c
// Own service info
types::ServiceInfo? info = ctx.service_info();

// Another service's info
types::ServiceInfo? other = ctx.service_info_of(42);
```

The `ServiceInfo` struct contains:

| Field | Type | Description |
|-------|------|-------------|
| `code_hash` | `Hash` | Blake2b-256 hash of the service code |
| `balance` | `Balance` | Token balance |
| `threshold_balance` | `Balance` | Minimum balance before ejection |
| `min_gas_accumulate` | `Gas` | Minimum gas for accumulate |
| `min_gas_on_transfer` | `Gas` | Minimum gas for on_transfer |
| `bytes_in_storage` | `ulong` | Total bytes used in storage |
| `items_in_storage` | `uint` | Number of storage items |
| `creation_slot` | `Timeslot` | Slot when the service was created |
| `last_accumulation_slot` | `Timeslot` | Last slot the service accumulated |
