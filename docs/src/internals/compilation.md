# Compilation Pipeline Details

Here is the full journey from C3 source code to a deployable `.jam` blob. Understanding this pipeline helps when things go wrong or when you want to customize the build process.

## The pipeline at a glance

```
┌─────────┐     ┌─────────┐     ┌───────────┐     ┌──────────┐
│ C3 src  │────>│   c3c   │────>│ RISC-V .o │────>│ jamtool  │────> .jam
│ (.c3)   │     │compiler │     │  (ELF)    │     │          │
└─────────┘     └─────────┘     └───────────┘     └──────────┘
                                       ▲
┌──────────────┐   ┌───────┐           │
│ host_stubs.c │──>│ clang │──> host_stubs.o
└──────────────┘   └───────┘
```

Three tools, two compilation steps, one output:

1. **c3c** compiles your C3 service code (plus the SDK `.c3` files) into RISC-V object files.
2. **clang** compiles `host_stubs.c` into a RISC-V object file containing PolkaVM metadata.
3. **jamtool** takes all the `.o` files, links them, translates RISC-V to PVM bytecode, and writes the `.jam` blob.

## Step 1: C3 to RISC-V objects

The C3 compiler (`c3c`) compiles your service module and all SDK modules into RISC-V ELF object files.

```bash
c3c compile-only \
    --target elf-riscv64 \
    --use-stdlib=no \
    --link-libc=no \
    --reloc=pic \
    --riscv-cpu=rvimac \
    --riscv-abi=int-only \
    -g -O0 \
    --obj-out build/obj/ \
    /path/to/jamc3.c3l/*.c3 \
    my_service.c3
```

Key flags explained:

| Flag | Why |
|------|-----|
| `--target elf-riscv64` | PVM is based on 64-bit RISC-V |
| `--use-stdlib=no` | No standard library in PVM -- bare metal |
| `--link-libc=no` | No libc either |
| `--reloc=pic` | Position-independent code for PVM's address space |
| `--riscv-cpu=rvimac` | PVM implements the RV64IMAC subset (Integer, Multiply, Atomic, Compressed) |
| `--riscv-abi=int-only` | No floating-point registers or instructions |
| `-O0` | Required for services (see below) |
| `-g` | Debug info (dropped with `--release`) |

The output is a set of `.o` files in `build/obj/`, one per C3 module.

## Step 2: Compile host stubs

The host stubs file provides PolkaVM import/export metadata that the C3 compiler cannot generate directly. It is compiled with clang targeting the same RISC-V ISA:

```bash
clang \
    --target=riscv64-unknown-none-elf \
    -march=rv64imac_zbb -mabi=lp64 \
    -fpic -fPIE -mrelax \
    -nostdinc -nostdlib -fno-builtin \
    -c -o build/obj/host_stubs.o \
    /path/to/jamc3.c3l/host_stubs.c
```

For authorizer builds, `-DJAM_BUILD_AUTHORIZER=1` is passed to clang so the stubs file exports `jam_entry_is_authorized` instead of `jam_entry_refine` and `jam_entry_accumulate`.

## Step 3: jamtool links and translates

`jamtool` is where the real magic happens. It takes all the `.o` files and produces a `.jam` blob:

```bash
jamtool \
    --dispatch "jam_entry_refine,jam_entry_accumulate,jam_entry_accumulate,jam_entry_accumulate" \
    --min-stack-size 131072 \
    -o my_service.jam \
    build/obj/*.o build/obj/host_stubs.o
```

Internally, jamtool performs these steps:

1. **Link** -- resolve all symbol references across the object files. Your C3 code references `read`, `write`, `gas`, etc. These are provided by `host_stubs.o` as naked stubs with PolkaVM metadata.

2. **Relocate** -- patch all addresses. RISC-V object files contain relocations (references to symbols by name). jamtool resolves these into concrete addresses in the flat PVM memory space.

