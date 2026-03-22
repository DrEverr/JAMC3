# Tips & Best Practices

Hard-won advice for writing JAM services in C3. Most of this comes from debugging real services on PolkaVM -- learn from others' mistakes.

## Keep refine pure

Refine runs off-chain on validator nodes. It should be a pure function: take the work payload in, produce a result out. No storage writes, no transfers, no state mutations.

```c
// Good: refine computes and returns
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    char* payload = ctx.payload();
    ulong len = ctx.payload_len();

    // Process the payload, produce output
    char[256] result;
    usz result_len = do_computation(payload, len, &result);

    return ctx.result_ok(&result, result_len);
}
```

The SDK enforces this at the type level -- `refine::Ctx` simply does not expose `kv_write()`, `transfer()`, or any other mutation method. If you try to call them, the compiler will reject it.

## Accumulate is where state changes happen

All persistent effects happen in accumulate: writing to storage, transferring tokens, creating services, checkpointing. This runs on-chain and is metered by gas.

```c
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    // Read current state
    char[4] key = { 'd', 'a', 't', 'a' };
    char[256] buf;
    usz? bytes = ctx.kv_read(&key, 4, &buf, 256);

    // Modify state
    char[8] new_value;
    // ... compute new_value ...

    // Write back
    ctx.kv_write(&key, 4, &new_value, 8)!;

    // Checkpoint to commit
    ctx.checkpoint();
}
```

## Use logging liberally during development

Logs are your only window into what happens inside PolkaVM. Use them everywhere during development.

```c
import jam::log;

fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    log::info("myservice", "Refine: entry");
    log::debug_u64("myservice", "payload_len", ctx.payload_len());

    // ... do work ...

    log::info("myservice", "Refine: done");
    return ctx.result_ok(&result, result_len);
}
```

Log levels (from `jam::log`):
- `log::err()` -- something broke, the operation cannot continue
- `log::warn()` -- something unexpected but recoverable
- `log::info()` -- high-level milestones ("Refine: entry", "Accumulate: stored 42")
- `log::debug()` -- detailed internal state
- `log::trace()` -- very verbose, step-by-step execution

The first argument is the "target" string (think log category). Use your service name so you can filter logs in a busy testnet.

For logging numeric values, use `log::debug_u64()`:

```c
log::debug_u64("myservice", "counter", counter);
// Output: "counter: 42"
```

## Start with debug builds

The default build mode (`jam-build` without `--release`) uses `-O0` and includes debug info. This gives you clearer error messages if something goes wrong in PVM execution.

Only switch to `--release` for final deployment. Even then, services still compile with `-O0` (only guests benefit from `-O2`). The `--release` flag for services mainly drops debug info to reduce blob size.

```bash
# During development
jam-build my_service.c3

# Final deployment
jam-build --release -o my_service.jam my_service.c3
```

## Test with small payloads first

Start with trivial inputs and work up. If your refine panics with a complex payload, you have no stack trace to debug with. Small payloads make it obvious where things go wrong.

## Keep storage keys short and consistent

Storage keys cost gas proportional to their length. Use short, fixed-length keys. If you need multiple keys, establish a naming convention.

```c
// Good: short, fixed-size keys
char[4] counter_key = { 'c', 'n', 't', 'r' };
char[4] state_key   = { 's', 't', 'a', 't' };

// If you need namespaced keys, use a prefix byte
char[5] user_key = { 'u', /* 4-byte user id */ };
```

Avoid dynamically constructed keys when possible -- they are harder to debug and easier to get wrong.

## Handle errors gracefully

Panics in PVM waste gas and produce no useful output. Always handle errors with C3's optional/fault system instead of letting things crash.

