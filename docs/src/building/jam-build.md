# jam-build Reference

`jam-build` is the build script that orchestrates the compilation pipeline from C3 source to `.jam` blob.

## Usage

```
jam-build [options] <source.c3> [additional sources...]
```

## Options

| Flag | Description |
|------|-------------|
| `--output` / `-o <path>` | Output file path. Default: `build/<name>.jam` |
| `--release` | Release build: no debug info (`-g0`). For `--guest` builds, also enables `-O2` |
| `--authorizer` | Build as an authorizer (dispatch: `is_authorized`) |
| `--guest` | Build as a CoreStation guest (dispatch: `guest_main`) |
| `--stack <bytes>` | Stack size in bytes. Default: 131072 (128 KiB) |
| `--sdk-dir <path>` | Path to the SDK `jamc3.c3l/` directory. Default: auto-detect |
| `--keep-intermediates` | Keep intermediate `.elf` files next to output |
| `--help` / `-h` | Show help message |

## Build modes

### Debug (default)

```bash
jam-build my_service.c3
```

Compiles with `-O0` and `-g` (debug info). Debug info helps with error messages during development. Both services and guests use `-O0` in debug mode.

### Release

```bash
jam-build --release my_service.c3
```

Compiles with `-g0` (no debug info) for smaller output. Optimization levels differ by target:

- **Services** always use `-O0`. RISC-V optimization at `-O1` and above uses registers `a6` and `a7`, which are not available in PolkaVM's register set.
- **Guests** use `-O2` with `--release`, since CoreStation guests run on full PolkaVM with all registers available.

### Authorizer

```bash
jam-build --authorizer my_auth.c3
```

Builds with the `is_authorized` dispatch entry instead of `refine`/`accumulate`. The SDK includes `entry_authorizer.c3` instead of `entry.c3`.

### Guest

```bash
jam-build --guest my_guest.c3
```

Builds a CoreStation guest binary with a `guest_main` dispatch entry. Requires a `corestation_rt.c3` runtime file near the source and a `guest_stubs.c` file.

## Examples

Build a single-file service:

```bash
jam-build hello.c3
# Output: build/hello.jam
```

Build with custom output path:

```bash
jam-build -o artifacts/my_service.jam my_service.c3
```

Build with multiple source files:

```bash
jam-build main.c3 helpers.c3 math.c3
```

Build a release authorizer with larger stack:

```bash
jam-build --release --authorizer --stack 262144 my_auth.c3
```

Keep intermediate files for debugging:

```bash
jam-build --keep-intermediates my_service.c3
# Intermediate .elf files are preserved in temp directory
```

## Dispatch tables

The build script sets up the correct dispatch table based on the build mode:

| Mode | Dispatch entries |
|------|-----------------|
| Service | `jam_entry_refine, jam_entry_accumulate, jam_entry_accumulate, jam_entry_accumulate` |
| Authorizer | `jam_entry_is_authorized` |
| Guest | `guest_main` |

For services, the same `jam_entry_accumulate` function handles three dispatch slots (accumulate, on_transfer, and on_new_service), since the SDK routes them all through the user's `accumulate` function.

## Tool requirements

The script checks for these tools and exits with an error if any are missing:

- **c3c** -- C3 compiler with `elf-riscv64` target support
- **jamtool** -- RISC-V to `.jam` recompiler
- **clang** (any version from 15 to 20, or unversioned) -- for compiling host stubs

## Environment

The script auto-detects the SDK directory relative to its own location (`../jamc3.c3l`). In Docker, it falls back to `/opt/jamc3/jamc3.c3l`.

You can override this with `--sdk-dir`:

```bash
jam-build --sdk-dir /path/to/jamc3.c3l my_service.c3
```
