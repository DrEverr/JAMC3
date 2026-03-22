# Storage API

**Module:** `jam::storage`

The storage module provides high-level wrappers around the `host_read` and `host_write` host functions for key-value storage operations.

In practice, you will usually use the context methods (`ctx.kv_read`, `ctx.kv_write`, `ctx.kv_delete`) rather than calling these functions directly. The direct functions are useful when you need cross-service reads or non-zero offsets.

## Functions

### kv_read

Read a value from the current service's storage.

```c
fn usz? kv_read(char* key, usz key_len, char* out, usz offset, usz max_len)
```

**Parameters:**
- `key` -- pointer to the key bytes
- `key_len` -- length of the key in bytes
- `out` -- output buffer to write the value into
- `offset` -- byte offset into the stored value to start reading from
- `max_len` -- maximum bytes to read into `out`

**Returns:** Number of bytes read on success.

**Faults:** `result::NO_KEY` if the key does not exist.

**Example:**

```c
char[4] key = { 'k', 'e', 'y', '1' };
char[256] buf;

usz? result = storage::kv_read(&key, 4, &buf, 0, 256);
if (try n = result)
{
    // buf contains n bytes
}
```

### kv_read_of

Read a value from another service's storage.

```c
fn usz? kv_read_of(
    types::ServiceId service_id,
    char* key, usz key_len,
    char* out, usz offset, usz max_len
)
```

**Parameters:** Same as `kv_read`, plus `service_id` specifying the target service.

**Returns:** Number of bytes read on success.

**Faults:** `result::NO_KEY` if the key does not exist.

**Example:**

```c
usz? result = storage::kv_read_of(42, &key, 4, &buf, 0, 256);
```

### kv_write

Write a value to the current service's storage. Only available during accumulate.

```c
fn usz? kv_write(char* key, usz key_len, char* value, usz value_len)
```

**Parameters:**
- `key` -- pointer to the key bytes
- `key_len` -- length of the key in bytes
- `value` -- pointer to the value bytes
- `value_len` -- length of the value in bytes

**Returns:** Previous value length on success (or 0 for new keys).

**Faults:** `result::INSUFFICIENT_BALANCE` if the service lacks balance for the storage deposit.

**Example:**

```c
char[4] key = { 'k', 'e', 'y', '1' };
char[8] value;
codec::encode_u64(&value, 8, 12345)!;

storage::kv_write(&key, 4, &value, 8)!;
```

### kv_delete

Delete a key from the current service's storage. Only available during accumulate.

```c
fn void? kv_delete(char* key, usz key_len)
```

**Parameters:**
- `key` -- pointer to the key bytes
- `key_len` -- length of the key in bytes

**Faults:** `result::INSUFFICIENT_BALANCE` in edge cases.

**Example:**

```c
char[4] key = { 'o', 'l', 'd', 'k' };
storage::kv_delete(&key, 4)!;
```

## Context methods

The context objects provide convenience wrappers:

| Context | Method | Notes |
|---------|--------|-------|
| `refine::Ctx` | `ctx.kv_read(key, key_len, out, max_len)` | Read-only, offset=0 |
| `accumulate::Ctx` | `ctx.kv_read(key, key_len, out, max_len)` | Read-only, offset=0 |
| `accumulate::Ctx` | `ctx.kv_write(key, key_len, value, value_len)` | Write |
| `accumulate::Ctx` | `ctx.kv_delete(key, key_len)` | Delete |
| `authorizer::Ctx` | `ctx.kv_read(key, key_len, out, max_len)` | Read-only, offset=0 |

For reads with a non-zero offset or cross-service reads, call `storage::kv_read()` or `storage::kv_read_of()` directly.
