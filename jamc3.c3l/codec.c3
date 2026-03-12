// JAM SDK - Binary Codec
// Implements the JAM natural number variable-length encoding (Gray Paper Appendix C)
// and helpers for encoding/decoding fixed-width integers and length-prefixed blobs.
// No stdlib dependency - operates on raw char slices.
module jam::codec;

import jam::result;

// ---------------------------------------------------------------------------
// Decode context - a cursor over a byte buffer
// ---------------------------------------------------------------------------

struct DecodeCtx
{
    char*  ptr;      // current read position
    ulong  remaining; // bytes left
}

fn DecodeCtx decode_ctx_init(char* data, ulong len)
{
    DecodeCtx ctx;
    ctx.ptr = data;
    ctx.remaining = len;
    return ctx;
}

// ---------------------------------------------------------------------------
// Natural number decode (Gray Paper eq C.1)
//
// Encoding scheme (Gray Paper Appendix C):
//   First byte determines the total length:
//   0x00..0x7F  -> 1 byte, value = first_byte
//   0x80..0xBF  -> 2 bytes, value = LE(remaining)  (first & 0x3F unused or zero)
//   0xC0..0xDF  -> 3 bytes
//   0xE0..0xEF  -> 4 bytes
//   0xF0..0xF7  -> 5 bytes
//   0xF8..0xFB  -> 6 bytes
//   0xFC..0xFD  -> 7 bytes
//   0xFE        -> 8 bytes
//   0xFF        -> 9 bytes (prefix + 8 LE bytes)
// ---------------------------------------------------------------------------

fn ulong? decode_natural_num(DecodeCtx* ctx)
{
    if (ctx.remaining == 0) return result::UNDECODABLE~;

    char first = *ctx.ptr;
    ctx.ptr++;
    ctx.remaining--;

    if (first < 0x80)
    {
        return (ulong)first;
    }

    // Count leading 1-bits to determine extra byte count
    uint extra;
    if (first == 0xFF)
    {
        extra = 8;
    }
    else
    {
        extra = 1;
        char mask = 0xC0;
        while (extra < 7)
        {
            if ((first & mask) != mask) break;
            extra++;
            mask = (char)((mask >> 1) | 0x80);
        }
    }

    if (ctx.remaining < extra) return result::UNDECODABLE~;

    // Read extra bytes as little-endian value
    ulong value = 0;
    for (uint i = 0; i < extra; i++)
    {
        value |= (ulong)(ctx.ptr[i]) << (i * 8);
    }

    ctx.ptr += extra;
    ctx.remaining -= extra;

    return value;
}

// ---------------------------------------------------------------------------
// Natural number encode (Gray Paper eq C.1)
// Returns number of bytes written. Buffer must be at least 9 bytes.
// ---------------------------------------------------------------------------

fn usz? encode_natural_num(char* buf, usz buf_len, ulong value)
{
    if (buf_len < 9) return result::TOO_BIG~;

    if (value == 0)
    {
        buf[0] = 0x00;
        return 1;
    }

    if (value < 0x80)
    {
        buf[0] = (char)value;
        return 1;
    }

    // Determine how many bytes needed for the value
    uint bytes_needed;
    if (value < ((ulong)1 << 14)) {
        bytes_needed = 2;
    } else if (value < ((ulong)1 << 21)) {
        bytes_needed = 3;
    } else if (value < ((ulong)1 << 28)) {
        bytes_needed = 4;
    } else if (value < ((ulong)1 << 35)) {
        bytes_needed = 5;
    } else if (value < ((ulong)1 << 42)) {
        bytes_needed = 6;
    } else if (value < ((ulong)1 << 49)) {
        bytes_needed = 7;
    } else if (value < ((ulong)1 << 56)) {
        bytes_needed = 8;
    } else {
        bytes_needed = 9;
    }

    if (bytes_needed == 9)
    {
        buf[0] = 0xFF;
        for (uint i = 0; i < 8; i++)
        {
            buf[1 + i] = (char)(value >> (i * 8));
        }
        return 9;
    }

    // Prefix: (bytes_needed - 1) leading 1-bits, then a 0-bit
    uint extra = bytes_needed - 1;
    char prefix = 0;
    for (uint i = 0; i < extra; i++)
    {
        prefix |= (char)((char)0x80 >> i);
    }
    buf[0] = prefix;

    // Write LE value bytes after prefix
    for (uint i = 0; i < extra; i++)
    {
        buf[1 + i] = (char)(value >> (i * 8));
    }
    return bytes_needed;
}

// ---------------------------------------------------------------------------
// Variable-length integer decoders (general-nat encoded, narrowed to type)
// Use these when the wire format uses general integer encoding for a field
// that logically fits in a u16, u32 or u64.
// ---------------------------------------------------------------------------

fn ushort? decode_var_u16(DecodeCtx* ctx)
{
    ulong v = decode_natural_num(ctx)!;
    if (v > 0xFFFF) return result::UNDECODABLE~;
    return (ushort)v;
}

fn uint? decode_var_u32(DecodeCtx* ctx)
{
    ulong v = decode_natural_num(ctx)!;
    if (v > 0xFFFFFFFF) return result::UNDECODABLE~;
    return (uint)v;
}

fn ulong? decode_var_u64(DecodeCtx* ctx)
{
    return decode_natural_num(ctx);
}

// ---------------------------------------------------------------------------
// Variable-length integer encoders (general-int encoded)
// Symmetric counterparts to decode_var_u16 / decode_var_u32 / decode_var_u64.
// ---------------------------------------------------------------------------

