// ==========================================================================
// Decentralized Guessing game aka. Bounty - JAM Service
// ==========================================================================
//
// Service where users post guesses backed by locked tokens,
// and workers claim rewards by submitting valid solutions.
//
// USE CASE: Decentralized Guessing game on JAM. A poster
// locks tokens into a bounty with game difficulty. Workers race to find a nonce
// such that a simple hash of (bounty_id || nonce) has enough leading
// zero bits to meet the target. The first valid solution wins the reward.
//
// WIRE FORMAT (work payloads):
//   Byte 0 = command tag:
//     0x01 = POST_BOUNTY:   [u8 tag][u64 reward][u8 difficulty][32B description]
//     0x02 = CLAIM_BOUNTY:  [u8 tag][u64 bounty_id][u64 nonce][u32 claimer_id]
//     0x03 = CANCEL_BOUNTY: [u8 tag][u64 bounty_id][u32 poster_id]
//
// STORAGE LAYOUT:
//   "next"           -> u64: next bounty ID counter
//   "stat"           -> Stats struct: global statistics
//   "b" || u64(id)   -> Bounty struct: individual bounty data
//   "w" || u32(sid)  -> u64: win count per service (leaderboard)
//   "lock"           -> u64: total tokens locked across all open bounties
// ==========================================================================
module bounty_board;

import jam::types;
import jam::service;
import jam::storage;
import jam::codec;
import jam::log;

// ==========================================================================
// Constants
// ==========================================================================

const char CMD_POST_BOUNTY   = 0x01;
const char CMD_CLAIM_BOUNTY  = 0x02;
const char CMD_CANCEL_BOUNTY = 0x03;

const char BOUNTY_OPEN       = 0x00;
const char BOUNTY_CLAIMED    = 0x01;
const char BOUNTY_CANCELLED  = 0x02;

const ulong MAX_DIFFICULTY   = 64;     // max leading zero bits required
const ulong MIN_REWARD       = 1000;   // minimum bounty reward

// ==========================================================================
// On-chain data structures
// ==========================================================================

// 54 bytes: individual bounty record stored in KV
struct Bounty @packed
{
    char                status;           // BOUNTY_OPEN / CLAIMED / CANCELLED
    types::ServiceId    poster_id;        // who posted it
    types::Balance      reward;           // locked tokens
    char                difficulty;       // leading zero bits required
    types::Timeslot     created_at;       // timeslot when posted
    types::ServiceId    winner_id;        // who claimed it (0 if open)
    char[32]            description;      // short description / task hash
}

// 32 bytes: aggregate statistics
struct Stats @packed
{
    ulong total_bounties;
    ulong total_claimed;
    ulong total_cancelled;
    ulong total_rewards_paid;
}

// ==========================================================================
// Refine - Off-chain validation
// ==========================================================================
// Parses and validates work payloads before they reach on-chain accumulate.
// For CLAIM_BOUNTY: performs the proof-of-work check off-chain.
// Returns a validated, re-encoded payload for accumulate to process.
// ==========================================================================

fn types::RefineResult refine(types::RefineArgs* args) @export("refine")
{
    log::info("bounty", "Refine: processing work item");

    if (args.work_payload == null || args.work_payload_len == 0)
    {
        log::err("bounty", "Refine: empty payload");
        return service::refine_empty();
    }

    codec::DecodeCtx ctx = codec::decode_ctx_init(
        args.work_payload, args.work_payload_len
    );

    // Read command tag
    char? maybe_cmd = codec::decode_u8(&ctx);
    if (catch maybe_cmd)
    {
        log::err("bounty", "Refine: failed to decode command tag");
        return service::refine_empty();
    }
    char cmd = maybe_cmd;

    if (cmd == CMD_POST_BOUNTY)
    {
        return refine_post_bounty(&ctx, args);
    }
    else if (cmd == CMD_CLAIM_BOUNTY)
    {
        return refine_claim_bounty(&ctx, args);
    }
    else if (cmd == CMD_CANCEL_BOUNTY)
    {
        return refine_cancel_bounty(&ctx, args);
    }
    else
    {
      log::err("bounty", "Refine: unknown command");
      return service::refine_empty();
    }
}

