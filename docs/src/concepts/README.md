# JAM Concepts

This section covers the core concepts of the JAM protocol that you need to understand to write services with jamc3.

## The JAM model

JAM (Join-Accumulate Machine) is a stateful blockchain where computation is organized around **services**. Each service has its own on-chain storage and code, and interacts with the chain through a two-phase execution model:

1. **Refine** (off-chain) -- validators execute work items in parallel across cores. This phase is pure computation with read-only access to chain state.
2. **Accumulate** (on-chain) -- refined results are folded into the service's persistent state. This phase can write to storage, transfer tokens, and create new services.

This split is the key design insight of JAM: expensive computation happens off-chain in refine, while only the state transitions happen on-chain in accumulate.

## Key abstractions

- **[Services](./services.md)** -- the fundamental unit of on-chain logic. Each service has code, storage, and a balance.
- **[Work packages](./work-packages.md)** -- bundles of work items submitted to the network for processing.
- **[Storage](./storage.md)** -- key-value storage available to each service.
- **[Preimages](./preimages.md)** -- a system for requesting and providing data blobs identified by hash.

## Gas

All computation in JAM is metered by **gas**. Every host function call and every instruction executed costs gas. Services specify minimum gas requirements for accumulate and on-transfer operations. You can check remaining gas at any time:

```c
types::Gas remaining = ctx.gas();
```

## Service IDs

Every service on the chain has a unique 32-bit identifier (`ServiceId`). Your service can query its own ID and look up information about other services:

```c
types::ServiceId my_id = ctx.service_id();
types::ServiceInfo? other = ctx.service_info_of(42);
```
