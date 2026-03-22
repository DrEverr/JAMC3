# Building CoreStation Guests

jamc3 can also build **CoreStation guest** programs. These are PolkaVM binaries that run inside a CoreStation environment rather than as JAM services.

## What are CoreStation guests?

CoreStation is an execution environment that hosts guest programs on top of PolkaVM. Unlike JAM services (which have refine/accumulate entry points), guests have a single `guest_main` entry point and communicate through a different set of host functions.

## Building a guest

Use the `--guest` flag:

```bash
jam-build --guest my_guest.c3
```

Or with Docker:

```bash
docker run --rm --platform=linux/amd64 \
  -v $(pwd):/app \
  ghcr.io/dreverr/jamc3 --guest my_guest.c3
```

## Requirements

Guest builds require two additional files near your source:

1. **`corestation_rt.c3`** -- CoreStation runtime module providing guest-specific types and APIs.
2. **`guest_stubs.c`** -- C stubs for guest host function imports (analogous to `host_stubs.c` for services).

The build script looks for these files in the same directory as your source file, or one directory up.

## Differences from service builds

| Aspect | Service | Guest |
|--------|---------|-------|
| Entry point | `refine` + `accumulate` | `guest_main` |
| Dispatch table | 4 entries (refine, accumulate x3) | 1 entry (guest_main) |
| SDK modules | Full `jamc3.c3l` | CoreStation runtime only |
| Optimization | Always `-O0` | `-O2` with `--release` |
| Output format | `.jam` | `.jam` |

Guests can use `-O2` with `--release` because CoreStation's PolkaVM supports the full RISC-V register set, including `a6` and `a7`.

## Example

```c
module my_guest;

// Guest-specific imports would come from corestation_rt.c3

fn void guest_main() @export("guest_main")
{
    // Guest logic here
}
```

Build:

```bash
jam-build --guest --release my_guest.c3
```
