// JAM SDK - Key-Value Storage
// High-level wrappers around host_read / host_write.
// No stdlib dependency.
module jam::storage;

import jam::host;
import jam::types;
import jam::result;

// ---------------------------------------------------------------------------
// Read from own service's storage
// ---------------------------------------------------------------------------

fn usz? kv_read(char* key, usz key_len, char* out, usz offset, usz max_len)
{
    // service_id 0 means "self" in the read host function
    ulong ret = host::host_read(0, key, key_len, out, offset, max_len);
    if (ret == types::HOST_NONE) return result::NO_KEY~;
    if (ret == types::HOST_OOB)  return result::NO_DATA~;
    return (usz)ret;
}

// ---------------------------------------------------------------------------
// Read from another service's storage
// ---------------------------------------------------------------------------

fn usz? kv_read_of(types::ServiceId service_id, char* key, usz key_len, char* out, usz offset, usz max_len)
{
    ulong ret = host::host_read((ulong)service_id, key, key_len, out, offset, max_len);
    if (ret == types::HOST_NONE) return result::NO_KEY~;
    if (ret == types::HOST_OOB)  return result::NO_DATA~;
    if (ret == types::HOST_WHO)  return result::HOST_ERROR~;
    return (usz)ret;
}

// ---------------------------------------------------------------------------
// Write to own service's storage
// ---------------------------------------------------------------------------

fn usz? kv_write(char* key, usz key_len, char* value, usz value_len)
{
    ulong ret = host::host_write(key, key_len, value, value_len);
    if (ret == types::HOST_FULL) return result::INSUFFICIENT_BALANCE~;
    if (ret == types::HOST_WHAT) return result::STORAGE_KV_WRITE~;
    return (usz)ret;
}

// ---------------------------------------------------------------------------
// Delete a key from own service's storage (write with zero-length value)
// ---------------------------------------------------------------------------

fn void? kv_delete(char* key, usz key_len)
{
    ulong ret = host::host_write(key, key_len, null, 0);
    if (ret == types::HOST_NONE) return result::NO_KEY~;
    if (ret == types::HOST_WHAT) return result::STORAGE_KV_DELETE~;
}