// ---------------------------------------------------------------------------
// Refine: POST_BOUNTY
// Validates reward amount and difficulty, passes through to accumulate.
// ---------------------------------------------------------------------------

fn types::RefineResult refine_post_bounty(codec::DecodeCtx* ctx, types::RefineArgs* args)
{
    log::info("bounty", "Refine: POST_BOUNTY");

    // Decode reward amount
    ulong? maybe_reward = codec::decode_u64(ctx);
    if (catch maybe_reward)
    {
        log::err("bounty", "Refine: failed to decode reward");
        return service::refine_empty();
    }
    ulong reward = maybe_reward;

    if (reward < MIN_REWARD)
    {
        log::warn("bounty", "Refine: reward below minimum");
        return service::refine_empty();
    }

    // Decode difficulty
    char? maybe_diff = codec::decode_u8(ctx);
    if (catch maybe_diff)
    {
        log::err("bounty", "Refine: failed to decode difficulty");
        return service::refine_empty();
    }
    char difficulty = maybe_diff;

    if ((ulong)difficulty > MAX_DIFFICULTY || difficulty == 0)
    {
        log::warn("bounty", "Refine: invalid difficulty");
        return service::refine_empty();
    }

    // Decode 32-byte description
    char[32] desc;
    if (catch codec::decode_fixed(ctx, &desc, 32))
    {
        log::err("bounty", "Refine: failed to decode description");
        return service::refine_empty();
    }

    // Re-encode validated payload for accumulate
    // Format: [cmd:1][reward:8][difficulty:1][desc:32] = 42 bytes
    char[42] out;
    out[0] = CMD_POST_BOUNTY;

    if (catch codec::encode_u64(&out[1], 8, reward)) {return service::refine_empty();}
    out[9] = difficulty;
    codec::mem_copy(&out[10], &desc, 32);

    log::debug_u64("bounty", "Refine: validated bounty, reward", reward);
    return service::refine_ok(&out, 42);
}

// ---------------------------------------------------------------------------
// Refine: CLAIM_BOUNTY
// Validates proof-of-work: hash(bounty_id || nonce) must have enough
// leading zero bits. Uses a simple xorshift-based hash for PoW.
// ---------------------------------------------------------------------------

fn types::RefineResult refine_claim_bounty(codec::DecodeCtx* ctx, types::RefineArgs* args)
{
    log::info("bounty", "Refine: CLAIM_BOUNTY");

    // Decode bounty ID
    ulong? maybe_id = codec::decode_u64(ctx);
    if (catch maybe_id)
    {
        log::err("bounty", "Refine: failed to decode bounty_id");
        return service::refine_empty();
    }
    ulong bounty_id = maybe_id;

    // Decode nonce
    ulong? maybe_nonce = codec::decode_u64(ctx);
    if (catch maybe_nonce)
    {
        log::err("bounty", "Refine: failed to decode nonce");
        return service::refine_empty();
    }
    ulong nonce = maybe_nonce;

    // Decode claimer service ID
    uint? maybe_claimer = codec::decode_u32(ctx);
    if (catch maybe_claimer)
    {
        log::err("bounty", "Refine: failed to decode claimer_id");
        return service::refine_empty();
    }
    uint claimer_id = maybe_claimer;

    // --- Proof of work: compute hash and count leading zero bits ---
    ulong pow_hash = compute_pow_hash(bounty_id, nonce);
    ulong leading_zeros = count_leading_zeros(pow_hash);

    log::debug_u64("bounty", "Refine: PoW leading zeros", leading_zeros);

    // Encode result for accumulate:
    // [cmd:1][bounty_id:8][claimer_id:4][leading_zeros:8] = 21 bytes
    char[21] out;
    out[0] = CMD_CLAIM_BOUNTY;

    if (catch codec::encode_u64(&out[1], 8, bounty_id)) {return service::refine_empty();}
    if (catch codec::encode_u32(&out[9], 4, claimer_id)) {return service::refine_empty();}
    if (catch codec::encode_u64(&out[13], 8, leading_zeros)) {return service::refine_empty();}

    return service::refine_ok(&out, 21);
}

