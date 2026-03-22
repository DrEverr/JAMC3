# Native Build Setup

If you prefer not to use Docker, you can install the toolchain natively and use `jam-build` directly.

## Install the tools

### 1. c3c (C3 compiler)

Version 0.7.10 or later is required. Download from [c3c releases](https://github.com/c3lang/c3c/releases) or build from source:

```bash
git clone https://github.com/c3lang/c3c.git
cd c3c
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
sudo cmake --install build
```

### 2. clang

A recent clang (version 15+) with RISC-V target support is required for compiling host stubs.

```bash
# Debian/Ubuntu
sudo apt install clang lld

# macOS
brew install llvm
export PATH="$(brew --prefix llvm)/bin:$PATH"

# Fedora
sudo dnf install clang lld
```

### 3. jamtool

Install from source using Cargo (requires Rust):

```bash
cargo install --git https://github.com/DrEverr/jamtool jamtool --locked
```

### 4. jamc3 SDK

Clone the repository:

```bash
git clone https://github.com/DrEverr/jamc3.git
```

Add the scripts directory to your PATH:

```bash
export PATH="/path/to/jamc3/scripts:$PATH"
```

Or add this to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.).

## Verify the installation

```bash
c3c --version
# c3c v0.7.10 or later

clang --version
# Any clang 15+

jamtool --help
# jamtool usage info

jam-build --help
# jam-build usage info
```

## Build a service

```bash
cd my-project
jam-build my_service.c3
```

Output: `build/my_service.jam`

## Common issues

### "c3c not found in PATH"

Make sure the c3c binary is on your PATH. If you installed from a tarball, add its directory:

```bash
export PATH="/opt/c3:$PATH"
```

### "jamtool not found"

Install jamtool with Cargo:

```bash
cargo install --git https://github.com/DrEverr/jamtool jamtool --locked
```

Make sure `~/.cargo/bin` is on your PATH.

### "No clang compiler found"

The build script searches for `clang-20`, `clang-19`, ..., `clang-15`, and `clang` (unversioned). Install any of these.

### RISC-V optimization breaks PolkaVM

If you see unexpected behavior with optimized builds, remember that services **must** be compiled with `-O0`. The RISC-V backend at `-O1` and above uses registers `a6` and `a7`, which are not part of PolkaVM's register file. The `jam-build` script handles this automatically (services always use `-O0`).

### Cross-compilation on macOS

Native builds on macOS require the LLVM clang (not Apple clang) for RISC-V cross-compilation:

```bash
brew install llvm
export PATH="$(brew --prefix llvm)/bin:$PATH"
```

Apple's built-in clang does not support the `riscv64-unknown-none-elf` target.
