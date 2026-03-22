# Docker Workflow

The Docker image is the recommended way to build jamc3 services. It bundles all required tools (c3c, clang, jamtool) so you do not need to install anything locally.

## Pull the image

```bash
docker pull ghcr.io/dreverr/jamc3:latest
```

On macOS with Apple Silicon:

```bash
docker pull --platform=linux/amd64 ghcr.io/dreverr/jamc3:latest
```

The image is linux/amd64 only because the toolchain (c3c, clang, jamtool) targets x86_64.

## Build a service

Mount your project directory as `/app` and pass your source file(s):

```bash
docker run --rm --platform=linux/amd64 \
  -v $(pwd):/app \
  ghcr.io/dreverr/jamc3 my_service.c3
```

The output appears at `build/my_service.jam` inside your project directory.

## Build options

The Docker entrypoint is `jam-build`, so all [jam-build flags](./jam-build.md) work directly:

```bash
# Release build
docker run --rm --platform=linux/amd64 \
  -v $(pwd):/app \
  ghcr.io/dreverr/jamc3 --release my_service.c3

# Custom output
docker run --rm --platform=linux/amd64 \
  -v $(pwd):/app \
  ghcr.io/dreverr/jamc3 -o artifacts/output.jam my_service.c3

# Build an authorizer
docker run --rm --platform=linux/amd64 \
  -v $(pwd):/app \
  ghcr.io/dreverr/jamc3 --authorizer my_auth.c3

# Multiple sources
docker run --rm --platform=linux/amd64 \
  -v $(pwd):/app \
  ghcr.io/dreverr/jamc3 main.c3 helpers.c3
```

## Shell alias

For convenience, add an alias to your shell profile:

```bash
alias jam-build='docker run --rm --platform=linux/amd64 -v $(pwd):/app ghcr.io/dreverr/jamc3'
```

Then build with:

```bash
jam-build my_service.c3
jam-build --release --authorizer my_auth.c3
```

## What is in the image

The Docker image contains:

| Tool | Version | Purpose |
|------|---------|---------|
| c3c | v0.7.10 | C3 compiler |
| clang | system | RISC-V cross-compiler for host stubs |
| lld | system | LLVM linker |
| jamtool | latest | RISC-V object to `.jam` recompiler |
| polkatool | v0.29.0 | PolkaVM linker (legacy/guest builds) |
| polkavm-to-jam | patched | PolkaVM to JAM converter (legacy) |

The SDK library (`jamc3.c3l/`) is pre-installed at `/opt/jamc3/jamc3.c3l/`.

## Building the image locally

If you want to build the Docker image yourself:

```bash
git clone https://github.com/DrEverr/jamc3.git
cd jamc3
docker build -t jamc3 .
```

This takes several minutes as it compiles the Rust tools from source.

Then use your local image:

```bash
docker run --rm --platform=linux/amd64 \
  -v $(pwd):/app \
  jamc3 my_service.c3
```
