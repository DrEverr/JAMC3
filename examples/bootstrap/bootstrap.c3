// Bootstrap Service
//
// A genesis service that can create and manage other JAM services.
// Installed at service ID 1000 in the genesis state.
//
// Work item payload format (instruction-based protocol):
// Each instruction is: [opcode: u8][instruction_data...]
// Multiple instructions can be concatenated in a single payload.
//
// Opcodes:
//   0x01 CreateService:
//     [code_hash: 32 bytes]       -- blake2b-256 of the .jam blob (pre-computed by submitter)
//     [code_len: u32 LE]          -- length of the code blob
//     [min_acc_gas: u64 LE]       -- minimum accumulate gas for the new service
//     [min_memo_gas: u64 LE]      -- minimum on-transfer gas
//     [endowment: u64 LE]         -- tokens to transfer to the new service
//     [flags: u8]                 -- bit 0: desired_id present, bit 1: gratis_offset present
//     if flags & 0x01:
//       [desired_id: u32 LE]      -- specific service ID to assign (registrar only for < S)
//     if flags & 0x02:
//       [gratis_offset: u64 LE]   -- free storage deposit offset (manager only)
//
//   0x02 Transfer:
//     [dest_service_id: u32 LE]
//     [amount: u64 LE]
//     [gas_limit: u64 LE]
//     [memo: 128 bytes]
//
//   0x03 Upgrade (self):
//     [code_hash: 32 bytes]       -- new code hash
//     [min_acc_gas: u64 LE]
//     [min_memo_gas: u64 LE]
//
//   0x04 Store (write to own storage):
//     [key_len: u16 LE]
//     [key: key_len bytes]
//     [val_len: u32 LE]
//     [value: val_len bytes]
//
// Refine: passes payload through as output (unchanged).
// Accumulate: decodes instructions from refine output, executes them.
//
// Storage keys written by the service:
//   "last_created"  -> u32 LE (most recently created service ID)
//   "created_count" -> u32 LE (total services created)

module bootstrap;

import jam::types;
import jam::service;
import jam::storage;
import jam::host;
import jam::log;
import jam::codec;
import jam::refine;
import jam::accumulate;

// ============================================================================
// Opcodes
// ============================================================================

const char OP_CREATE_SERVICE  = 0x01;
const char OP_TRANSFER        = 0x02;
const char OP_UPGRADE         = 0x03;
const char OP_STORE           = 0x04;

// ============================================================================
// Refine: pass-through
// ============================================================================

fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    log::info("boot", "Bootstrap refine");
    return ctx.result_ok(ctx.payload(), (usz)ctx.payload_len());
}

// ============================================================================
// Accumulate: decode and dispatch instructions from each operand's output
// ============================================================================

fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    log::info("boot", "Bootstrap accumulate");

    accumulate::InputIter iter = ctx.inputs();

    while (true)
    {
        types::AccumulateInput? maybe_input = iter.next();
        if (catch maybe_input) break;
        types::AccumulateInput input = maybe_input;

        // Only process work-item operands with a successful refine output
        if (input.kind != types::AccumulateInputKind.OPERAND) continue;
        if (input.operand.digest_output.status != types::WorkDigestStatus.OK) {
            log::warn("boot", "Panicked/failed item");
            continue;
        }

        char* data     = input.operand.digest_output.data;
        ulong data_len = input.operand.digest_output.data_len;

        if (data == null || data_len == 0) continue;

        dispatch_instructions(data, (usz)data_len);
    }
}

// ============================================================================
// Instruction dispatcher
// ============================================================================

fn void dispatch_instructions(char* data, usz data_len)
{
    codec::DecodeCtx ctx = codec::decode_ctx_init(data, (ulong)data_len);

    while (ctx.remaining > 0) {
        char? op_r = codec::decode_u8(&ctx);
        if (catch op_r) return;
        char opcode = op_r;

        bool ok;
        switch (opcode) {
            case OP_CREATE_SERVICE:
                ok = do_create_service(&ctx);
            case OP_TRANSFER:
                ok = do_transfer(&ctx);
            case OP_UPGRADE:
                ok = do_upgrade(&ctx);
            case OP_STORE:
                ok = do_store(&ctx);
            default:
                log::warn("boot", "Unknown op");
                return;
        }

        if (!ok) return;
    }
}

// ============================================================================
// 0x01 CreateService
// ============================================================================

