# Quick Start

Build your first JAM service in five minutes.

## 1. Create your service

Create a directory for your project and a single C3 source file:

```bash
mkdir hello-jam && cd hello-jam
```

Create `hello.c3`:

```c
module hello;

import jam::types;
import jam::refine;
import jam::accumulate;
import jam::log;

// Refine: off-chain computation.
// Receives a work item and returns a result.
fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    log::info("hello", "Hello World from Refine!");

    char[5] result = { 'h', 'e', 'l', 'l', 'o' };
    return ctx.result_ok(&result, 5);
}

// Accumulate: on-chain state transition.
// Processes refined results and updates service storage.
fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    log::info("hello", "Hello World from Accumulate!");
}
```

Every JAM service must export two functions: `refine` and `accumulate`. The SDK provides typed context objects (`refine::Ctx` and `accumulate::Ctx`) that give you access to the appropriate host functions for each phase.

## 2. Build with Docker

```bash
docker run --rm --platform=linux/amd64 \
  -v $(pwd):/app \
  ghcr.io/dreverr/jamc3 hello.c3
```

Or if building natively:

```bash
jam-build hello.c3
```

Output:

```
Building service (debug): hello.c3 -> build/hello.jam

[1] Compiling C3 -> RISC-V objects...
  -> 12 object files
[2] Compiling host stubs...
  -> /tmp/.../obj/host_stubs.o
[3] jamtool -> .jam...

Build complete: build/hello.jam
Size: 1234 bytes
```

The result is `build/hello.jam`, a binary blob ready for deployment on a JAM chain.

## 3. What just happened?

The build pipeline ran these steps:

1. **c3c** compiled your C3 source (plus the SDK modules) into RISC-V object files.
2. **clang** compiled `host_stubs.c`, which provides PolkaVM metadata for host function imports.
3. **jamtool** linked the objects and produced the final `.jam` blob with the dispatch table for `refine` and `accumulate`.

## 4. Next steps

- Add [storage](./concepts/storage.md) to persist data between accumulate rounds.
- Learn about [work packages](./concepts/work-packages.md) to understand how data flows through the system.
- Read the [SDK reference](./sdk/README.md) for the full API.
- [Deploy your service](./deploying/README.md) to a local testnet.

## A more complete example

Here is a service that computes Fibonacci numbers in refine and stores the result in accumulate:

```c
module fib;

import jam::codec;
import jam::log;
import jam::types;
import jam::refine;
import jam::accumulate;
import jam::storage;

fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    // Default to fib(10) if no payload
    ulong value = 10;
    if (ctx.payload() != null && ctx.payload_len() > 0)
    {
        codec::DecodeCtx dec = codec::decode_ctx_init(
            ctx.payload(), ctx.payload_len()
        );
        ulong? decoded = codec::decode_u8(&dec);
        if (try v = decoded) { value = v; }
    }

    ulong result = fib_calc(value);

    char[8] buf;
    if (catch codec::encode_u64(&buf, 8, result))
    {
        return ctx.result_empty();
    }
    return ctx.result_ok(&buf, 8);
}

fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    // Iterate over inputs and store the first successful result
    accumulate::InputIter iter = ctx.inputs();
    while (true)
    {
        types::AccumulateInput? maybe_input = iter.next();
        if (catch maybe_input) break;
        types::AccumulateInput input = maybe_input;

        if (input.kind == types::AccumulateInputKind.OPERAND
            && input.operand.digest_output.status == types::WorkDigestStatus.OK
            && input.operand.digest_output.data_len >= 8)
        {
            char[4] key = { 'f', 'i', 'b', 'r' };
            ctx.kv_write(
                &key, 4,
                input.operand.digest_output.data, 8
            )!;
            break;
        }
    }
}

fn ulong fib_calc(ulong n)
{
    ulong a;
    ulong b = 1;
    for (ulong i; i < n; i++)
    {
        ulong t = a + b;
        a = b;
        b = t;
    }
    return a;
}
```
