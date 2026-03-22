# Internals & Deep Dive

This section goes under the hood of jamc3. You do not need to read any of this to write JAM services -- the SDK and `jam-build` handle all the details. But if you want to understand *why* things work the way they do, or if you are troubleshooting a tricky build problem, this is where to look.

## What is covered here

- [**.jam Binary Format**](./jam-binary.md) -- what is actually inside the `.jam` file that gets deployed to the chain. PVM bytecode sections, memory layout, and how to inspect them.

- [**PVM Memory Model**](./pvm-memory.md) -- PolkaVM's register file, memory layout, stack behavior, and why certain compiler flags are mandatory.

- [**Host Function Internals**](./host-calls.md) -- how PVM host calls work at the instruction level, the `host_stubs.c` mechanism for PolkaVM metadata, and the dispatch table that maps entry point indices to your code.

- [**Compilation Pipeline Details**](./compilation.md) -- the full journey from C3 source code to `.jam` blob, why we target RISC-V, what `jamtool` does internally, and the difference between debug and release builds.

## When you might need this

- You are getting cryptic build errors and want to understand the toolchain
- You want to inspect or debug a `.jam` blob directly
- You are curious about PVM limitations and why certain things are the way they are
- You are writing your own build pipeline instead of using `jam-build`
- You want to contribute to jamc3 itself
