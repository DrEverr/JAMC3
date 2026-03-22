# Codec Module

**Module:** `jam::codec`

The codec module implements binary encoding and decoding for the JAM protocol. It includes the variable-length natural number encoding specified in Gray Paper Appendix C, fixed-width little-endian integer codecs, and utility functions.

## DecodeCtx

All decoding functions operate on a `DecodeCtx`, a cursor over a byte buffer:

```c
struct DecodeCtx
{
    char*  ptr;       // current read position
    ulong  remaining; // bytes left
}
```

Initialize a decode context:

```c
char[64] data = { /* ... */ };
codec::DecodeCtx ctx = codec::decode_ctx_init(&data, 64);
```

The context advances automatically as you decode values. Check `ctx.remaining` to see how many bytes are left.

## Natural number encoding

The JAM protocol uses a variable-length encoding for natural numbers (Gray Paper Appendix C). The first byte determines the total length:

| First byte range | Total bytes | Value range |
|------------------|-------------|-------------|
| `0x00..0x7F` | 1 | 0 to 127 |
| `0x80..0xBF` | 2 | 128 to 16,511 |
| `0xC0..0xDF` | 3 | up to ~2M |
| `0xE0..0xEF` | 4 | up to ~268M |
| `0xF0..0xF7` | 5 | up to ~34B |
| `0xF8..0xFB` | 6 | up to ~4.4T |
| `0xFC..0xFD` | 7 | up to ~562T |
| `0xFE` | 8 | up to ~72P |
| `0xFF` | 9 | full u64 range |

### decode_natural_num

```c
fn ulong? decode_natural_num(DecodeCtx* ctx)
```

Decodes a variable-length natural number. Faults with `result::UNDECODABLE` on truncated input.

### encode_natural_num

```c
fn usz? encode_natural_num(char* buf, usz buf_len, ulong value)
```

Encodes a value as a variable-length natural number. Buffer must be at least 9 bytes. Returns the number of bytes written. Faults with `result::TOO_BIG` if the buffer is too small.

## Variable-width integer codecs

Convenience wrappers that decode/encode using the natural number encoding but narrow to specific widths:

### Decoders

```c
fn ushort? decode_var_u16(DecodeCtx* ctx)  // Faults if value > 0xFFFF
fn uint?   decode_var_u32(DecodeCtx* ctx)  // Faults if value > 0xFFFFFFFF
fn ulong?  decode_var_u64(DecodeCtx* ctx)  // Alias for decode_natural_num
```

### Encoders

```c
fn usz? encode_var_u16(char* buf, usz buf_len, ushort value)
fn usz? encode_var_u32(char* buf, usz buf_len, uint value)
fn usz? encode_var_u64(char* buf, usz buf_len, ulong value)
```

## Fixed-width little-endian codecs

For fields that use fixed-width encoding on the wire:

### Decoders

```c
fn char?   decode_u8(DecodeCtx* ctx)
fn ushort? decode_u16(DecodeCtx* ctx)
fn uint?   decode_u24(DecodeCtx* ctx)   // 3-byte LE
fn uint?   decode_u32(DecodeCtx* ctx)
fn ulong?  decode_u64(DecodeCtx* ctx)
```

### Encoders

```c
fn usz? encode_u8(char* buf, usz buf_len, char value)
fn usz? encode_u16(char* buf, usz buf_len, ushort value)
fn usz? encode_u32(char* buf, usz buf_len, uint value)
fn usz? encode_u64(char* buf, usz buf_len, ulong value)
```

All encoders return the number of bytes written and fault with `result::TOO_BIG` if the buffer is too small.

## Blob codecs

### decode_fixed

Read a fixed number of bytes without a length prefix:

```c
fn void? decode_fixed(DecodeCtx* ctx, char* out, usz len)
```

### decode_blob

Read a length-prefixed blob (natural number length prefix followed by that many bytes). Returns a zero-copy slice into the decode buffer:

```c
struct BlobSlice
{
    char* ptr;
    ulong len;
}

fn BlobSlice? decode_blob(DecodeCtx* ctx)
```

**Example:**

```c
codec::BlobSlice? slice = codec::decode_blob(&ctx);
if (try s = slice)
{
    // s.ptr points into the original buffer
    // s.len is the blob length
}
```

## Memory utilities

The codec module also provides stdlib-free memory utilities used internally:

```c
fn void mem_copy(char* dst, char* src, usz len)
fn void mem_zero(char* dst, usz len)
```

These are simple byte-by-byte implementations suitable for the no-stdlib PolkaVM environment.

## Example: encoding and decoding a counter

```c
// Encode
char[9] buf;
usz? written = codec::encode_natural_num(&buf, 9, 42);
// written == 1, buf[0] == 42

// Decode
codec::DecodeCtx dec = codec::decode_ctx_init(&buf, written ?? 0);
ulong? value = codec::decode_natural_num(&dec);
// value == 42
```