// ---------------------------------------------------------------------------
// Refine: CANCEL_BOUNTY
// Validates cancel request format, passes through.
// ---------------------------------------------------------------------------

fn types::RefineResult refine_cancel_bounty(codec::DecodeCtx* ctx, types::RefineArgs* args)
{
    log::info("bounty", "Refine: CANCEL_BOUNTY");

    ulong? maybe_id = codec::decode_u64(ctx);
    if (catch maybe_id)
    {
        log::err("bounty", "Refine: failed to decode bounty_id");
        return service::refine_empty();
    }
    ulong bounty_id = maybe_id;

    uint? maybe_poster = codec::decode_u32(ctx);
    if (catch maybe_poster)
    {
        log::err("bounty", "Refine: failed to decode poster_id");
        return service::refine_empty();
    }
    uint poster_id = maybe_poster;

    // Pass through: [cmd:1][bounty_id:8][poster_id:4] = 13 bytes
    char[13] out;
    out[0] = CMD_CANCEL_BOUNTY;
    if (catch codec::encode_u64(&out[1], 8, bounty_id)) {return service::refine_empty();}
    if (catch codec::encode_u32(&out[9], 4, poster_id)) {return service::refine_empty();}

    return service::refine_ok(&out, 13);
}

// ==========================================================================
// Accumulate - On-chain state mutation
// ==========================================================================
// Receives validated payloads from refine and applies state changes:
// creates bounties, settles claims, or processes cancellations.
// ==========================================================================

fn void accumulate(types::AccumulateArgs* args) @export("accumulate")
{
    log::info("bounty", "Accumulate: entry");
    log::debug_u64("bounty", "Accumulate: timeslot", args.timeslot);
    log::debug_u64("bounty", "Accumulate: inputs", args.num_inputs);

    // Process each input from the work items
    char[128] input_buf;
    ulong? maybe_len = service::fetch_inputs(&input_buf, 128);
    if (catch maybe_len)
    {
        log::warn("bounty", "Accumulate: no inputs available");
        return;
    }
    usz input_len = maybe_len;

    if (input_len == 0)
    {
        log::warn("bounty", "Accumulate: empty input");
        return;
    }

    codec::DecodeCtx ctx = codec::decode_ctx_init(&input_buf, input_len);

    char? maybe_cmd = codec::decode_u8(&ctx);
    if (catch maybe_cmd)
    {
        log::err("bounty", "Accumulate: failed to decode command");
        return;
    }
    char cmd = maybe_cmd;

    if (cmd == CMD_POST_BOUNTY)
    {
        accumulate_post_bounty(&ctx, args);
    }
    else if (cmd == CMD_CLAIM_BOUNTY)
    {
        accumulate_claim_bounty(&ctx, args);
    }
    else if (cmd == CMD_CANCEL_BOUNTY)
    {
        accumulate_cancel_bounty(&ctx, args);
    }
    else
    {
        log::err("bounty", "Accumulate: unknown command");
    }
}

// ---------------------------------------------------------------------------
// Accumulate: POST_BOUNTY
// Creates a new bounty, assigns an ID, locks reward in storage.
// ---------------------------------------------------------------------------

