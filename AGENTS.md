# jamc3 — C3 SDK and Build Tool for JAM Services

## What is this

`jamc3` is the C3 language SDK for building JAM protocol services, authorizers, and CoreStation guest programs. It provides:

- **`jamc3.c3l/`** — C3 library with JAM host functions, storage, codec, types, logging
- **`jam-build`** — Build script that compiles C3 source → `.jam` blob (or `.polkavm` for guests)
- **`Dockerfile`** — Docker image with all toolchain dependencies

## Build pipeline

```
C3 source (.c3) → c3c → RISC-V objects (.o) → jamtool → JAM blob (.jam)
```

For guest programs (dispatch: `guest_main` only, no host calls):
```
C3 source (.c3) → c3c → RISC-V .o → jamtool → .jam
```

## jam-build usage

```bash
# Build a JAM service (debug mode — includes debug info for clear errors)
jam-build my_service.c3

# Build optimized for deployment
jam-build --release my_service.c3

# Build an authorizer
jam-build --authorizer my_authorizer.c3

# Build a CoreStation guest program
jam-build --guest my_game.c3

# Custom output path and stack size
jam-build --output out/service.jam --stack 262144 my_service.c3
```

### Flags

| Flag | Description | Default |
|------|-------------|---------|
| `--output`, `-o` | Output file path | `build/<name>.jam` |
| `--release` | No debug info (-g0). Enables -O2 for guests only. | off (debug: -O0, -g) |
| `--authorizer` | Build as authorizer (single entry: `is_authorized`) | off |
| `--guest` | Build as CoreStation guest (dispatch: `guest_main` only) | off |
| `--stack <bytes>` | PVM stack size | 131072 (128 KiB) |
| `--sdk-dir <path>` | JAM SDK directory | auto-detect |
| `--keep-intermediates` | Keep .elf/.polkavm files | off |

### Build modes

- **Debug (default):** `-O0 -g` — full debug info, clear error messages, larger output
- **Release:** `-g0`, no debug info. For `--guest` also enables `-O2`. Services always use `-O0` because RISC-V optimization (-O1+) uses registers a6/a7 which don't exist in PolkaVM's 13-register file.

## Docker usage

```bash
# Build the image
docker build -t jamc3 .

# Build a service
docker run --rm -v $(pwd):/app jamc3 my_service.c3

# Build with options
docker run --rm -v $(pwd):/app jamc3 --release --output out/service.jam my_service.c3
```

## Toolchain dependencies

| Tool | Purpose | Source |
|------|---------|--------|
| `c3c` | C3 compiler | [c3lang/c3c](https://github.com/c3lang/c3c) |
| `jamtool` | RISC-V .o → .jam recompiler | [DrEverr/jamtool](https://github.com/DrEverr/jamtool) |
| `clang` | Compile host/guest stubs | LLVM |
| `polkatool` | ELF → .polkavm (guest builds) | polkadot-fellows |

## C3 service structure

A minimal JAM service in C3:

```c3
import jam::types;
import jam::log;

fn void refine(types::RefineArgs* args) @export("refine") {
    // Process work items
}

fn void accumulate(types::AccumulateArgs* args) @export("accumulate") {
    // Apply state changes
}
```

## File layout

```
jamc3.c3l/          C3 SDK library (types, host functions, storage, codec)
scripts/jam-build   Build script
tools/              Build tool sources (polkavm-to-jam)
examples/           Example services
headers/            C header files
Dockerfile          Docker image with full toolchain
```
