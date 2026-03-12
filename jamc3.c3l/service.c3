// JAM SDK - High-level Service API
// Convenience functions for common service operations.
// No stdlib dependency.
module jam::service;

import jam::host;
import jam::types;
import jam::codec;
import jam::result;
import jam::log;

// ---------------------------------------------------------------------------
// Get remaining gas
// ---------------------------------------------------------------------------

fn types::Gas gas_remaining()
{
    return host::host_gas();
}

// ---------------------------------------------------------------------------
// Get chain parameters
// ---------------------------------------------------------------------------

fn types::ChainParams? chain_params()
{
    types::ChainParams params;
    ulong ret = host::host_fetch(
        (char*)&params,
        0,
        types::ChainParams.sizeof,
        types::FETCH_CHAIN_PARAMS,
        0, 0
    );
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return params;
}

// ---------------------------------------------------------------------------
// Get 32-byte chain entropy
// ---------------------------------------------------------------------------

fn void? chain_entropy(char* out_32)
{
    ulong ret = host::host_fetch(
        out_32,
        0,
        32,
        types::FETCH_CHAIN_ENTROPY32,
        0, 0
    );
    if (ret == types::HOST_NONE) return result::NO_DATA~;
}

// ---------------------------------------------------------------------------
// Get own service info
// ---------------------------------------------------------------------------

fn types::ServiceInfo? service_info()
{
    types::ServiceInfo info;
    ulong ret = host::host_info(0, (char*)&info);
    if (ret == types::HOST_WHO) return result::HOST_ERROR~;
    return info;
}

// ---------------------------------------------------------------------------
// Get info for a specific service
// ---------------------------------------------------------------------------

fn types::ServiceInfo? service_info_of(types::ServiceId id)
{
    types::ServiceInfo info;
    ulong ret = host::host_info((ulong)id, (char*)&info);
    if (ret == types::HOST_WHO) return result::HOST_ERROR~;
    return info;
}

// ---------------------------------------------------------------------------
// Get own service balance
// ---------------------------------------------------------------------------

fn types::Balance? balance()
{
    types::ServiceInfo info = service_info()!;
    return info.balance;
}

// ---------------------------------------------------------------------------
// Return data to the PVM host.
// Sets registers a0 (pointer) and a1 (length) via inline asm.
// This is how refine results and authorizer results are communicated back.
// ---------------------------------------------------------------------------

fn void return_to_host(char* ptr, usz len) @naked
{
    // On RISC-V (PolkaVM), a0 = x10, a1 = x11
    // In the C ABI, the first two arguments are already in a0 and a1,
    // so for a @naked function we just need to return.
    // The caller passes ptr in a0 and len in a1 which is exactly
    // what the host expects to find in those registers.
    asm("ret");
}

// ---------------------------------------------------------------------------
// Transfer tokens to another service
// ---------------------------------------------------------------------------

fn void? transfer(types::ServiceId receiver, types::Balance amount, types::Gas gas_limit, types::Memo* memo)
{
    ulong ret = host::host_transfer(
        (ulong)receiver,
        amount,
        gas_limit,
        (char*)memo
    );
    if (ret == types::HOST_WHO)  return result::HOST_ERROR~;
    if (ret == types::HOST_CASH) return result::INSUFFICIENT_BALANCE~;
    if (ret == types::HOST_LOW)  return result::HOST_ERROR~;
}

// ---------------------------------------------------------------------------
// Create a state checkpoint (accumulate only)
// ---------------------------------------------------------------------------

fn types::Gas checkpoint()
{
    return host::host_checkpoint();
}

// ---------------------------------------------------------------------------
// Yield accumulation output hash (accumulate only)
// ---------------------------------------------------------------------------

fn void yield_hash(types::Hash* hash)
{
    host::host_yield((char*)hash);
}

// ---------------------------------------------------------------------------
// Create a new service (accumulate only)
// ---------------------------------------------------------------------------

fn types::ServiceId? new_service(
    types::Hash* code_hash,
    ulong code_len,
    types::Gas min_gas_acc,
    types::Gas min_gas_memo,
    ulong gratis_offset,
    types::ServiceId desired_id
)
{
    ulong ret = host::host_new(
        (char*)code_hash,
        code_len,
        min_gas_acc,
        min_gas_memo,
        gratis_offset,
        (ulong)desired_id
    );
    if (ret == types::HOST_CASH) return result::INSUFFICIENT_BALANCE~;
    if (ret == types::HOST_FULL) return result::HOST_ERROR~;
    return (types::ServiceId)ret;
}

// ---------------------------------------------------------------------------
// Upgrade service code (accumulate only)
// ---------------------------------------------------------------------------

fn void? upgrade(types::Hash* code_hash, types::Gas min_gas_acc, types::Gas min_gas_memo)
{
    ulong ret = host::host_upgrade(
        (char*)code_hash,
        min_gas_acc,
        min_gas_memo
    );
    if (ret == types::HOST_CASH) return result::INSUFFICIENT_BALANCE~;
}

// ---------------------------------------------------------------------------
// Fetch accumulate inputs
// ---------------------------------------------------------------------------

fn usz? fetch_inputs(char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(
        buf,
        0,
        buf_len,
        types::FETCH_INPUTS,
        0, 0
    );
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}

// ---------------------------------------------------------------------------
// Fetch nth work item payload (for refine)
// ---------------------------------------------------------------------------

fn usz? fetch_nth_payload(uint index, char* buf, usz buf_len)
{
    ulong ret = host::host_fetch(
        buf,
        0,
        buf_len,
        types::FETCH_NTH_ITEM_PAYLOAD,
        (ulong)index,
        0
    );
    if (ret == types::HOST_NONE) return result::NO_DATA~;
    return (usz)ret;
}