fn void accumulate_post_bounty(codec::DecodeCtx* ctx, types::AccumulateArgs* args)
{
    log::info("bounty", "Accumulate: creating bounty");

    // Checkpoint so we can roll back if something fails
    service::checkpoint();

    // Decode validated payload: [reward:8][difficulty:1][desc:32]
    ulong? maybe_reward = codec::decode_u64(ctx);
    if (catch maybe_reward)
    {
        log::err("bounty", "Accumulate: failed to decode reward");
        return;
    }
    ulong reward = maybe_reward;

    char? maybe_diff = codec::decode_u8(ctx);
    if (catch maybe_diff)
    {
        log::err("bounty", "Accumulate: failed to decode difficulty");
        return;
    }
    char difficulty = maybe_diff;

    char[32] desc;
    if (catch codec::decode_fixed(ctx, &desc, 32))
    {
        log::err("bounty", "Accumulate: failed to decode description");
        return;
    }

    // Check service balance can cover existing locked funds plus new reward
    types::Balance? maybe_bal = service::balance();
    if (catch maybe_bal)
    {
        log::err("bounty", "Accumulate: cannot query balance");
        return;
    }
    types::Balance balance = maybe_bal;

    ulong total_locked = read_total_locked();
    if (balance < total_locked + reward)
    {
        log::err("bounty", "Accumulate: insufficient balance for reward");
        log::debug_u64("bounty", "Accumulate: balance", balance);
        log::debug_u64("bounty", "Accumulate: already locked", total_locked);
        log::debug_u64("bounty", "Accumulate: requested reward", reward);
        return;
    }

    // Lock the reward by incrementing total locked counter
    write_total_locked(total_locked + reward);

    // Get next bounty ID
    ulong next_id = read_next_id();

    // Build the Bounty struct
    Bounty bounty;
    bounty.status      = BOUNTY_OPEN;
    bounty.poster_id   = args.service_id;
    bounty.reward      = reward;
    bounty.difficulty  = difficulty;
    bounty.created_at  = args.timeslot;
    bounty.winner_id   = 0;
    codec::mem_copy(&bounty.description, &desc, 32);

    // Write bounty to storage: key = "b" + u64(id)
    write_bounty(next_id, &bounty);

    // Increment and save next ID
    write_next_id(next_id + 1);

    // Update global stats
    Stats stats = read_stats();
    stats.total_bounties++;
    write_stats(&stats);

    log::debug_u64("bounty", "Accumulate: created bounty ID", next_id);
    log::debug_u64("bounty", "Accumulate: reward locked", reward);
}

// ---------------------------------------------------------------------------
// Accumulate: CLAIM_BOUNTY
// Settles a bounty: verifies PoW meets difficulty, transfers reward.
// ---------------------------------------------------------------------------

