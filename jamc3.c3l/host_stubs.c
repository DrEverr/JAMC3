// JAM SDK - PolkaVM Host Function Import Stubs
//
// This file provides the PolkaVM metadata sections that polkatool needs to
// resolve host function imports. C3 cannot emit custom ELF sections, so we
// use a minimal C file compiled with clang to generate the .polkavm_metadata
// entries. The public symbol names match the @cname declarations in host.c3.
//
// Each POLKAVM_IMPORT_WITH_INDEX invocation creates:
//   1. A PolkaVM_Metadata_V2 struct in .polkavm_metadata section
//   2. A naked function stub with a magic marker that polkatool recognizes
//
// Compiled separately and linked into the final ELF.

typedef unsigned long long uint64_t;

// ---- PolkaVM metadata structures ----

struct PolkaVM_Metadata {
    unsigned char version;
    unsigned int flags;
    unsigned int symbol_length;
    const char * symbol;
    unsigned char input_regs;
    unsigned char output_regs;
} __attribute__ ((packed));

struct PolkaVM_Metadata_V2 {
    unsigned char version;
    unsigned int flags;
    unsigned int symbol_length;
    const char * symbol;
    unsigned char input_regs;
    unsigned char output_regs;
    unsigned char has_index;
    unsigned int index;
} __attribute__ ((packed));

// ---- PolkaVM import/export magic ----

#define POLKAVM_IMPORT_DEF()  \
    ".word 0x0000000b\n" \
    ".quad %[metadata]\n"

#define POLKAVM_EXPORT_DEF()  \
    ".quad %[metadata]\n" \
    ".quad %[function]\n"

// Count arguments for input register count
#define POLKAVM_COUNT0()                  0
#define POLKAVM_COUNT1(a)                 1
#define POLKAVM_COUNT2(a,b)               2
#define POLKAVM_COUNT3(a,b,c)             3
#define POLKAVM_COUNT4(a,b,c,d)           4
#define POLKAVM_COUNT5(a,b,c,d,e)         5
#define POLKAVM_COUNT6(a,b,c,d,e,f)       6

// ---- Import macro ----
// Creates a public (non-static) naked function with the given name and
// embeds the PolkaVM metadata for the host call index.

