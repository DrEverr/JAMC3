# Installation

There are two ways to set up your jamc3 development environment: using Docker (recommended) or installing tools natively.

## Docker (recommended)

Docker is the simplest way to get started. The jamc3 Docker image bundles all required tools.

### Prerequisites

- [Docker](https://www.docker.com/) (linux/amd64 platform support required)

### Pull the image

```bash
docker pull ghcr.io/dreverr/jamc3:latest
```

On macOS (Apple Silicon), you need to specify the platform:

```bash
docker pull --platform=linux/amd64 ghcr.io/dreverr/jamc3:latest
```

That is all you need. Skip ahead to the [Quick Start](./quickstart.md) to build your first service.

## Native installation

If you prefer to build without Docker, you need to install the following tools.

### c3c (C3 compiler)

The C3 compiler must support the `elf-riscv64` target. Version 0.7.10 or later is recommended.

Download from [https://github.com/c3lang/c3c/releases](https://github.com/c3lang/c3c/releases) or build from source:

```bash
git clone https://github.com/c3lang/c3c.git
cd c3c
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
sudo cmake --install build
```

Verify:

```bash
c3c --version
```

### clang

A recent clang (15 or later) is required for compiling host stubs to RISC-V. Install via your system package manager:

```bash
# Debian/Ubuntu
sudo apt install clang lld

# macOS
brew install llvm
```

### jamtool

jamtool links RISC-V object files and produces the final `.jam` blob. Install from source with Cargo:

```bash
cargo install --git https://github.com/DrEverr/jamtool jamtool --locked
```

### jamc3 SDK

Clone the SDK repository:

```bash
git clone https://github.com/DrEverr/jamc3.git
cd jamc3
```

The `scripts/jam-build` script orchestrates the build pipeline. Add it to your PATH or invoke it directly:

```bash
export PATH="$PWD/scripts:$PATH"
```

### IDE support (optional)

To get autocompletion for `jam::` modules in your editor, add the SDK as a C3 library dependency in your project:

```bash
mkdir -p lib
git clone https://github.com/DrEverr/jamc3.c3l.git lib/jamc3.c3l
```

Create or update `project.json`:

```json
{
  "dependency-search-paths": ["lib"],
  "dependencies": ["jamc3"]
}
```

Your editor's C3 LSP will now provide suggestions for all SDK types and functions.

### Verify your setup

```bash
c3c --version
jamtool --help
clang --version
```

If all three commands succeed, you are ready to build services natively.
