# Introduction

**jamc3** (pronounced "jamsy") is a C3 language SDK for building [JAM](https://graypaper.com/) protocol services. It compiles C3 source code into `.jam` blobs that run on PolkaVM, the virtual machine powering the JAM blockchain.

## What is JAM?

JAM (Join-Accumulate Machine) is a blockchain protocol designed by Gavin Wood as the next generation of the Polkadot network. It defines a minimal, general-purpose computation model where on-chain logic is executed as **services** running inside PolkaVM, a RISC-V based virtual machine.

The JAM protocol splits computation into two phases:

- **Refine** -- off-chain, parallelizable computation performed by validators on individual work items.
- **Accumulate** -- on-chain state transitions that fold refined results into persistent service storage.

This separation allows JAM to scale computation across many cores while maintaining a single coherent state.

## What is C3?

[C3](https://c3-lang.org/) is a systems programming language that aims to be a modern evolution of C. It provides familiar C-like syntax with improvements such as modules, error handling via optionals, and a cleaner type system, while still compiling to efficient native code. C3 targets RISC-V, which makes it a natural fit for PolkaVM.

## Why jamc3?

jamc3 provides everything you need to write JAM services in C3:

- **All JAM protocol types** -- service IDs, hashes, balances, gas, chain parameters, and more.
- **27 host function bindings** -- storage, transfers, logging, checkpointing, preimages, sub-VMs, and more.
- **Binary codec** -- variable-length natural number encoding as specified in Gray Paper Appendix C.
- **High-level service API** -- typed contexts for refine, accumulate, and authorizer entry points.
- **Bare metal** -- no standard library, no libc. Everything runs inside PolkaVM constraints.
- **Docker build tool** -- produce `.jam` files with a single command.

## How it works

The build pipeline takes C3 source code through several stages to produce a deployable JAM blob:

```
C3 source -> c3c compiler -> RISC-V .o files -> jamtool -> .jam blob
```

The resulting `.jam` file can be deployed to a JAM chain using `jam-cli` or similar deployment tools.

## Next steps

- [Installation](./installation.md) -- set up your development environment.
- [Quick Start](./quickstart.md) -- build your first service in five minutes.
- [JAM Concepts](./concepts/README.md) -- understand the protocol fundamentals.
