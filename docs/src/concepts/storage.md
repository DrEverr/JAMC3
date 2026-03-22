# Storage

Each JAM service has its own **key-value storage** on-chain. Storage is the primary mechanism for persisting state between accumulate rounds.

## Storage model

- Keys and values are arbitrary byte sequences.
- Storage is scoped to the service -- each service can only write to its own storage.
- Reading from other services' storage is permitted (cross-service reads).
- Storage operations cost gas and may require sufficient balance to cover deposits.

## Reading storage

Read from your own storage:

```c
char[4] key = { 'c', 'n', 't', 'r' };
char[8] buf;

usz? result = ctx.kv_read(&key, 4, &buf, 8);
if (try bytes_read = result)
{
    // buf contains bytes_read bytes of data
}
else
{
    // Key not found (result::NO_KEY)
}
```

Read from another service's storage using the lower-level API:

```c
import jam::storage;

usz? result = storage::kv_read_of(
    other_service_id,
    &key, 4,       // key pointer and length
    &buf,           // output buffer
    0,              // offset into the value
    8               // max bytes to read
);
```

The offset parameter lets you read a slice of a large value without fetching the entire thing.

## Writing storage

Writing is only available during **accumulate** (not in refine or authorizer contexts):

```c
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    char[4] key = { 'd', 'a', 't', 'a' };
    char[8] value;

    // Encode a u64 into the value buffer
    codec::encode_u64(&value, 8, 42)!;

    // Write to storage
    ctx.kv_write(&key, 4, &value, 8)!;
}
```

Writing can fail with `INSUFFICIENT_BALANCE` if the service does not have enough balance to cover the storage deposit for new items.

## Deleting storage

Delete a key to reclaim the storage deposit:

```c
ctx.kv_delete(&key, 4)!;
```

Deletion is implemented as a write with zero-length value. Like writes, it can fault with `INSUFFICIENT_BALANCE` in edge cases.

## Storage deposits

JAM charges deposits for storage usage. The chain parameters define the costs:

- **Item deposit** -- fixed cost per storage item.
- **Byte deposit** -- cost per byte of stored data.
- **Base deposit** -- base cost for the service account itself.

You can query these from chain parameters:

```c
types::ChainParams? params = ctx.chain_params();
if (try p = params)
{
    // p.item_deposit, p.byte_deposit, p.base_deposit
}
```

## Storage in refine

During refine, you have **read-only** access to storage. The compiler enforces this -- `refine::Ctx` does not have a `kv_write` or `kv_delete` method:

```c
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    char[4] key = { 'd', 'a', 't', 'a' };
    char[8] buf;

    // Reading works
    usz? result = ctx.kv_read(&key, 4, &buf, 8);

    // ctx.kv_write(...) would NOT compile
    return ctx.result_empty();
}
```

## Checkpointing

During accumulate, you can create checkpoints to commit partial state changes. If the service runs out of gas or panics after a checkpoint, the state changes up to the last checkpoint are preserved:

```c
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    ctx.kv_write(&key1, 4, &val1, 8)!;
    ctx.checkpoint();  // Commits the write above

    ctx.kv_write(&key2, 4, &val2, 8)!;
    // If a panic happens here, key1's write is preserved
    // but key2's write is rolled back
}
```
