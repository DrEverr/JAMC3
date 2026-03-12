// JAM SDK - Entry Points
// Provides the PVM entry point functions that the PolkaVM dispatch table maps to.
// These decode the raw arguments and delegate to user-supplied hooks.
//
// The user must implement the following in their service module:
//   fn void refine(jam::types::RefineArgs* args)
//   fn void accumulate(jam::types::AccumulateArgs* args)
module jam::entry;

import jam::types;
import jam::codec;
import jam::log;

// ---------------------------------------------------------------------------
// User hooks - must be implemented by the service author.
// Just plain `refine` and `accumulate`.
// ---------------------------------------------------------------------------

extern fn void refine(types::RefineArgs* args);
extern fn void accumulate(types::AccumulateArgs* args);

// ---------------------------------------------------------------------------
// Refine entry point
// ---------------------------------------------------------------------------

fn void jam_entry_refine(char* arg_ptr, ulong arg_len) @export("jam_entry_refine")
{
    codec::DecodeCtx ctx = codec::decode_ctx_init(arg_ptr, arg_len);

    types::RefineArgs args;

    uint? core_idx = codec::decode_var_u32(&ctx);
    if (catch core_idx)
    {
        log::err("JAM", "Refine: failed to decode core_index");
        return;
    }
    args.core_index = core_idx;

    uint? wi_idx = codec::decode_var_u32(&ctx);
    if (catch wi_idx)
    {
        log::err("JAM", "Refine: failed to decode work_item_index");
        return;
    }
    args.work_item_index = wi_idx;

    uint? svc_id = codec::decode_var_u32(&ctx);
    if (catch svc_id)
    {
        log::err("JAM", "Refine: failed to decode service_id");
        return;
    }
    args.service_id = svc_id;

    codec::BlobSlice? blob = codec::decode_blob(&ctx);
    if (catch blob)
    {
        log::err("JAM", "Refine: failed to decode work_payload");
        return;
    }
    args.work_payload = blob.ptr;
    args.work_payload_len = blob.len;

    if (catch codec::decode_fixed(&ctx, &args.work_package_hash, 32))
    {
        log::err("JAM", "Refine: failed to decode work_package_hash");
        return;
    }

    refine(&args);
}

// ---------------------------------------------------------------------------
// Accumulate entry point
// ---------------------------------------------------------------------------

fn void jam_entry_accumulate(char* arg_ptr, ulong arg_len) @export("jam_entry_accumulate")
{
    codec::DecodeCtx ctx = codec::decode_ctx_init(arg_ptr, arg_len);

    types::AccumulateArgs args;

    uint? ts = codec::decode_var_u32(&ctx);
    if (catch ts)
    {
        log::err("JAM", "Accumulate: failed to decode timeslot");
        return;
    }
    args.timeslot = ts;

    uint? svc_id = codec::decode_var_u32(&ctx);
    if (catch svc_id)
    {
        log::err("JAM", "Accumulate: failed to decode service_id");
        return;
    }
    args.service_id = svc_id;

    ulong? n_inp = codec::decode_var_u64(&ctx);
    if (catch n_inp)
    {
        log::err("JAM", "Accumulate: failed to decode num_inputs");
        return;
    }
    args.num_inputs = n_inp;

    accumulate(&args);
}
