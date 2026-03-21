// Example: Hello World JAM Service
// Minimal structure for a JAM service in C3.
module hello;

import jam::types;
import jam::refine;
import jam::accumulate;
import jam::log;

// ---------------------------------------------------------------------------
// Refine - off-chain computation
// ---------------------------------------------------------------------------

fn types::RefineResult refine(refine::Ctx* ctx) @export("refine")
{
    log::info("hello", "Hello World from Refine!");

    char[5] result = { 'h', 'e', 'l', 'l', 'o' };
    return ctx.result_ok(&result, 5);
}

// ---------------------------------------------------------------------------
// Accumulate - on-chain computation
// ---------------------------------------------------------------------------

fn void accumulate(accumulate::Ctx* ctx) @export("accumulate")
{
    log::info("hello", "Hello World from Accumulate!");
}