#define HOST_IMPORT(idx, ret_regs, name, in_regs, ...) \
static struct PolkaVM_Metadata_V2 name##__IMPORT_METADATA \
    __attribute__ ((section(".polkavm_metadata"), used)) = { \
    2, 0, sizeof(#name) - 1, #name, in_regs, ret_regs, 1, idx \
}; \
uint64_t __attribute__ ((naked, used)) name(__VA_ARGS__) { \
    __asm__( \
        POLKAVM_IMPORT_DEF() \
        "ret\n" \
        : \
        : [metadata] "i" (&name##__IMPORT_METADATA) \
        : "memory" \
    ); \
}

#define HOST_IMPORT_VOID(idx, name, in_regs, ...) \
static struct PolkaVM_Metadata_V2 name##__IMPORT_METADATA \
    __attribute__ ((section(".polkavm_metadata"), used)) = { \
    2, 0, sizeof(#name) - 1, #name, in_regs, 0, 1, idx \
}; \
void __attribute__ ((naked, used)) name(__VA_ARGS__) { \
    __asm__( \
        POLKAVM_IMPORT_DEF() \
        "ret\n" \
        : \
        : [metadata] "i" (&name##__IMPORT_METADATA) \
        : "memory" \
    ); \
}

// ===========================================================================
// General host functions (available in both refine and accumulate)
// ===========================================================================

// Index 0: gas() -> uint64_t
HOST_IMPORT(0, 1, gas, 0)

// Index 1: fetch(buffer, offset, len, discriminator, w11, w12) -> uint64_t
HOST_IMPORT(1, 1, fetch, 6,
    uint64_t buffer, uint64_t offset, uint64_t len,
    uint64_t discriminator, uint64_t w11, uint64_t w12)

// Index 2: lookup(hash, out, offset, len) -> uint64_t
HOST_IMPORT(2, 1, lookup, 4,
    uint64_t hash, uint64_t out, uint64_t offset, uint64_t len)

// Index 3: read(service_id, key, key_len, out, offset, len) -> uint64_t
HOST_IMPORT(3, 1, read, 6,
    uint64_t service_id, uint64_t key, uint64_t key_len,
    uint64_t out, uint64_t offset, uint64_t len)

// Index 4: write(key, key_len, value, value_len) -> uint64_t
HOST_IMPORT(4, 1, write, 4,
    uint64_t key, uint64_t key_len, uint64_t value, uint64_t value_len)

// Index 5: info(service_id, out) -> uint64_t
HOST_IMPORT(5, 1, info, 4,
    uint64_t service_id, uint64_t out, uint64_t offset, uint64_t length)

// Index 100: log(level, target, target_len, msg, msg_len) -> void
HOST_IMPORT_VOID(100, log, 5,
    uint64_t level, uint64_t target, uint64_t target_len,
    uint64_t msg, uint64_t msg_len)

// ===========================================================================
// Refine-only host functions
// ===========================================================================

// Index 6: historical_lookup(service_id, hash, out, len) -> uint64_t
HOST_IMPORT(6, 1, historical_lookup, 4,
    uint64_t service_id, uint64_t hash, uint64_t out, uint64_t len)

// Index 7: export(ptr, len) -> uint64_t
HOST_IMPORT(7, 1, export, 2,
    uint64_t ptr, uint64_t len)

// Index 8: machine(code, len, pc) -> uint64_t
HOST_IMPORT(8, 1, machine, 3,
    uint64_t code, uint64_t len, uint64_t pc)

// Index 9: peek(machine_id, out, addr, len) -> uint64_t
HOST_IMPORT(9, 1, peek, 4,
    uint64_t machine_id, uint64_t out, uint64_t addr, uint64_t len)

// Index 10: poke(machine_id, data, addr, len) -> uint64_t
HOST_IMPORT(10, 1, poke, 4,
    uint64_t machine_id, uint64_t data, uint64_t addr, uint64_t len)

// Index 11: pages(machine_id, start, count, mode) -> uint64_t
HOST_IMPORT(11, 1, pages, 4,
    uint64_t machine_id, uint64_t start, uint64_t count, uint64_t mode)

// Index 12: invoke(machine_id, params) -> uint64_t
HOST_IMPORT(12, 1, invoke, 2,
    uint64_t machine_id, uint64_t params)

// Index 13: expunge(machine_id) -> uint64_t
HOST_IMPORT(13, 1, expunge, 1,
    uint64_t machine_id)

// ===========================================================================
// Accumulate-only host functions
// ===========================================================================

// Index 14: bless(manager, assigners, delegator, registrar, extra, count) -> uint64_t
HOST_IMPORT(14, 1, bless, 6,
    uint64_t manager, uint64_t assigners, uint64_t delegator,
    uint64_t registrar, uint64_t extra, uint64_t count)

// Index 15: assign(core, authorizers, assigner) -> uint64_t
HOST_IMPORT(15, 1, assign, 3,
    uint64_t core, uint64_t authorizers, uint64_t assigner)

// Index 16: designate(validators) -> uint64_t
HOST_IMPORT(16, 1, designate, 1,
    uint64_t validators)

// Index 17: checkpoint() -> uint64_t
HOST_IMPORT(17, 1, checkpoint, 0)

// Index 18: new(code_hash, code_len, min_gas_acc, min_gas_memo, gratis_offset, desired_id) -> uint64_t
// Note: 'new' is a C++ keyword but valid in C
HOST_IMPORT(18, 1, new, 6,
    uint64_t code_hash, uint64_t code_len, uint64_t min_gas_acc,
    uint64_t min_gas_memo, uint64_t gratis_offset, uint64_t desired_id)

// Index 19: upgrade(code_hash, min_gas_acc, min_gas_memo) -> uint64_t
HOST_IMPORT(19, 1, upgrade, 3,
    uint64_t code_hash, uint64_t min_gas_acc, uint64_t min_gas_memo)

// Index 20: transfer(receiver, amount, gas_limit, memo) -> uint64_t
HOST_IMPORT(20, 1, transfer, 4,
    uint64_t receiver, uint64_t amount, uint64_t gas_limit, uint64_t memo)

// Index 21: eject(service_id, memo) -> uint64_t
HOST_IMPORT(21, 1, eject, 2,
    uint64_t service_id, uint64_t memo)

// Index 22: query(hash, len) -> uint64_t
HOST_IMPORT(22, 1, query, 2,
    uint64_t hash, uint64_t len)

// Index 23: solicit(hash, len) -> uint64_t
HOST_IMPORT(23, 1, solicit, 2,
    uint64_t hash, uint64_t len)

// Index 24: forget(hash, len) -> uint64_t
HOST_IMPORT(24, 1, forget, 2,
    uint64_t hash, uint64_t len)

// Index 25: yield(hash) -> uint64_t
// Note: 'yield' is a C++ keyword but valid in C
HOST_IMPORT(25, 1, yield, 1,
    uint64_t hash)

// Index 26: provide(service_id, offset, len) -> uint64_t
HOST_IMPORT(26, 1, provide, 3,
    uint64_t service_id, uint64_t offset, uint64_t len)


// ===========================================================================
// PolkaVM Export Declarations
// ===========================================================================
// These export the C3-defined entry points (jam_entry_refine, etc.) so that
// polkatool can find them when building the dispatch table.

// Helpers for unique symbol names
#define CONCAT2(a, b) a ## b
#define CONCAT(a, b) CONCAT2(a, b)

#define HOST_EXPORT(fn_name, in_regs, out_regs) \
extern void fn_name(); \
static struct PolkaVM_Metadata fn_name##__EXPORT_METADATA \
    __attribute__ ((section(".polkavm_metadata"), used)) = { \
    1, 0, sizeof(#fn_name) - 1, #fn_name, in_regs, out_regs \
}; \
static void __attribute__ ((naked, used)) CONCAT(polkavm_export_dummy_, fn_name)() { \
    __asm__( \
        ".pushsection .polkavm_exports,\"Ra\",@note\n" \
        ".byte 1\n" \
        POLKAVM_EXPORT_DEF() \
        ".popsection\n" \
        : \
        : [metadata] "i" (&fn_name##__EXPORT_METADATA), \
          [function] "i" (fn_name) \
        : "memory" \
    ); \
}

// Export entry points based on build mode.
// Define JAM_BUILD_AUTHORIZER=1 to export is_authorized instead of refine/accumulate.
#if defined(JAM_BUILD_AUTHORIZER) && JAM_BUILD_AUTHORIZER
HOST_EXPORT(jam_entry_is_authorized, 2, 0)
#else
HOST_EXPORT(jam_entry_refine, 2, 0)
HOST_EXPORT(jam_entry_accumulate, 2, 0)
#endif
