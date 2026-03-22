# Host Function Internals

JAM services run inside PolkaVM, a sandboxed environment with no direct access to the outside world. All interaction with the chain -- storage, transfers, logging, preimages -- happens through **host calls**. Here is how they work under the hood.

## The ecall instruction

At the PVM instruction level, a host call is an `ecall` (environment call). When PVM encounters this instruction, it:

1. Reads the host function index from the instruction encoding
2. Reads arguments from registers a0-a5 (up to 6 arguments)
3. Suspends VM execution
4. Calls the host implementation (in the validator node)
5. Places the return value in a0 (or a0+a1 for two-register returns)
6. Resumes VM execution

This is analogous to a syscall in a regular operating system, except the "kernel" is the JAM validator node.

## The host_stubs.c mechanism

Here is the tricky part. C3 (and any language targeting PolkaVM) needs a way to tell the PVM linker "when my code calls the symbol `read`, that should become ecall #3." The C3 compiler does not know about PolkaVM-specific metadata sections. So we use a workaround.

The file `host_stubs.c` is a small C file compiled separately with `clang`. It creates two things for each host function:

1. **A PolkaVM metadata struct** in a special `.polkavm_metadata` ELF section. This struct tells `jamtool` (or `polkatool` in the legacy pipeline) the host call index, the number of input registers, and the number of output registers.

2. **A naked function stub** with the same name as the C3 `@cname` declaration. This stub contains a magic marker that the toolchain recognizes as "this is an import, not real code."

Here is what the macro expansion looks like for the `read` host function (index 3):

```c
// This is what HOST_IMPORT(3, 1, read, 6, ...) expands to:

// Metadata: "read" is import #3, takes 6 input regs, returns 1 reg
static struct PolkaVM_Metadata_V2 read__IMPORT_METADATA
    __attribute__ ((section(".polkavm_metadata"), used)) = {
    2, 0, sizeof("read") - 1, "read", 6, 1, 1, 3
};

// Stub function: naked, just contains the magic marker + ret
uint64_t __attribute__ ((naked, used)) read(...) {
    __asm__(
        ".word 0x0000000b\n"        // Magic marker for polkatool
        ".quad %[metadata]\n"       // Pointer to metadata
        "ret\n"
        :
        : [metadata] "i" (&read__IMPORT_METADATA)
        : "memory"
    );
}
```

When `jamtool` processes the linked object files, it finds these metadata sections and magic markers, and replaces the stub call sites with proper `ecall` instructions in the final PVM bytecode.

## Exports work similarly

Entry points that PVM needs to call (like `jam_entry_refine`) are exported using a similar mechanism. The `HOST_EXPORT` macro in `host_stubs.c` creates:

1. A metadata struct with the function name and register counts
2. An entry in the `.polkavm_exports` section pointing to the actual C3 function

The C3 function is declared with `@export("jam_entry_refine")` which makes it visible as a global symbol. The stub file references it with `extern void jam_entry_refine()` and creates the PolkaVM export metadata.

This is why both `@export` in C3 and `HOST_EXPORT` in the stubs file are needed -- the C3 side provides the implementation, the stubs side provides the PolkaVM metadata.

## The dispatch table

The dispatch table is the bridge between the JAM protocol and your code. When the chain wants to call your service, it uses a numeric index:

### Service dispatch

| Index | Meaning | Maps to |
|-------|---------|---------|
| 0 | Refine | `jam_entry_refine` |
| 1 | Accumulate | `jam_entry_accumulate` |
| 2 | On-transfer | `jam_entry_accumulate` |
| 3 | On-timeout | `jam_entry_accumulate` |

Indices 1, 2, and 3 all invoke the same `jam_entry_accumulate` function. The JAM protocol calls index 2 when your service receives a transfer and index 3 on timeout, but the SDK routes all three to your single `accumulate()` hook. The `jam-build` script passes this table to jamtool:

```bash
jamtool --dispatch "jam_entry_refine,jam_entry_accumulate,jam_entry_accumulate,jam_entry_accumulate" ...
```

### Authorizer dispatch

| Index | Meaning | Maps to |
|-------|---------|---------|
| 0 | Is authorized? | `jam_entry_is_authorized` |

Authorizers have a single entry point. Build with `jam-build --authorizer`.

### Guest dispatch (CoreStation)

| Index | Meaning | Maps to |
|-------|---------|---------|
| 0 | Guest main | `guest_main` |

Guests also have a single entry point. Build with `jam-build --guest`.

## Host function indices

For reference, here are all 27 host functions and their indices as defined by the JAM protocol:

**General (available in both refine and accumulate):**

| Index | Function | Purpose |
|-------|----------|---------|
| 0 | `gas` | Query remaining gas |
| 1 | `fetch` | Fetch chain data (params, entropy, traces, inputs) |
| 2 | `lookup` | Look up preimage by hash |
| 3 | `read` | Read from service storage |
| 4 | `write` | Write to own service storage |
| 5 | `info` | Get service account info |
| 100 | `log` | Log a message |

**Refine-only:**

| Index | Function | Purpose |
|-------|----------|---------|
| 6 | `historical_lookup` | Historical preimage lookup |
| 7 | `export` | Export data segment |
| 8 | `machine` | Create sub-VM |
| 9 | `peek` | Read sub-VM memory |
| 10 | `poke` | Write sub-VM memory |
| 11 | `pages` | Set sub-VM page permissions |
| 12 | `invoke` | Run sub-VM |
| 13 | `expunge` | Destroy sub-VM |

**Accumulate-only:**

| Index | Function | Purpose |
|-------|----------|---------|
| 14 | `bless` | Set privileged services (manager-only) |
| 15 | `assign` | Assign authorizers to core |
| 16 | `designate` | Set pending validator keys |
| 17 | `checkpoint` | Commit state checkpoint |
| 18 | `new` | Create new service |
| 19 | `upgrade` | Upgrade service code |
| 20 | `transfer` | Transfer tokens |
| 21 | `eject` | Destroy service account |
| 22 | `query` | Query preimage status |
| 23 | `solicit` | Request preimage |
| 24 | `forget` | Cancel preimage request |
| 25 | `yield` | Set accumulation output hash |
| 26 | `provide` | Provide preimage data |

## Why this matters

Most of the time, you interact with host functions through the SDK's typed wrappers (`ctx.kv_read()`, `ctx.transfer()`, etc.) and never think about indices or metadata sections. But knowing how the plumbing works helps when:

- You get linker errors about unresolved symbols (check that `host_stubs.c` is being compiled and linked)
- Your service deploys but crashes on the first call (check the dispatch table)
- You want to add a new host function that the SDK does not wrap yet
- You are debugging at the PVM instruction level with `polkatool disassemble`