fn void accumulate_claim_bounty(codec::DecodeCtx* ctx, types::AccumulateArgs* args)
{
    log::info("bounty", "Accumulate: processing claim");

    // Checkpoint for atomic settlement
    service::checkpoint();

    // Decode: [bounty_id:8][claimer_id:4][leading_zeros:8]
    ulong? maybe_id = codec::decode_u64(ctx);
    if (catch maybe_id)
    {
        log::err("bounty", "Accumulate: failed to decode bounty_id");
        return;
    }
    ulong bounty_id = maybe_id;

    uint? maybe_claimer = codec::decode_u32(ctx);
    if (catch maybe_claimer)
    {
        log::err("bounty", "Accumulate: failed to decode claimer_id");
        return;
    }
    uint claimer_id = maybe_claimer;

    ulong? maybe_zeros = codec::decode_u64(ctx);
    if (catch maybe_zeros)
    {
        log::err("bounty", "Accumulate: failed to decode leading_zeros");
        return;
    }
    ulong leading_zeros = maybe_zeros;

    // Load the bounty
    Bounty bounty;
    if (!read_bounty(bounty_id, &bounty))
    {
        log::err("bounty", "Accumulate: bounty not found");
        return;
    }

    // Must be open
    if (bounty.status != BOUNTY_OPEN)
    {
        log::warn("bounty", "Accumulate: bounty not open");
        return;
    }

    // PoW must meet difficulty target
    if (leading_zeros < (ulong)bounty.difficulty)
    {
        log::warn("bounty", "Accumulate: PoW insufficient");
        log::debug_u64("bounty", "Accumulate: need", (ulong)bounty.difficulty);
        log::debug_u64("bounty", "Accumulate: got", leading_zeros);
        return;
    }

    // Transfer reward to claimer
    types::Memo memo;
    codec::mem_zero((char*)&memo, 128);
    // Write "BOUNTY" into the memo
    memo[0] = 'B'; memo[1] = 'O'; memo[2] = 'U';
    memo[3] = 'N'; memo[4] = 'T'; memo[5] = 'Y';

    if (catch service::transfer(
        (types::ServiceId)claimer_id,
        bounty.reward,
        1000,    // gas limit for the transfer
        &memo
    ))
    {
        log::err("bounty", "Accumulate: transfer failed");
        return;
    }

    // Mark bounty as claimed
    bounty.status    = BOUNTY_CLAIMED;
    bounty.winner_id = claimer_id;
    write_bounty(bounty_id, &bounty);

    // Release locked funds since reward has been transferred out
    ulong total_locked = read_total_locked();
    if (total_locked >= bounty.reward)
    {
        write_total_locked(total_locked - bounty.reward);
    }
    else
    {
        write_total_locked(0);
    }

    // Update leaderboard: increment winner's count
    ulong wins = read_win_count(claimer_id);
    wins++;
    write_win_count(claimer_id, wins);

    // Update global stats
    Stats stats = read_stats();
    stats.total_claimed++;
    stats.total_rewards_paid += bounty.reward;
    write_stats(&stats);

    log::debug_u64("bounty", "Accumulate: bounty claimed, ID", bounty_id);
    log::debug_u64("bounty", "Accumulate: paid out", bounty.reward);
    log::debug_u64("bounty", "Accumulate: winner total wins", wins);
}

// ---------------------------------------------------------------------------
// Accumulate: CANCEL_BOUNTY
// Only the original poster can cancel. Refunds locked reward.
// ---------------------------------------------------------------------------

fn void accumulate_cancel_bounty(codec::DecodeCtx* ctx, types::AccumulateArgs* args)
{
    log::info("bounty", "Accumulate: processing cancellation");

    service::checkpoint();

    // Decode: [bounty_id:8][poster_id:4]
    ulong? maybe_id = codec::decode_u64(ctx);
    if (catch maybe_id)
    {
        log::err("bounty", "Accumulate: failed to decode bounty_id");
        return;
    }
    ulong bounty_id = maybe_id;

    uint? maybe_poster = codec::decode_u32(ctx);
    if (catch maybe_poster)
    {
        log::err("bounty", "Accumulate: failed to decode poster_id");
        return;
    }
    uint poster_id = maybe_poster;

    // Load the bounty
    Bounty bounty;
    if (!read_bounty(bounty_id, &bounty))
    {
        log::err("bounty", "Accumulate: bounty not found");
        return;
    }

    // Must be open
    if (bounty.status != BOUNTY_OPEN)
    {
        log::warn("bounty", "Accumulate: bounty not open");
        return;
    }

    // Only poster can cancel
    if (bounty.poster_id != poster_id)
    {
        log::warn("bounty", "Accumulate: not the poster");
        return;
    }

    // Mark as cancelled
    bounty.status = BOUNTY_CANCELLED;
    write_bounty(bounty_id, &bounty);

    // Release locked funds
    ulong total_locked = read_total_locked();
    if (total_locked >= bounty.reward)
    {
        write_total_locked(total_locked - bounty.reward);
    }
    else
    {
        write_total_locked(0);
    }

    // Update stats
    Stats stats = read_stats();
    stats.total_cancelled++;
    write_stats(&stats);

    log::debug_u64("bounty", "Accumulate: cancelled bounty ID", bounty_id);
    log::debug_u64("bounty", "Accumulate: refunded", bounty.reward);
}

// ==========================================================================
// Proof-of-Work helpers
// ==========================================================================