fn usz? encode_var_u16(char* buf, usz buf_len, ushort value)
{
    return encode_natural_num(buf, buf_len, (ulong)value);
}

fn usz? encode_var_u32(char* buf, usz buf_len, uint value)
{
    return encode_natural_num(buf, buf_len, (ulong)value);
}

fn usz? encode_var_u64(char* buf, usz buf_len, ulong value)
{
    return encode_natural_num(buf, buf_len, value);
}

// ---------------------------------------------------------------------------
// Fixed-width little-endian decoders
// ---------------------------------------------------------------------------

fn char? decode_u8(DecodeCtx* ctx)
{
    if (ctx.remaining < 1) return result::UNDECODABLE~;
    char v = *ctx.ptr;
    ctx.ptr++;
    ctx.remaining--;
    return v;
}

fn ushort? decode_u16(DecodeCtx* ctx)
{
    if (ctx.remaining < 2) return result::UNDECODABLE~;
    ushort v = (ushort)ctx.ptr[0] | ((ushort)ctx.ptr[1] << 8);
    ctx.ptr += 2;
    ctx.remaining -= 2;
    return v;
}

fn uint? decode_u24(DecodeCtx* ctx)
{
    if (ctx.remaining < 3) return result::UNDECODABLE~;
    uint v = (uint)ctx.ptr[0]
           | ((uint)ctx.ptr[1] << 8)
           | ((uint)ctx.ptr[2] << 16);
    ctx.ptr += 3;
    ctx.remaining -= 3;
    return v;
}

fn uint? decode_u32(DecodeCtx* ctx)
{
    if (ctx.remaining < 4) return result::UNDECODABLE~;
    uint v = (uint)ctx.ptr[0]
           | ((uint)ctx.ptr[1] << 8)
           | ((uint)ctx.ptr[2] << 16)
           | ((uint)ctx.ptr[3] << 24);
    ctx.ptr += 4;
    ctx.remaining -= 4;
    return v;
}

fn ulong? decode_u64(DecodeCtx* ctx)
{
    if (ctx.remaining < 8) return result::UNDECODABLE~;
    ulong v = 0;
    for (int i = 0; i < 8; i++)
    {
        v |= (ulong)ctx.ptr[i] << (i * 8);
    }
    ctx.ptr += 8;
    ctx.remaining -= 8;
    return v;
}

// ---------------------------------------------------------------------------
// Fixed-size blob (no length prefix)
// ---------------------------------------------------------------------------

fn void? decode_fixed(DecodeCtx* ctx, char* out, usz len)
{
    if (ctx.remaining < len) return result::UNDECODABLE~;
    for (usz i = 0; i < len; i++)
    {
        out[i] = ctx.ptr[i];
    }
    ctx.ptr += len;
    ctx.remaining -= len;
}

// ---------------------------------------------------------------------------
// Length-prefixed binary blob (general-int length prefix)
// Returns a pointer and length into the decode buffer (zero-copy).
// ---------------------------------------------------------------------------

struct BlobSlice
{
    char* ptr;
    ulong len;
}

fn BlobSlice? decode_blob(DecodeCtx* ctx)
{
    ulong len = decode_natural_num(ctx)!;
    if (ctx.remaining < len) return result::UNDECODABLE~;
    BlobSlice s;
    s.ptr = ctx.ptr;
    s.len = len;
    ctx.ptr += len;
    ctx.remaining -= len;
    return s;
}

// ---------------------------------------------------------------------------
// Fixed-width little-endian encoders
// ---------------------------------------------------------------------------

fn usz? encode_u8(char* buf, usz buf_len, char value)
{
    if (buf_len < 1) return result::TOO_BIG~;
    buf[0] = value;
    return 1;
}

fn usz? encode_u16(char* buf, usz buf_len, ushort value)
{
    if (buf_len < 2) return result::TOO_BIG~;
    buf[0] = (char)(value);
    buf[1] = (char)(value >> 8);
    return 2;
}

fn usz? encode_u32(char* buf, usz buf_len, uint value)
{
    if (buf_len < 4) return result::TOO_BIG~;
    buf[0] = (char)(value);
    buf[1] = (char)(value >> 8);
    buf[2] = (char)(value >> 16);
    buf[3] = (char)(value >> 24);
    return 4;
}

fn usz? encode_u64(char* buf, usz buf_len, ulong value)
{
    if (buf_len < 8) return result::TOO_BIG~;
    for (int i = 0; i < 8; i++)
    {
        buf[i] = (char)(value >> (i * 8));
    }
    return 8;
}

// ---------------------------------------------------------------------------
// Utility: memcpy/memset without stdlib
// ---------------------------------------------------------------------------

fn void mem_copy(char* dst, char* src, usz len)
{
    for (usz i = 0; i < len; i++)
    {
        dst[i] = src[i];
    }
}

fn void mem_zero(char* dst, usz len)
{
    for (usz i = 0; i < len; i++)
    {
        dst[i] = 0;
    }
}

// ---------------------------------------------------------------------------
// C ABI builtins required by the compiler (no-stdlib builds).
// The compiler may emit calls to memset/memcpy for array init or struct copy.
// ---------------------------------------------------------------------------

fn char* cabi_memset(char* dst, int val, usz len) @export("memset")
{
    char c = (char)val;
    for (usz i = 0; i < len; i++)
    {
        dst[i] = c;
    }
    return dst;
}

fn char* cabi_memcpy(char* dst, char* src, usz len) @export("memcpy")
{
    for (usz i = 0; i < len; i++)
    {
        dst[i] = src[i];
    }
    return dst;
}
