// JAM SDK - Protocol Types
// All types understood by JAM services, matching the Gray Paper spec.
module jam::types;

// ---------------------------------------------------------------------------
// Numeric aliases
// ---------------------------------------------------------------------------

alias ServiceId  = uint;     // N_S: 32-bit service identifier
alias Timeslot   = uint;     // N_T: 32-bit timeslot index
alias Gas        = ulong;    // N_G: 64-bit unsigned gas
alias Balance    = ulong;    // N_B: 64-bit balance
alias CoreIndex  = uint;     // N_C: core index (fits in uint for SDK)

// ---------------------------------------------------------------------------
// Fixed-size byte types
// ---------------------------------------------------------------------------

alias Hash = char[32];       // H: 256-bit hash (blake2b-256)
alias Memo = char[128];      // W_T: transfer memo (128 bytes)

// ---------------------------------------------------------------------------
// Host function sentinel return values (from Gray Paper Appendix)
// ---------------------------------------------------------------------------

const ulong HOST_OK   = 0;
const ulong HOST_NONE = 0xFFFF_FFFF_FFFF_FFFF;        // 2^64 - 1
const ulong HOST_WHAT = 0xFFFF_FFFF_FFFF_FFFE;        // 2^64 - 2
const ulong HOST_OOB  = 0xFFFF_FFFF_FFFF_FFFD;        // 2^64 - 3
const ulong HOST_WHO  = 0xFFFF_FFFF_FFFF_FFFC;        // 2^64 - 4
const ulong HOST_FULL = 0xFFFF_FFFF_FFFF_FFFB;        // 2^64 - 5
const ulong HOST_CORE = 0xFFFF_FFFF_FFFF_FFFA;        // 2^64 - 6
const ulong HOST_CASH = 0xFFFF_FFFF_FFFF_FFF9;        // 2^64 - 7
const ulong HOST_LOW  = 0xFFFF_FFFF_FFFF_FFF8;        // 2^64 - 8
const ulong HOST_HUH  = 0xFFFF_FFFF_FFFF_FFF7;        // 2^64 - 9

// ---------------------------------------------------------------------------
// Fetch discriminators (host_call #1 sub-commands)
// ---------------------------------------------------------------------------

const ulong FETCH_CHAIN_PARAMS      = 0;
const ulong FETCH_CHAIN_ENTROPY32   = 1;
const ulong FETCH_AUTH_TRACE        = 2;
const ulong FETCH_NTH_ITEM_PAYLOAD  = 13;
const ulong FETCH_INPUTS            = 14;
const ulong FETCH_SINGLE_ITEM       = 15;

// ---------------------------------------------------------------------------
// ServiceInfo - account metadata returned by host_info (96 bytes)
// Matches the on-chain ServiceAccount summary.
// ---------------------------------------------------------------------------

struct ServiceInfo @packed
{
    Hash     code_hash;
    Balance  balance;
    Balance  threshold_balance;
    Gas      min_gas_accumulate;
    Gas      min_gas_on_transfer;
    ulong    bytes_in_storage;
    uint     items_in_storage;
    ulong    gratis_storage_offset;
    Timeslot creation_slot;
    Timeslot last_accumulation_slot;
    Timeslot parent_slot;
}

// ---------------------------------------------------------------------------
// ChainParams - protocol constants fetched via host_fetch(CHAIN_PARAMS)
// 134 bytes, packed, little-endian.
// ---------------------------------------------------------------------------

struct ChainParams @packed
{
    ulong   item_deposit;
    ulong   byte_deposit;
    ulong   base_deposit;
    ushort  core_count;
    uint    expunge_period;
    uint    epoch_length;
    ulong   report_acc_gas;
    ulong   package_auth_gas;
    ulong   package_ref_gas;
    ulong   block_acc_gas;
    ushort  recent_history_len;
    ushort  max_package_items;
    ushort  max_report_deps;
    ushort  max_block_tickets;
    uint    max_lookup_anchorage;
    ushort  ticket_entries;
    ushort  auth_pool_size;
    ushort  slot_seconds;
    ushort  auth_queue_size;
    ushort  rotation_period;
    ushort  max_package_exts;
    ushort  assurance_timeout_period;
    ushort  val_count;
    uint    max_auth_code_size;
    uint    max_bundle_size;
    uint    max_service_code_size;
    uint    ec_piece_size;
    uint    max_package_imports;
    uint    segment_ec_pieces;
    uint    max_report_var_size;
    uint    memo_size;
    uint    max_package_exports;
    uint    epoch_tail_start;
}

// ---------------------------------------------------------------------------
// Entry point argument structures
// ---------------------------------------------------------------------------

// Arguments decoded and passed to the user's accumulate hook.
struct AccumulateArgs @packed
{
    Timeslot  timeslot;
    ServiceId service_id;
    Gas       num_inputs;
}

// Arguments decoded and passed to the user's refine hook.
struct RefineArgs @packed
{
    CoreIndex core_index;
    uint      work_item_index;
    ServiceId service_id;
    char*     work_payload;
    ulong     work_payload_len;
    Hash      work_package_hash;
}

// Arguments decoded and passed to the user's is_authorized hook.
struct IsAuthorizedArgs @packed
{
    ushort core_index;
}

// ---------------------------------------------------------------------------
// Work digest output - the result of a refine invocation
// ---------------------------------------------------------------------------

enum WorkDigestStatus : char
{
    OK,
    OUT_OF_GAS,
    PANIC,
    BAD_EXPORTS,
    OVERSIZE,
    BAD_CODE,
    BIG_CODE,
}

struct WorkDigestOutput
{
    WorkDigestStatus status;
    char*            data;
    ulong            data_len;
}

// ---------------------------------------------------------------------------
// Accumulate operand - one refined work item arriving in accumulate
// ---------------------------------------------------------------------------

struct AccumulateOperand
{
    Hash             work_package_hash;
    Hash             segment_root;
    Hash             authorizer_hash;
    Hash             payload_hash;
    Gas              gas_limit;
    WorkDigestOutput digest_output;
    WorkDigestOutput work_report_output;
}

// ---------------------------------------------------------------------------
// Accumulate transfer - a deferred transfer arriving in accumulate
// ---------------------------------------------------------------------------

struct AccumulateTransfer
{
    ServiceId sender;
    ServiceId receiver;
    Balance   amount;
    Memo      memo;
    Gas       gas_limit;
}

// ---------------------------------------------------------------------------
// Accumulate input - discriminated union: either operand or transfer
// ---------------------------------------------------------------------------

enum AccumulateInputKind : char
{
    OPERAND,
    TRANSFER,
}

struct AccumulateInput
{
    AccumulateInputKind kind;
    union
    {
        AccumulateOperand  operand;
        AccumulateTransfer transfer;
    }
}