// 64-bit left rotation.
fn ulong rotate_left(ulong x, int r)
{
    return (x << r) | (x >> (64 - r));
}

// SipHash round: ARX mixing on four state words.
// Inlined as a macro to avoid exceeding PolkaVM's register limit (a0-a5).
macro void sip_round(ulong *v0, ulong *v1, ulong *v2, ulong *v3)
{
    *v0 += *v1;
    *v1 = rotate_left(*v1, 13);
    *v1 ^= *v0;
    *v0 = rotate_left(*v0, 32);

    *v2 += *v3;
    *v3 = rotate_left(*v3, 16);
    *v3 ^= *v2;

    *v0 += *v3;
    *v3 = rotate_left(*v3, 21);
    *v3 ^= *v0;

    *v2 += *v1;
    *v1 = rotate_left(*v1, 17);
    *v1 ^= *v2;
    *v2 = rotate_left(*v2, 32);
}

// SipHash-2-4 inspired keyed hash for proof-of-work.
// Provides good avalanche properties so that expected work to find
// a solution with D leading zero bits is genuinely ~2^D attempts.
// Uses a fixed key derived from constants; bounty_id and nonce are
// mixed as the message.
fn ulong compute_pow_hash(ulong bounty_id, ulong nonce)
{
    // Initialize four state words from SipHash-style constants
    ulong v0 = 0x736f6d6570736575;  // "somepseu"
    ulong v1 = 0x646f72616e646f6d;  // "dorandom"
    ulong v2 = 0x6c7967656e657261;  // "lygenera"
    ulong v3 = 0x7465646279746573;  // "tedbytes"

    // Mix in bounty_id as first message word
    v3 ^= bounty_id;
    sip_round(&v0, &v1, &v2, &v3);
    sip_round(&v0, &v1, &v2, &v3);
    v0 ^= bounty_id;

    // Mix in nonce as second message word
    v3 ^= nonce;
    sip_round(&v0, &v1, &v2, &v3);
    sip_round(&v0, &v1, &v2, &v3);
    v0 ^= nonce;

    // Finalization: 4 rounds
    v2 ^= 0xff;
    sip_round(&v0, &v1, &v2, &v3);
    sip_round(&v0, &v1, &v2, &v3);
    sip_round(&v0, &v1, &v2, &v3);
    sip_round(&v0, &v1, &v2, &v3);

    return v0 ^ v1 ^ v2 ^ v3;
}

// Count leading zero bits of a 64-bit value.
fn ulong count_leading_zeros(ulong value)
{
    if (value == 0) return 64;
    ulong count = 0;
    ulong mask = (ulong)1 << 63;
    while ((value & mask) == 0)
    {
        count++;
        mask >>= 1;
    }
    return count;
}

// ==========================================================================
// Storage helpers
// ==========================================================================

// --- Next bounty ID counter: key = "next" ---

fn ulong read_next_id()
{
    char[4] key = { 'n', 'e', 'x', 't' };
    char[8] buf;

    ulong? maybe_bytes = storage::kv_read(&key, 4, &buf, 0, 8);
    if (try bytes_read = maybe_bytes)
    {
        codec::DecodeCtx ctx = codec::decode_ctx_init(&buf, bytes_read);
        ulong? maybe_id = codec::decode_u64(&ctx);
        if (try id = maybe_id)
        {
            return id;
        }
    }
    return 0;
}

fn void write_next_id(ulong id)
{
    char[4] key = { 'n', 'e', 'x', 't' };
    char[8] buf;

    if (catch codec::encode_u64(&buf, 8, id)) {return;}
    if (catch storage::kv_write(&key, 4, &buf, 8))
    {
        log::err("bounty", "Storage: failed to write next_id");
    }
}

// --- Bounty record: key = "b" + u64(id), 9 bytes ---

fn void make_bounty_key(ulong id, char* key_buf)
{
    key_buf[0] = 'b';
    if (catch codec::encode_u64(&key_buf[1], 8, id)) {return;}
}

