# Submitting Work Packages

After deploying a service and setting up authorization, you can submit work packages to trigger the refine-accumulate cycle.

## Basic submission

```bash
jam-cli --rpc ws://localhost:19800 submit-work \
  --service <service-id> \
  --core <core-index> \
  --payload <hex-encoded-data>
```

## Work package structure

A work package contains:

- **Target core** -- which core should process this package.
- **Authorizer** -- which authorizer hash must approve it.
- **Work items** -- one or more items, each with a target service and payload.

## What happens after submission

1. **Authorization** -- the authorizer assigned to the target core runs `is_authorized` to check the package.
2. **Refine** -- each work item is processed by its target service's `refine` function. The payload you submitted is available via `ctx.payload()`.
3. **Attestation** -- validators attest to the refine results.
4. **Accumulate** -- once attested, the work digests are passed to each service's `accumulate` function as operand inputs.

## Sending data in the payload

The payload is an arbitrary byte sequence. Your service defines its own format. For example, using a single byte to indicate a Fibonacci number to compute:

```bash
# Send payload 0x0A (decimal 10) to compute fib(10)
jam-cli --rpc ws://localhost:19800 submit-work \
  --service 42 \
  --core 0 \
  --payload 0a
```

Your refine function decodes this:

```c
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    ulong n = 10;  // default
    if (ctx.payload() != null && ctx.payload_len() > 0)
    {
        codec::DecodeCtx dec = codec::decode_ctx_init(
            ctx.payload(), ctx.payload_len()
        );
        ulong? v = codec::decode_u8(&dec);
        if (try val = v) { n = val; }
    }

    // Compute and return result...
    return ctx.result_ok(&result_buf, result_len);
}
```

## Verifying results

After accumulation, check your service's storage to verify the results:

```bash
jam-cli --rpc ws://localhost:19800 read-storage \
  --service <service-id> \
  --key <hex-encoded-key>
```

Or check the node logs for your service's log messages:

```
[INFO  hello] Hello World from Accumulate!
[DEBUG my_svc] counter: 1
```

## Gas considerations

Each work item has a gas limit for refine. If your computation exceeds the gas limit, the work digest will have status `OUT_OF_GAS` and no output data will be available in accumulate.

Monitor gas usage during development:

```c
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    log::debug_u64("svc", "gas at start", ctx.gas());

    // ... computation ...

    log::debug_u64("svc", "gas at end", ctx.gas());
    return ctx.result_ok(&buf, len);
}
```