fn bool do_create_service(codec::DecodeCtx* ctx)
{
    types::Hash code_hash;
    if (catch codec::decode_fixed(ctx, (char*)&code_hash, 32)) return false;

    uint?  code_len_r     = codec::decode_u32(ctx);
    ulong? min_acc_gas_r  = codec::decode_u64(ctx);
    ulong? min_memo_gas_r = codec::decode_u64(ctx);
    ulong? endowment_r    = codec::decode_u64(ctx);
    char?  flags_r        = codec::decode_u8(ctx);

    if (catch code_len_r)     return false;
    if (catch min_acc_gas_r)  return false;
    if (catch min_memo_gas_r) return false;
    if (catch endowment_r)    return false;
    if (catch flags_r)        return false;

    uint  code_len     = code_len_r;
    ulong min_acc_gas  = min_acc_gas_r;
    ulong min_memo_gas = min_memo_gas_r;
    ulong endowment    = endowment_r;
    uint  flags        = (uint)(char)flags_r & 0xFF;

    // Parse optional desired_id (default: >= S to trigger auto-assign)
    // Per GP eq 4543-4545: if caller is registrar and i < S, the ID is used literally.
    // To get auto-assigned hash-based ID, pass i >= S (65536).
    ulong desired_id = 65536; // S = 2^16 — triggers auto-assign by default
    if (flags & 0x01) {
        uint? did_r = codec::decode_u32(ctx);
        if (catch did_r) return false;
        desired_id = (ulong)(uint)did_r;
    }

    // Parse optional gratis_offset (default: 0 = no free storage)
    // Per GP: f != 0 requires caller to be manager service
    ulong gratis_offset = 0;
    if (flags & 0x02) {
        ulong? go_r = codec::decode_u64(ctx);
        if (catch go_r) return false;
        gratis_offset = go_r;
    }

    log::info("boot", "Creating service");

    // Create the new service account via raw host call
    ulong ret = host::host_new(
        (char*)&code_hash,
        (ulong)code_len,
        min_acc_gas,
        min_memo_gas,
        gratis_offset,
        desired_id
    );
    if (ret >= types::HOST_NONE) {
        log::warn("boot", "new_service failed");
        return false;
    }
    types::ServiceId new_id = (types::ServiceId)ret;

    log::info("boot", "Created svc");

    // Store the new service ID in our storage
    char[4] id_buf;
    codec::encode_u32(&id_buf, 4, (uint)new_id)!!;
    if (catch err = storage::kv_write("last_created", 12, &id_buf, 4)) {
        log::warn("boot", "kv_write last_created failed");
    }

    // Increment created count
    char[4] count_buf;
    uint count = 0;
    usz rd = storage::kv_read("created_count", 13, &count_buf, 0, 4) ?? 0;
    if (rd == 4) {
        codec::DecodeCtx cnt_ctx = codec::decode_ctx_init(&count_buf, 4);
        count = codec::decode_u32(&cnt_ctx) ?? 0;
    }
    count++;
    codec::encode_u32(&count_buf, 4, count)!!;
    if (catch err = storage::kv_write("created_count", 13, &count_buf, 4)) {
        log::warn("boot", "kv_write count failed");
    }

    // Transfer endowment to the new service (if > 0)
    if (endowment > 0) {
        types::Memo memo;
        // Write "bootstrap" into memo
        char[9] msg = {'b','o','o','t','s','t','r','a','p'};
        codec::mem_copy((char*)&memo, (char*)&msg, 9);

        if (catch err = service::transfer(new_id, endowment, min_memo_gas, &memo)) {
            log::warn("boot", "transfer failed");
        } else {
            log::info("boot", "Funded svc");
        }
    }

    // Create a checkpoint so we don't lose progress on later failures
    service::checkpoint();

    return true;
}

// ============================================================================
// 0x02 Transfer
// ============================================================================

fn bool do_transfer(codec::DecodeCtx* ctx)
{
    // [dest: u32][amount: u64][gas_limit: u64][memo: 128]
    uint?  dest_r      = codec::decode_u32(ctx);
    ulong? amount_r    = codec::decode_u64(ctx);
    ulong? gas_limit_r = codec::decode_u64(ctx);

    if (catch dest_r)      return false;
    if (catch amount_r)    return false;
    if (catch gas_limit_r) return false;

    uint  dest      = dest_r;
    ulong amount    = amount_r;
    ulong gas_limit = gas_limit_r;

    types::Memo memo;
    if (catch codec::decode_fixed(ctx, (char*)&memo, 128)) return false;

    log::info("boot", "Transfer");
    if (catch err = service::transfer((types::ServiceId)dest, amount, gas_limit, &memo)) {
        log::warn("boot", "transfer failed");
        return false;
    }

    return true;
}

// ============================================================================
// 0x03 Upgrade
// ============================================================================

fn bool do_upgrade(codec::DecodeCtx* ctx)
{
    // [code_hash: 32][min_acc_gas: u64][min_memo_gas: u64]
    types::Hash code_hash;
    if (catch codec::decode_fixed(ctx, (char*)&code_hash, 32)) return false;

    ulong? min_acc_gas_r  = codec::decode_u64(ctx);
    ulong? min_memo_gas_r = codec::decode_u64(ctx);

    if (catch min_acc_gas_r)  return false;
    if (catch min_memo_gas_r) return false;

    log::info("boot", "Upgrade");
    service::upgrade(&code_hash, min_acc_gas_r, min_memo_gas_r);
    return true;
}

// ============================================================================
// 0x04 Store
// ============================================================================

fn bool do_store(codec::DecodeCtx* ctx)
{
    // [key_len: u16][key: key_len][val_len: u32][value: val_len]
    ushort? key_len_r = codec::decode_u16(ctx);
    if (catch key_len_r) return false;
    ushort key_len = key_len_r;

    if (ctx.remaining < (ulong)key_len) return false;
    char* key = ctx.ptr;
    ctx.ptr += key_len;
    ctx.remaining -= key_len;

    uint? val_len_r = codec::decode_u32(ctx);
    if (catch val_len_r) return false;
    uint val_len = val_len_r;

    if (ctx.remaining < (ulong)val_len) return false;
    char* val = ctx.ptr;
    ctx.ptr += val_len;
    ctx.remaining -= val_len;

    log::info("boot", "Store KV");
    if (catch err = storage::kv_write(key, key_len, val, val_len)) {
        log::warn("boot", "kv_write failed");
        return false;
    }

    return true;
}