fn bool read_bounty(ulong id, Bounty* out)
{
    char[9] key;
    make_bounty_key(id, &key);

    char[54] buf;   // Bounty is 54 bytes packed
    ulong? maybe_bytes = storage::kv_read(&key, 9, &buf, 0, Bounty.sizeof);
    if (catch maybe_bytes)
    {
        return false;
    }
    usz bytes_read = maybe_bytes;
    if (bytes_read < Bounty.sizeof) return false;

    codec::mem_copy((char*)out, &buf, Bounty.sizeof);
    return true;
}

fn void write_bounty(ulong id, Bounty* bounty)
{
    char[9] key;
    make_bounty_key(id, &key);

    if (catch storage::kv_write(&key, 9, (char*)bounty, Bounty.sizeof))
    {
        log::err("bounty", "Storage: failed to write bounty");
    }
}

// --- Global stats: key = "stat" ---

fn Stats read_stats()
{
    char[4] key = { 's', 't', 'a', 't' };
    Stats stats;
    codec::mem_zero((char*)&stats, Stats.sizeof);

    char[32] buf;   // Stats is 32 bytes packed
    ulong? maybe_bytes = storage::kv_read(&key, 4, &buf, 0, Stats.sizeof);
    if (try bytes_read = maybe_bytes)
    {
        if (bytes_read >= Stats.sizeof)
        {
            codec::mem_copy((char*)&stats, &buf, Stats.sizeof);
        }
    }
    return stats;
}

fn void write_stats(Stats* stats)
{
    char[4] key = { 's', 't', 'a', 't' };
    if (catch storage::kv_write(&key, 4, (char*)stats, Stats.sizeof))
    {
        log::err("bounty", "Storage: failed to write stats");
    }
}

// --- Total locked balance: key = "lock" ---

fn ulong read_total_locked()
{
    char[4] key = { 'l', 'o', 'c', 'k' };
    char[8] buf;

    ulong? maybe_bytes = storage::kv_read(&key, 4, &buf, 0, 8);
    if (try bytes_read = maybe_bytes)
    {
        codec::DecodeCtx ctx = codec::decode_ctx_init(&buf, bytes_read);
        ulong? maybe_val = codec::decode_u64(&ctx);
        if (try val = maybe_val)
        {
            return val;
        }
    }
    return 0;
}

fn void write_total_locked(ulong amount)
{
    char[4] key = { 'l', 'o', 'c', 'k' };
    char[8] buf;

    if (catch codec::encode_u64(&buf, 8, amount)) {return;}
    if (catch storage::kv_write(&key, 4, &buf, 8))
    {
        log::err("bounty", "Storage: failed to write total_locked");
    }
}

// --- Leaderboard: key = "w" + u32(service_id) ---

fn void make_wins_key(uint service_id, char* key_buf)
{
    key_buf[0] = 'w';
    if (catch codec::encode_u32(&key_buf[1], 4, service_id)) {return;}
}

fn ulong read_win_count(uint service_id)
{
    char[5] key;
    make_wins_key(service_id, &key);

    char[8] buf;
    ulong? maybe_bytes = storage::kv_read(&key, 5, &buf, 0, 8);
    if (try bytes_read = maybe_bytes)
    {
        codec::DecodeCtx ctx = codec::decode_ctx_init(&buf, bytes_read);
        ulong? maybe_count = codec::decode_u64(&ctx);
        if (try count = maybe_count)
        {
            return count;
        }
    }
    return 0;
}

fn void write_win_count(uint service_id, ulong count)
{
    char[5] key;
    make_wins_key(service_id, &key);

    char[8] buf;
    if (catch codec::encode_u64(&buf, 8, count))
    {
        log::err("bounty", "Storage: failed to encode win count");
        return;
    }
    if (catch storage::kv_write(&key, 5, &buf, 8))
    {
        log::err("bounty", "Storage: failed to write win count");
    }
}