```c
// Bad: ignoring errors
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    // If kv_read fails, this crashes. Gas wasted, no output.
    char[8] buf;
    usz bytes = ctx.kv_read(&key, 4, &buf, 8)!!;
}

// Good: handling errors
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    char[8] buf;
    usz? maybe_bytes = ctx.kv_read(&key, 4, &buf, 8);
    if (catch maybe_bytes)
    {
        // Key doesn't exist yet, use default
        log::info("myservice", "No existing data, starting fresh");
    }
}
```

The `!` operator re-raises a fault to the caller. The `!!` operator unwraps or panics. Prefer `if (catch ...)` or `if (try ...)` for explicit control flow.

## Gas management

Refine and accumulate have separate gas budgets set by the work package submitter. Here is what you need to know:

- **Check remaining gas** with `ctx.gas()` if doing variable-length work.
- **Checkpoint often** in accumulate. `ctx.checkpoint()` commits all storage writes since the last checkpoint and returns gas consumed. If accumulate runs out of gas, uncommitted writes since the last checkpoint are rolled back.
- **Storage operations cost gas** -- reads are cheap, writes are expensive.
- **Host calls cost gas** -- each one deducts from your budget.

```c
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    // Process items, checkpointing periodically
    accumulate::InputIter iter = ctx.inputs();
    types::AccumulateInput? maybe_input = iter.next();

    while (try input = maybe_input)
    {
        process_input(ctx, &input);

        // Commit progress periodically
        ctx.checkpoint();

        maybe_input = iter.next();
    }
}
```

## Structure your code

Separate business logic from JAM boilerplate. Your `refine()` and `accumulate()` entry points should be thin wrappers that decode input, call your logic, and encode output.

```c
module myservice;

import jam::types;
import jam::refine;
import jam::accumulate;
import jam::log;

// Business logic -- testable, reusable
fn ulong compute(char* data, usz len)
{
    // ... your actual computation ...
    return 42;
}

// Thin entry points
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    ulong result = compute(ctx.payload(), (usz)ctx.payload_len());

    char[8] out;
    // ... encode result into out ...
    return ctx.result_ok(&out, 8);
}

fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    // ... iterate inputs, call business logic, store results ...
}
```

## Common pitfalls

### Forgetting to export entry points

Your `refine` and `accumulate` functions **must** have `@export("refine")` and `@export("accumulate")` attributes. Without them, the SDK's `entry.c3` cannot find your functions and the build will fail with a linker error.

```c
// Wrong: missing @export
fn types::RefineResult refine(refine::Ctx* ctx) { ... }

// Right
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine") { ... }
```

### Stack overflow with default 128 KiB

The default stack size is 128 KiB (`--stack 131072`). Large local arrays can blow through this quickly. The accumulate entry point already allocates a 65,536-byte buffer for input decoding, leaving you about 64 KiB.

If you need large buffers, keep them small or consider splitting work across multiple accumulate rounds.

```c
// Dangerous: 64 KiB on the stack, on top of the entry point's 64 KiB buffer
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    char[65536] my_buffer;  // This might overflow!
}

// Safer: use a smaller buffer
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    char[4096] my_buffer;  // Plenty of room
}
```

You can increase the stack with `jam-build --stack 262144` (256 KiB) but this increases your blob size.

### Wrong dispatch table

The dispatch table maps entry point indices to functions. For services, the standard mapping is:

- Index 0: `jam_entry_refine`
- Index 1, 2, 3: `jam_entry_accumulate` (accumulate is called for multiple dispatch reasons)

For authorizers: index 0 is `jam_entry_is_authorized`.

The `jam-build` script handles this automatically. If you are building manually, make sure you get the `--dispatch` argument right or your service will crash when the chain tries to call it.

### Building with optimization enabled

Services **must** be compiled with `-O0`. The RISC-V optimizer uses registers `a6` and `a7` which do not exist in PolkaVM (it only has `a0`-`a5` plus a few others, 13 total). Optimized code will silently produce wrong results or crash.

The `jam-build` script enforces this -- it always uses `-O0` for services regardless of `--release`. Only guest builds (CoreStation) can use `-O2`.
