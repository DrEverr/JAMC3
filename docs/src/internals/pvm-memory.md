# PVM Memory Model

PolkaVM (PVM) is the virtual machine that executes JAM services. It is based on the RISC-V ISA but has its own constraints. Understanding the memory model helps you write efficient services and avoid subtle bugs.

## Register file

PVM has **13 registers**, a subset of the full RISC-V register set:

| Register | RISC-V name | Purpose |
|----------|------------|---------|
| a0 | x10 | Argument/return 1 |
| a1 | x11 | Argument/return 2 |
| a2 | x12 | Argument 3 |
| a3 | x13 | Argument 4 |
| a4 | x14 | Argument 5 |
| a5 | x15 | Argument 6 |
| t0 | x5 | Temporary |
| t1 | x6 | Temporary |
| t2 | x7 | Temporary |
| s0 | x8 | Saved / frame pointer |
| s1 | x9 | Saved |
| ra | x1 | Return address |
| sp | x2 | Stack pointer |

Notably absent: **a6 (x16) and a7 (x17) do not exist in PVM**. This is the reason services must be compiled with `-O0`. The RISC-V C compiler at optimization levels `-O1` and above will use `a6`/`a7` for register allocation, producing code that crashes or silently corrupts data in PVM.

This also limits function signatures to **6 arguments** (a0-a5). The SDK is carefully designed around this constraint -- you will notice that methods like `bless()` which would need 7+ arguments (6 host call args + the `self` pointer) are not exposed as `Ctx` methods. Instead, you call the raw host function directly.

## Memory layout

When PVM instantiates your service, memory is laid out as follows:

```
Address space (low to high):
+---------------------------+  0x00000000
|  RO Section               |  Code + read-only data
|  (from .jam blob)         |  Immutable at runtime
+---------------------------+
|  RW Section               |  Initialized globals
|  (from .jam blob)         |  Writable at runtime
+---------------------------+
|  Heap (grows up)          |  Dynamic allocation
|  (not used by jamc3)      |  (no allocator in SDK)
+---------------------------+
|         ...               |
|  (unmapped gap)           |
|         ...               |
+---------------------------+
|  Stack (grows down)       |  Local variables, call frames
|  Default: 128 KiB         |  Starts at top of allocation
+---------------------------+  Stack base
```

## Stack behavior

The stack grows **downward** (from high addresses to low), following standard RISC-V convention. The default size is **128 KiB** (131,072 bytes), configurable via `jam-build --stack <bytes>`.

Important things to know about the stack:

- **No guard page**. If you overflow the stack, you silently corrupt the heap or RW section. There is no segfault, just wrong behavior.
- **The entry point pre-allocates a large buffer**. The accumulate entry in `entry.c3` allocates a 65,536-byte (64 KiB) buffer on the stack for input decoding. This means your `accumulate()` function effectively has about 64 KiB of stack remaining with the default size.
- **Recursive functions are risky**. Each call frame consumes stack space. Deep recursion on a 128 KiB stack can overflow quickly.

If you need more stack, increase it:

```bash
jam-build --stack 262144 my_service.c3  # 256 KiB
```

## Why -O0 is required for services

This deserves emphasis because it is the most common source of mysterious bugs.

The C3 compiler (`c3c`) targets standard RISC-V when generating code. At `-O1` and above, the RISC-V backend may:

1. **Spill values into a6/a7** -- these registers do not exist in PVM, so the values vanish.
2. **Use a6/a7 for function arguments** -- if the optimizer decides to pass more than 6 arguments in registers, the extra ones go into a6/a7 and are lost.
3. **Perform register renaming** -- optimized code may rewrite register assignments in ways that hit the missing registers.

The result is not a crash -- it is silently wrong computation. Your service runs, produces output, and the output is garbage.

The `jam-build` script enforces `-O0` for all service builds, even with `--release`. The only exception is CoreStation guest builds (`--guest --release`), which run on a full PolkaVM with the complete register set.

## No floating point

PVM has **no floating-point unit**. The C3 compiler is invoked with `--riscv-abi=int-only` which tells it to never emit floating-point instructions.

If your code uses `float` or `double`, the compiler will either reject it or generate software floating-point calls that do not link. Stick to integer arithmetic.

## Gas costs for memory operations

Every memory access in PVM costs gas. The costs are defined by the JAM protocol, but the general principle is:

- **Reads are cheap** -- loading from memory is a single-gas-unit operation.
- **Writes are more expensive** -- especially to storage (host calls), which go through the state trie.
- **Host calls have fixed overhead** -- each `ecall` instruction costs gas regardless of what the host function does, plus the host function's own gas cost.

There is no way to query the exact gas cost of an operation from within PVM. Use `ctx.gas()` before and after operations to measure empirically during development.
