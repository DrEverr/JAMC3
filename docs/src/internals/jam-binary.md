# .jam Binary Format

When you run `jam-build`, the final output is a `.jam` file. This is the deployable blob that gets uploaded to the JAM chain and executed by PolkaVM. Here is what is inside it.

## High-level structure

A `.jam` file is a serialized PVM program. It contains everything PolkaVM needs to instantiate and run your service:

1. **Read-only (RO) section** -- compiled PVM bytecode (your code) plus any constant data. This section is immutable at runtime.
2. **Read-write (RW) section** -- initialized global variables. This gets copied into writable memory when the VM starts.
3. **Stack reservation** -- specifies how much stack memory to allocate (default 128 KiB).
4. **Dispatch table** -- maps entry point indices (0, 1, 2, 3) to code offsets within the RO section.

The format is defined by the JAM protocol specification and is what the chain validators expect when they execute your service.

## How jamtool produces it

`jamtool` takes one or more RISC-V `.o` files (ELF object files) and transforms them:

1. **Link** -- resolves symbols across all object files (your C3 code + host_stubs.o). No external linker needed; jamtool does this internally.
2. **Relocate** -- patches all addresses to work in PVM's flat memory model.
3. **Translate** -- converts RISC-V machine instructions into PVM bytecode. PVM is *based on* RISC-V but uses its own compact encoding.
4. **Build dispatch table** -- reads the `--dispatch` argument to map entry point names to indices.
5. **Serialize** -- writes everything into the `.jam` binary format.

## Section layout

```
+-----------------------------+
|  Header / metadata          |
+-----------------------------+
|  RO section (code + consts) |
|  - PVM bytecode             |
|  - String literals          |
|  - Other read-only data     |
+-----------------------------+
|  RW section (globals)       |
|  - Initialized variables    |
|  - (zero-initialized data)  |
+-----------------------------+
|  Stack size declaration     |
+-----------------------------+
|  Dispatch table             |
|  - index 0 -> offset        |
|  - index 1 -> offset        |
|  - ...                      |
+-----------------------------+
```

Sections are aligned as required by PVM. The RO section comes first because it is typically the largest part of the binary.

## Dispatch table entries

For a standard service, the dispatch table has four entries:

| Index | Entry point | Purpose |
|-------|------------|---------|
| 0 | `jam_entry_refine` | Off-chain computation |
| 1 | `jam_entry_accumulate` | On-chain state transition |
| 2 | `jam_entry_accumulate` | On-transfer handler |
| 3 | `jam_entry_accumulate` | On-timeout handler |

Indices 1, 2, and 3 all point to the same `jam_entry_accumulate` function. The protocol invokes different indices depending on the reason for the accumulate call, but the SDK routes them all to your single `accumulate()` function.

For an authorizer, there is one entry:

| Index | Entry point | Purpose |
|-------|------------|---------|
| 0 | `jam_entry_is_authorized` | Authorization check |

For a CoreStation guest:

| Index | Entry point | Purpose |
|-------|------------|---------|
| 0 | `guest_main` | Guest entry point |

## Inspecting a .jam file

You can use `polkatool` to disassemble PVM bytecode and inspect the contents:

```bash
polkatool disassemble my_service.jam
```

This shows the PVM instructions, section boundaries, and entry points. It is useful for:

- Verifying your dispatch table is correct
- Checking that symbols were exported properly
- Understanding the size breakdown of your binary
- Debugging crashes by correlating PVM instruction offsets with source code

## Size considerations

Typical service sizes:

- Hello World: ~2-4 KiB
- Storage demo: ~4-8 KiB
- Complex services: 10-50 KiB

The main contributors to size are:
- Code complexity (more functions = more bytecode)
- String literals (log messages, key names)
- Stack reservation (128 KiB is reserved but not all stored in the blob)
- Debug info (stripped in `--release` mode)

Use `--release` to drop debug info and reduce blob size for deployment.
