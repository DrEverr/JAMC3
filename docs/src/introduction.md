# Introduction

**jamc3** is a SDK for building [JAM](https://graypaper.com/) protocol services in [C3](https://c3-lang.org/). It includes a C3 library for writing service code, a build tool that compiles it into `.jam` blobs, and a Docker image with the entire toolchain pre-installed.

## What's inside

- **C3 library** (`jamc3.c3l`) — all JAM protocol types, 27 host function bindings, storage API, binary codec, logging, and typed contexts for refine/accumulate/authorizer entry points. Bare metal — no stdlib, no libc.
- **Build tool** (`jam-build`) — takes your C3 source and produces a deployable `.jam` file in one command. Handles the full pipeline: C3 → RISC-V objects → PVM bytecode.
- **Docker image** (`ghcr.io/dreverr/jamc3`) — zero-setup build environment with c3c, jamtool, clang, and the SDK pre-installed.

## Quick taste

```bash
# Write a service
cat > my_service.c3 << 'EOF'
import jam::types;
import jam::log;

fn void refine(types::RefineArgs* args) @export("refine") {
    log::info("refine called");
}

fn void accumulate(types::AccumulateArgs* args) @export("accumulate") {
    log::info("accumulate called");
}
EOF

# Build it
docker run --rm -v $(pwd):/app ghcr.io/dreverr/jamc3 my_service.c3

# Deploy it
jam-cli deploy-service --jam-file build/my_service.jam
```

## Why C3?

[C3](https://c3-lang.org/) is a systems language that modernizes C with modules, better error handling, and a cleaner type system — while still compiling to efficient native code. Its RISC-V backend makes it a natural fit for PolkaVM, the virtual machine that powers JAM services.

## How JAM services work

JAM (Join-Accumulate Machine) is a blockchain protocol designed by Gavin Wood as the next generation of Polkadot. On-chain logic runs as **services** inside PolkaVM, a RISC-V based virtual machine.

The protocol splits computation into two phases:

- **Refine** — parallel, off-chain computation on individual work items. No state access — pure computation only.
- **Accumulate** — sequential, on-chain state transitions that fold refined results into persistent service storage.

This separation lets JAM scale computation across many cores while maintaining a single coherent state. As a service developer, you implement both phases and the SDK handles the rest.

## Next steps

- [Installation](./installation.md) — set up your development environment
- [Quick Start](./quickstart.md) — build your first service in five minutes
- [JAM Concepts](./concepts/README.md) — understand the protocol in more depth
