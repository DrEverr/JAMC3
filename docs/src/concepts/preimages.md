# Preimages

The **preimage system** in JAM allows services to request data blobs by their hash and have them provided by external parties. This is useful for storing large data off-chain while referencing it on-chain by hash.

## How it works

1. A service **solicits** a preimage by specifying its hash and expected length.
2. An external party (or another service) **provides** the actual data matching that hash.
3. The service can then **look up** the preimage data by hash.

## Soliciting preimages

During accumulate, request a preimage by hash:

```c
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    types::Hash target_hash = { /* 32 bytes */ };
    ulong expected_len = 1024;

    ctx.solicit((char*)&target_hash, expected_len)!;
}
```

## Querying preimage status

Check whether a solicited preimage is available:

```c
ulong? status = ctx.query((char*)&target_hash, expected_len);
if (try s = status)
{
    // s indicates the preimage status
}
```

## Looking up preimage data

Once a preimage is available, read it:

```c
char[1024] buf;
usz? result = ctx.lookup((char*)&target_hash, &buf, 0, 1024);
if (try bytes_read = result)
{
    // buf now contains the preimage data
}
```

The `lookup` function is available in all contexts (refine, accumulate, and authorizer).

## Providing preimages

During accumulate, you can provide preimage data to fulfill a solicitation:

```c
ctx.provide(target_service_id, &data, data_len)!;
```

## Forgetting preimages

Cancel a solicitation when you no longer need the preimage:

```c
ctx.forget((char*)&target_hash, expected_len)!;
```

## Historical lookups (refine only)

During refine, you can look up historical preimages associated with a specific service:

```c
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    types::Hash hash = { /* ... */ };
    char[4096] buf;

    usz? result = ctx.historical_lookup(
        some_service_id,
        (char*)&hash,
        &buf,
        4096
    );

    if (try len = result)
    {
        return ctx.result_ok(&buf, len);
    }
    return ctx.result_empty();
}
```
