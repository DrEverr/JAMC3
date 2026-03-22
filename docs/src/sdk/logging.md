# Logging

**Module:** `jam::log`

The logging module provides structured logging with severity levels. Log messages are sent to the host via the `host_log` function and appear in the validator node's output.

## Log levels

| Level | Constant | Value |
|-------|----------|-------|
| Error | `LEVEL_ERROR` | 0 |
| Warn | `LEVEL_WARN` | 1 |
| Info | `LEVEL_INFO` | 2 |
| Debug | `LEVEL_DEBUG` | 3 |
| Trace | `LEVEL_TRACE` | 4 |

## Convenience functions

The simplest way to log is with the level-specific functions. Each takes a null-terminated target string (identifies the source component) and a null-terminated message:

```c
log::info("my_svc", "Service started");
log::warn("my_svc", "Payload was empty, using default");
log::err("my_svc", "Failed to decode input");
log::debug("my_svc", "Processing work item");
log::trace("my_svc", "Entering refine function");
```

## Logging integers

Use `debug_u64` to log a label with an integer value:

```c
log::debug_u64("my_svc", "counter", 42);
// Output: "counter: 42"

log::debug_u64("my_svc", "gas remaining", ctx.gas());
```

## Low-level function

For non-null-terminated strings or when you already know the lengths, use `log_msg` directly:

```c
fn void log_msg(ulong level, char* target, usz target_len, char* msg, usz msg_len)
```

**Example:**

```c
char[4] target = { 'm', 'y', 's', 'v' };
char[5] msg = { 'h', 'e', 'l', 'l', 'o' };
log::log_msg(log::LEVEL_INFO, &target, 4, &msg, 5);
```

## Formatting utilities

### fmt_u64

Format a `ulong` as a decimal string:

```c
fn usz fmt_u64(char* buf, usz buf_len, ulong value)
```

Returns the number of characters written. The buffer should be at least 20 bytes (maximum digits in a u64).

**Example:**

```c
char[20] buf;
usz len = log::fmt_u64(&buf, 20, 12345);
// buf contains "12345", len == 5
```

### str_len

Compute the length of a null-terminated string:

```c
fn usz str_len(char* s)
```

## Best practices

- Use **target** strings consistently across your service to make log filtering easy.
- Keep targets short (4-8 characters) to minimize gas overhead.
- Use `debug` and `trace` levels for development; they may be filtered out in production.
- Prefer `debug_u64` over manual string formatting for logging numbers, as it avoids buffer management.
- Remember that every log call costs gas. Avoid logging in hot loops.