3. **Translate** -- convert RISC-V instructions into PVM bytecode. PVM uses its own compact instruction encoding, not raw RISC-V. jamtool maps each RISC-V instruction to its PVM equivalent, replacing host call stubs with `ecall` instructions.

4. **Build dispatch table** -- the `--dispatch` argument is a comma-separated list of function names. Each position in the list becomes a dispatch table entry (index 0, 1, 2, 3...).

5. **Serialize** -- write the final `.jam` binary with RO section, RW section, stack size, and dispatch table.

## Why RISC-V?

PVM is based on the RISC-V ISA because:

- **Well-defined, open standard** -- no proprietary extensions or ambiguity.
- **Simple instruction set** -- easy to implement a correct, auditable VM.
- **Compiler support** -- LLVM (and therefore C3, Rust, C, etc.) has mature RISC-V backends.
- **Subset-friendly** -- PVM only implements the `rvimac` subset. Compilers can target this subset cleanly.

PVM is not a full RISC-V implementation. It strips out floating-point, most of the register file, and privileged instructions. What remains is a clean, deterministic computation engine.

## Why int-only ABI?

PVM has no floating-point unit. The `--riscv-abi=int-only` flag tells the C3 compiler:

- Do not use floating-point registers (f0-f31)
- Do not emit floating-point instructions (fadd, fmul, etc.)
- Pass all values in integer registers

If you accidentally use `float` or `double` in your service code, you will get a compile-time or link-time error rather than a silent runtime failure.

## The legacy pipeline

Before `jamtool` existed, the build pipeline used three separate tools:

```
C3 src -> c3c -> RISC-V .o -> ld.lld (link) -> ELF -> polkatool -> .polkavm -> polkavm-to-jam -> .jam
```

This legacy pipeline is still available (`polkavm-to-jam` is included in the Docker image) but `jamtool` is preferred because:

- Single tool instead of three
- Faster (no intermediate ELF linking step)
- Better error messages
- Handles relocations more correctly for PVM

The `jam-build` script uses `jamtool` by default.

## Debug vs release builds

| Aspect | Debug (default) | Release (`--release`) |
|--------|-----------------|----------------------|
| Optimization | `-O0` | `-O0` for services, `-O2` for guests |
| Debug info | `-g` (included) | `-g0` (stripped) |
| Blob size | Larger | Smaller |
| Error messages | More detailed | Minimal |
| Build speed | Same | Same |

For services, **optimization is always `-O0`** regardless of build mode. This is because RISC-V optimization uses registers `a6`/`a7` which do not exist in PVM's 13-register file. The `jam-build` script enforces this.

CoreStation guests (`--guest`) run on full PolkaVM which has the complete RISC-V register set, so they can safely use `-O2` in release mode.

The practical difference between debug and release for services is just the debug info. Debug info makes the blob larger but does not affect runtime behavior. Strip it for deployment to save on-chain storage costs.

## Building without jam-build

If you want to run the pipeline manually (for custom builds, CI integration, etc.), here is the sequence:

```bash
# 1. Compile C3 sources
c3c compile-only \
    --target elf-riscv64 \
    --use-stdlib=no --link-libc=no \
    --reloc=pic --riscv-cpu=rvimac --riscv-abi=int-only \
    -g -O0 \
    --obj-out obj/ \
    path/to/jamc3.c3l/*.c3 \
    my_service.c3

# 2. Compile host stubs
clang --target=riscv64-unknown-none-elf \
    -march=rv64imac_zbb -mabi=lp64 \
    -fpic -fPIE -mrelax \
    -nostdinc -nostdlib -fno-builtin \
    -c -o obj/host_stubs.o \
    path/to/jamc3.c3l/host_stubs.c

# 3. Link + translate + serialize
jamtool \
    --dispatch "jam_entry_refine,jam_entry_accumulate,jam_entry_accumulate,jam_entry_accumulate" \
    --min-stack-size 131072 \
    -o my_service.jam \
    obj/*.o
```

Make sure all tools are on your PATH and you pass the correct SDK path. The Docker workflow handles all of this automatically.
