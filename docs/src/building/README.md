# Building

jamc3 compiles C3 source code into `.jam` blobs through a multi-step pipeline. This section covers the build system in detail.

## Build pipeline

```
C3 source (.c3)
      |
      v
  c3c compile-only (--target elf-riscv64)
      |
      v
  RISC-V object files (.o)
      |
      v                    host_stubs.c
  jamtool (link + recompile + serialize)  <--  clang (RISC-V .o)
      |
      v
  .jam blob
```

1. **c3c** compiles your C3 sources and the SDK modules into RISC-V object files using the `elf-riscv64` target with `rvimac` CPU and `int-only` ABI.
2. **clang** compiles `host_stubs.c`, which contains PolkaVM metadata sections that declare the host function imports and dispatch table exports.
3. **jamtool** links all object files, translates them to PolkaVM bytecode, and serializes the final `.jam` blob with the correct dispatch table.

## Build modes

There are three types of builds:

- **Service** (default) -- produces a `.jam` blob with `refine` and `accumulate` dispatch entries.
- **Authorizer** (`--authorizer`) -- produces a `.jam` blob with an `is_authorized` dispatch entry.
- **Guest** (`--guest`) -- produces a CoreStation guest binary with a `guest_main` dispatch entry.

## Quick reference

```bash
# Build a service (Docker)
docker run --rm --platform=linux/amd64 \
  -v $(pwd):/app ghcr.io/dreverr/jamc3 my_service.c3

# Build a service (native)
jam-build my_service.c3

# Build with options
jam-build --release --output build/my_svc.jam my_service.c3

# Build an authorizer
jam-build --authorizer my_auth.c3
```

## Sections

- [jam-build Reference](./jam-build.md) -- all flags and options for the build script.
- [Docker Workflow](./docker.md) -- using the Docker image for builds.
- [Native Build Setup](./native.md) -- building without Docker.
- [Building CoreStation Guests](./guest.md) -- building guest programs for CoreStation.
